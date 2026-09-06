import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from database import get_db
from deps import get_current_user
from models.food_log import FoodLog, FoodLogItem
from models.user import User, UserGoal
from schemas.food import (
    FoodLogCreate,
    FoodLogOut,
    GoalProgress,
    ItemsUpdate,
    MacroTotals,
    TodayResponse,
)
from services.daily_scores import calculate_daily_scores
from services.food_grader import grade_meal

router = APIRouter(prefix="/api/v1/food-log", tags=["food-log"])


def _meal_totals(items) -> MacroTotals:
    return MacroTotals(
        calories=sum((i.calories or 0) for i in items),
        protein_g=sum((i.protein_g or 0) for i in items),
        carbs_g=sum((i.carbs_g or 0) for i in items),
        fat_g=sum((i.fat_g or 0) for i in items),
        fiber_g=sum((i.fiber_g or 0) for i in items),
        sugar_g=sum((i.sugar_g or 0) for i in items),
        sodium_mg=sum((i.sodium_mg or 0) for i in items),
    )


async def _latest_goal(db: AsyncSession, user_id) -> UserGoal | None:
    res = await db.execute(
        select(UserGoal).where(UserGoal.user_id == user_id).order_by(UserGoal.updated_at.desc())
    )
    return res.scalars().first()


@router.post("", response_model=FoodLogOut, status_code=201)
async def create_food_log(
    body: FoodLogCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    logged_at = body.logged_at or datetime.now(timezone.utc)
    log = FoodLog(
        user_id=user.id,
        logged_at=logged_at,
        meal_type=body.meal_type,
        source=body.source,
        food_image_url=body.food_image_url,
        notes=body.notes,
    )
    db.add(log)
    await db.flush()

    items = []
    for item in body.items:
        fi = FoodLogItem(food_log_id=log.id, **item.model_dump())
        db.add(fi)
        items.append(fi)
    await db.flush()

    goal = await _latest_goal(db, user.id)
    grade = grade_meal(items, goal, user.allergies, logged_at, body.meal_type)
    log.meal_grade = grade["grade"]
    log.total_calories = sum((i.calories or 0) for i in items)
    for fi in items:
        fi.food_grade = grade["grade"]
    await db.flush()

    # Update logging streak.
    from services.streak_engine import update_streaks_for_user

    await update_streaks_for_user(db, user.id, "food_log", logged_at.date())

    # Schedule a 45-min post-meal symptom check-in (only when a Celery worker exists;
    # the mobile app also schedules a local notification as the primary mechanism).
    from config import settings

    if settings.use_celery:
        try:
            from tasks.notification_task import schedule_meal_followup

            schedule_meal_followup.apply_async(
                args=[str(user.id), str(log.id), body.meal_type], countdown=45 * 60
            )
        except Exception:  # noqa: BLE001 — broker optional in local dev
            pass

    await db.refresh(log, attribute_names=["items"])
    return FoodLogOut.model_validate(log)


@router.get("/today", response_model=TodayResponse)
async def today(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    now = datetime.now(timezone.utc)
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    res = await db.execute(
        select(FoodLog)
        .where(
            FoodLog.user_id == user.id,
            FoodLog.is_deleted.is_(False),
            FoodLog.logged_at >= start,
        )
        .options(selectinload(FoodLog.items))
        .order_by(FoodLog.logged_at.asc())
    )
    logs = res.scalars().all()

    all_items = [i for log in logs for i in log.items]
    totals = _meal_totals(all_items)

    goal = await _latest_goal(db, user.id)
    progress = GoalProgress()
    if goal:
        progress = GoalProgress(
            calories_pct=round(totals.calories / goal.calories_target * 100, 1) if goal.calories_target else 0,
            protein_pct=round(totals.protein_g / goal.protein_g * 100, 1) if goal.protein_g else 0,
            carbs_pct=round(totals.carbs_g / goal.carbs_g * 100, 1) if goal.carbs_g else 0,
            fat_pct=round(totals.fat_g / goal.fat_g * 100, 1) if goal.fat_g else 0,
        )

    scores = await calculate_daily_scores(db, user.id, now.date())
    return TodayResponse(
        date=now.date().isoformat(),
        logs=[FoodLogOut.model_validate(log) for log in logs],
        totals=totals,
        goal_progress=progress,
        daily_scores=scores,
    )


@router.get("/frequent")
async def frequent_ingredients(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    res = await db.execute(
        select(FoodLogItem.ingredient_name, func.count().label("c"))
        .join(FoodLog, FoodLog.id == FoodLogItem.food_log_id)
        .where(FoodLog.user_id == user.id, FoodLog.is_deleted.is_(False))
        .group_by(FoodLogItem.ingredient_name)
        .order_by(func.count().desc())
        .limit(20)
    )
    return [{"ingredient_name": n, "count": c} for n, c in res.all()]


@router.get("/history", response_model=list[FoodLogOut])
async def history(
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    meal_type: str | None = None,
    limit: int = Query(20, le=100),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = select(FoodLog).where(FoodLog.user_id == user.id, FoodLog.is_deleted.is_(False))
    if start_date:
        q = q.where(FoodLog.logged_at >= start_date)
    if end_date:
        q = q.where(FoodLog.logged_at <= end_date)
    if meal_type:
        q = q.where(FoodLog.meal_type == meal_type)
    q = q.options(selectinload(FoodLog.items)).order_by(FoodLog.logged_at.desc()).limit(limit).offset(offset)
    res = await db.execute(q)
    return [FoodLogOut.model_validate(log) for log in res.scalars().all()]


async def _get_owned_log(db: AsyncSession, log_id: uuid.UUID, user_id) -> FoodLog:
    res = await db.execute(
        select(FoodLog)
        .where(FoodLog.id == log_id, FoodLog.user_id == user_id)
        .options(selectinload(FoodLog.items))
    )
    log = res.scalar_one_or_none()
    if log is None:
        raise HTTPException(status_code=404, detail="Food log not found")
    return log


@router.get("/{log_id}", response_model=FoodLogOut)
async def get_log(log_id: uuid.UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return FoodLogOut.model_validate(await _get_owned_log(db, log_id, user.id))


@router.put("/{log_id}/items", response_model=FoodLogOut)
async def update_items(
    log_id: uuid.UUID,
    body: ItemsUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    log = await _get_owned_log(db, log_id, user.id)
    for old in list(log.items):
        await db.delete(old)
    await db.flush()
    items = [FoodLogItem(food_log_id=log.id, **i.model_dump()) for i in body.items]
    for fi in items:
        db.add(fi)
    await db.flush()

    goal = await _latest_goal(db, user.id)
    grade = grade_meal(items, goal, user.allergies, log.logged_at, log.meal_type)
    log.meal_grade = grade["grade"]
    log.total_calories = sum((i.calories or 0) for i in items)
    for fi in items:
        fi.food_grade = grade["grade"]
    await db.flush()
    await db.refresh(log, attribute_names=["items"])
    return FoodLogOut.model_validate(log)


@router.delete("/{log_id}", status_code=204)
async def delete_log(log_id: uuid.UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    log = await _get_owned_log(db, log_id, user.id)
    log.is_deleted = True
    await db.flush()
    return None

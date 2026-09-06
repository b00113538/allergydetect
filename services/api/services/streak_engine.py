from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models.food_log import FoodLog
from models.streak import UserBadge, UserStreak
from models.symptom_log import SymptomLog
from models.user import UserGoal

STREAK_TYPES = {
    "logging": "Consecutive days with 2+ meals logged",
    "reaction_free": "Consecutive days with no symptoms severity > 3",
    "protein_goal": "Consecutive days meeting protein target",
    "hydration": "Consecutive days meeting water intake goal",
}

# badge_id -> (streak_type, threshold)
BADGE_RULES = {
    "logging_7": ("logging", 7),
    "logging_30": ("logging", 30),
    "logging_100": ("logging", 100),
    "reaction_free_7": ("reaction_free", 7),
    "reaction_free_30": ("reaction_free", 30),
    "protein_7": ("protein_goal", 7),
    "hydration_7": ("hydration", 7),
}


async def _day_bounds(day: date):
    return (
        datetime.combine(day, time.min, tzinfo=timezone.utc),
        datetime.combine(day, time.max, tzinfo=timezone.utc),
    )


async def count_meals_for_date(db: AsyncSession, user_id, day: date) -> int:
    start, end = await _day_bounds(day)
    res = await db.execute(
        select(func.count(FoodLog.id)).where(
            FoodLog.user_id == user_id,
            FoodLog.is_deleted.is_(False),
            FoodLog.logged_at >= start,
            FoodLog.logged_at <= end,
        )
    )
    return int(res.scalar() or 0)


async def _get_or_create(db: AsyncSession, user_id, streak_type: str) -> UserStreak:
    res = await db.execute(
        select(UserStreak).where(UserStreak.user_id == user_id, UserStreak.streak_type == streak_type)
    )
    streak = res.scalar_one_or_none()
    if streak is None:
        streak = UserStreak(user_id=user_id, streak_type=streak_type, current_count=0, record_count=0)
        db.add(streak)
        await db.flush()
    return streak


async def increment_streak(db: AsyncSession, user_id, streak_type: str, day: date) -> UserStreak:
    streak = await _get_or_create(db, user_id, streak_type)
    if streak.last_updated == day:
        pass  # already counted today
    elif streak.last_updated == day - timedelta(days=1):
        streak.current_count += 1
    else:
        streak.current_count = 1
    streak.last_updated = day
    streak.record_count = max(streak.record_count or 0, streak.current_count)
    await db.flush()
    await _award_badges(db, user_id, streak_type, streak.current_count)
    return streak


async def break_streak(db: AsyncSession, user_id, streak_type: str, day: date) -> UserStreak:
    streak = await _get_or_create(db, user_id, streak_type)
    streak.current_count = 0
    streak.last_updated = day
    await db.flush()
    return streak


async def _award_badges(db: AsyncSession, user_id, streak_type: str, count: int) -> None:
    for badge_id, (s_type, threshold) in BADGE_RULES.items():
        if s_type == streak_type and count >= threshold:
            exists = await db.execute(
                select(UserBadge).where(UserBadge.user_id == user_id, UserBadge.badge_id == badge_id)
            )
            if exists.scalar_one_or_none() is None:
                db.add(UserBadge(user_id=user_id, badge_id=badge_id))
    await db.flush()


async def update_streaks_for_user(db: AsyncSession, user_id, event_type: str, day: date | None = None):
    day = day or datetime.now(timezone.utc).date()

    if event_type == "food_log":
        if await count_meals_for_date(db, user_id, day) >= 2:
            await increment_streak(db, user_id, "logging", day)

    elif event_type == "symptom_log":
        start, end = await _day_bounds(day)
        res = await db.execute(
            select(func.max(SymptomLog.severity)).where(
                SymptomLog.user_id == user_id,
                SymptomLog.logged_at >= start,
                SymptomLog.logged_at <= end,
            )
        )
        worst = res.scalar()
        if worst is not None and worst > 3:
            await break_streak(db, user_id, "reaction_free", day)

    elif event_type == "end_of_day":
        start, end = await _day_bounds(day)
        res = await db.execute(
            select(func.coalesce(func.sum(FoodLog.total_calories), 0)).where(FoodLog.user_id == user_id)
        )
        goal_res = await db.execute(
            select(UserGoal).where(UserGoal.user_id == user_id).order_by(UserGoal.updated_at.desc())
        )
        goal = goal_res.scalars().first()
        # protein total for the day
        from models.food_log import FoodLogItem

        protein_res = await db.execute(
            select(func.coalesce(func.sum(FoodLogItem.protein_g), 0))
            .join(FoodLog, FoodLog.id == FoodLogItem.food_log_id)
            .where(FoodLog.user_id == user_id, FoodLog.logged_at >= start, FoodLog.logged_at <= end)
        )
        protein_today = float(protein_res.scalar() or 0)
        if goal and goal.protein_g and protein_today >= goal.protein_g * 0.9:
            await increment_streak(db, user_id, "protein_goal", day)

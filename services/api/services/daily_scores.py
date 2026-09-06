from datetime import date, datetime, time, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from constants import GRADE_VALUES
from models.food_log import FoodLog
from models.user import UserGoal


def compute_scores(meals: list[Any], goals: Any | None) -> dict:
    """Pure computation of the three Whoop-style scores (spec §6.3)."""
    # MEAL QUALITY — calorie-weighted average of meal grades.
    if meals:
        total_cal = sum((getattr(m, "total_calories", 0) or 0) for m in meals)
        if total_cal <= 0:
            meal_quality = sum(GRADE_VALUES.get(m.meal_grade, 60) for m in meals) / len(meals)
        else:
            meal_quality = sum(
                GRADE_VALUES.get(m.meal_grade, 60) * ((getattr(m, "total_calories", 0) or 0) / total_cal)
                for m in meals
            )
    else:
        meal_quality = 0

    # EATING RHYTHM — penalty-based.
    rhythm = 100
    meal_times = sorted(
        m.logged_at.hour + m.logged_at.minute / 60 for m in meals if getattr(m, "logged_at", None)
    )
    if not any(t < 11 for t in meal_times):
        rhythm -= 20
    if any(t > 21 for t in meal_times):
        rhythm -= 15
    for i in range(1, len(meal_times)):
        if meal_times[i] - meal_times[i - 1] < 2.5:
            rhythm -= 10
            break
    if not meals or max(meal_times, default=0) < 15:
        rhythm -= 15
    eating_rhythm = max(0, rhythm)

    # DIET WHOLENESS — protein + fiber + variety.
    all_items = [item for m in meals for item in getattr(m, "items", [])]
    goal_protein = (getattr(goals, "protein_g", None) or 100) if goals else 100
    protein_total = sum((getattr(i, "protein_g", 0) or 0) for i in all_items)
    fiber_total = sum((getattr(i, "fiber_g", 0) or 0) for i in all_items)
    protein_score = min(protein_total / max(goal_protein, 1), 1.0)
    fiber_score = min(fiber_total / 25, 1.0)
    variety_score = min(
        len({i.ingredient_name for i in all_items if (getattr(i, "nova_group", 4) or 4) <= 2}) / 5,
        1.0,
    )
    diet_wholeness = round((protein_score * 0.4 + fiber_score * 0.35 + variety_score * 0.25) * 100)

    return {
        "meal_quality": round(meal_quality),
        "eating_rhythm": eating_rhythm,
        "diet_wholeness": diet_wholeness,
    }


async def calculate_daily_scores(db: AsyncSession, user_id, day: date) -> dict:
    start = datetime.combine(day, time.min, tzinfo=timezone.utc)
    end = datetime.combine(day, time.max, tzinfo=timezone.utc)
    result = await db.execute(
        select(FoodLog)
        .where(
            FoodLog.user_id == user_id,
            FoodLog.is_deleted.is_(False),
            FoodLog.logged_at >= start,
            FoodLog.logged_at <= end,
        )
        .options(selectinload(FoodLog.items))
    )
    meals = result.scalars().all()
    goals_res = await db.execute(
        select(UserGoal).where(UserGoal.user_id == user_id).order_by(UserGoal.updated_at.desc())
    )
    goals = goals_res.scalars().first()
    return compute_scores(meals, goals)

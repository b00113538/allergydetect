from collections import Counter, defaultdict
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from constants import GRADE_VALUES
from models.food_log import FoodLog, FoodLogItem
from models.insight import AllergenCandidate
from models.streak import UserStreak
from models.symptom_log import SymptomLog
from models.user import UserGoal


def _bounds(d: date):
    return (
        datetime.combine(d, time.min, tzinfo=timezone.utc),
        datetime.combine(d, time.max, tzinfo=timezone.utc),
    )


async def _latest_goal(db: AsyncSession, user_id):
    res = await db.execute(
        select(UserGoal).where(UserGoal.user_id == user_id).order_by(UserGoal.updated_at.desc())
    )
    return res.scalars().first()


async def _period_report(db: AsyncSession, user_id, start: date, days: int) -> dict:
    end = start + timedelta(days=days)
    start_dt = datetime.combine(start, time.min, tzinfo=timezone.utc)
    end_dt = datetime.combine(end, time.min, tzinfo=timezone.utc)

    logs_res = await db.execute(
        select(FoodLog)
        .where(
            FoodLog.user_id == user_id,
            FoodLog.is_deleted.is_(False),
            FoodLog.logged_at >= start_dt,
            FoodLog.logged_at < end_dt,
        )
        .options(selectinload(FoodLog.items))
    )
    logs = logs_res.scalars().all()

    sym_res = await db.execute(
        select(SymptomLog).where(
            SymptomLog.user_id == user_id,
            SymptomLog.logged_at >= start_dt,
            SymptomLog.logged_at < end_dt,
        )
    )
    symptoms = sym_res.scalars().all()

    # Logging consistency: days with 2+ meals.
    meals_per_day: dict[str, int] = defaultdict(int)
    for log in logs:
        meals_per_day[log.logged_at.date().isoformat()] += 1
    days_with_2 = sum(1 for c in meals_per_day.values() if c >= 2)
    logging_consistency_pct = round(days_with_2 / days * 100, 1)

    # Grade distribution + top foods.
    grade_dist = {"A": 0, "B": 0, "C": 0, "D": 0, "F": 0}
    food_counter: Counter = Counter()
    food_grades: dict[str, list[int]] = defaultdict(list)
    macro_totals = {"calories": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0}
    for log in logs:
        if log.meal_grade in grade_dist:
            grade_dist[log.meal_grade] += 1
        for item in log.items:
            food_counter[item.ingredient_name] += 1
            food_grades[item.ingredient_name].append(GRADE_VALUES.get(item.food_grade, 60))
            macro_totals["calories"] += item.calories or 0
            macro_totals["protein_g"] += item.protein_g or 0
            macro_totals["carbs_g"] += item.carbs_g or 0
            macro_totals["fat_g"] += item.fat_g or 0

    top_foods = [
        {
            "name": name,
            "count": count,
            "avg_grade": round(sum(food_grades[name]) / len(food_grades[name]), 1),
        }
        for name, count in food_counter.most_common(10)
    ]

    # Symptom stats.
    symptom_counter: Counter = Counter()
    for s in symptoms:
        symptom_counter.update(s.symptoms)
    total_reactions = len(symptoms)
    reaction_severity_avg = round(sum(s.severity for s in symptoms) / total_reactions, 1) if total_reactions else 0

    reaction_days = {s.logged_at.date() for s in symptoms if s.severity > 3}
    reaction_free_days = days - len(reaction_days)

    # Macro adherence (avg daily actual vs target).
    goal = await _latest_goal(db, user_id)
    macro_adherence = {"protein_pct": 0.0, "carbs_pct": 0.0, "fat_pct": 0.0, "calories_pct": 0.0}
    if goal:
        avg = {k: v / days for k, v in macro_totals.items()}
        macro_adherence = {
            "calories_pct": round(avg["calories"] / goal.calories_target * 100, 1) if goal.calories_target else 0,
            "protein_pct": round(avg["protein_g"] / goal.protein_g * 100, 1) if goal.protein_g else 0,
            "carbs_pct": round(avg["carbs_g"] / goal.carbs_g * 100, 1) if goal.carbs_g else 0,
            "fat_pct": round(avg["fat_g"] / goal.fat_g * 100, 1) if goal.fat_g else 0,
        }

    # Top allergen candidates.
    cand_res = await db.execute(
        select(AllergenCandidate)
        .where(AllergenCandidate.user_id == user_id)
        .order_by(AllergenCandidate.confidence_score.desc())
        .limit(5)
    )
    top_candidates = [
        {"name": c.ingredient_name, "confidence_score": round(c.confidence_score, 4)}
        for c in cand_res.scalars().all()
    ]

    streak_res = await db.execute(
        select(func.max(UserStreak.record_count)).where(UserStreak.user_id == user_id)
    )
    streak_record = int(streak_res.scalar() or 0)

    return {
        "logging_consistency_pct": logging_consistency_pct,
        "total_reactions": total_reactions,
        "reaction_severity_avg": reaction_severity_avg,
        "most_common_symptoms": [{"symptom": s, "count": c} for s, c in symptom_counter.most_common(5)],
        "top_foods": top_foods,
        "top_allergen_candidates": top_candidates,
        "macro_adherence": macro_adherence,
        "grade_distribution": grade_dist,
        "reaction_free_days": reaction_free_days,
        "streak_record": streak_record,
        "wearable_correlation": [],
    }


async def weekly_report(db: AsyncSession, user_id, week_start: date) -> dict:
    return await _period_report(db, user_id, week_start, 7)


async def monthly_report(db: AsyncSession, user_id, month_start: date) -> dict:
    report = await _period_report(db, user_id, month_start, 30)
    # Food-group breakdown by macro dominance.
    groups = {"protein_sources": [], "carb_sources": [], "fat_sources": []}
    items_res = await db.execute(
        select(FoodLogItem)
        .join(FoodLog, FoodLog.id == FoodLogItem.food_log_id)
        .where(FoodLog.user_id == user_id)
    )
    seen = set()
    for item in items_res.scalars().all():
        if item.ingredient_name in seen:
            continue
        seen.add(item.ingredient_name)
        p, c, f = item.protein_g or 0, item.carbs_g or 0, item.fat_g or 0
        dominant = max(("protein_sources", p), ("carb_sources", c), ("fat_sources", f), key=lambda x: x[1])
        if dominant[1] > 0:
            groups[dominant[0]].append(item.ingredient_name)
    report["food_group_breakdown"] = {k: v[:10] for k, v in groups.items()}
    return report


async def yearly_wrapped(db: AsyncSession, user_id) -> dict:
    year_start = datetime(date.today().year, 1, 1, tzinfo=timezone.utc)
    logs_res = await db.execute(
        select(FoodLog).where(
            FoodLog.user_id == user_id, FoodLog.is_deleted.is_(False), FoodLog.logged_at >= year_start
        ).options(selectinload(FoodLog.items))
    )
    logs = logs_res.scalars().all()
    food_counter: Counter = Counter()
    months: Counter = Counter()
    scans = 0
    for log in logs:
        months[log.logged_at.month] += 1
        if log.source in ("camera", "barcode"):
            scans += 1
        for item in log.items:
            food_counter[item.ingredient_name] += 1

    streak_res = await db.execute(
        select(func.max(UserStreak.record_count)).where(
            UserStreak.user_id == user_id, UserStreak.streak_type == "reaction_free"
        )
    )
    longest_reaction_free = int(streak_res.scalar() or 0)

    cand_res = await db.execute(
        select(AllergenCandidate)
        .where(AllergenCandidate.user_id == user_id)
        .order_by(AllergenCandidate.confidence_score.desc())
        .limit(1)
    )
    top_cand = cand_res.scalars().first()

    from models.streak import UserBadge

    badge_res = await db.execute(select(func.count(UserBadge.id)).where(UserBadge.user_id == user_id))

    return {
        "total_meals_logged": len(logs),
        "total_scans": scans,
        "longest_reaction_free_streak": longest_reaction_free,
        "most_eaten_food": food_counter.most_common(1)[0][0] if food_counter else None,
        "top_allergen_discovered": top_cand.ingredient_name if top_cand else None,
        "best_month": max(months, key=months.get) if months else None,
        "total_badges_earned": int(badge_res.scalar() or 0),
        "macro_adherence_improvement": 0.0,
        "reaction_reduction_pct": 0.0,
    }

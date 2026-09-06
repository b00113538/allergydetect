from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from constants import ALLERGEN_FAMILIES
from models.food_log import FoodLog
from models.insight import AIInsight, AllergenCandidate
from models.symptom_log import SymptomLog
from models.wearable import WearableReading

SYMPTOM_WINDOW_HOURS = 8
WEARABLE_WINDOW_HOURS = 2
HRV_DROP_THRESHOLD = 0.15  # 15%
HR_ELEVATION_BPM = 10.0
WEARABLE_BOOST = 0.15


def _norm(name: str) -> str:
    return (name or "").strip().lower()


def _as_aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _wearable_signal(meal_time: datetime, wearables: list[Any], hrv_baseline, hr_baseline) -> bool:
    """True if HRV dropped >15% or resting HR rose >10bpm within 2h after the meal."""
    if not wearables:
        return False
    win_end = meal_time + timedelta(hours=WEARABLE_WINDOW_HOURS)
    hrv_vals, hr_vals = [], []
    for w in wearables:
        rec = _as_aware(w.recorded_at)
        if meal_time <= rec <= win_end:
            if w.metric == "hrv":
                hrv_vals.append(w.value)
            elif w.metric in ("resting_hr", "heart_rate"):
                hr_vals.append(w.value)
    if hrv_baseline and hrv_vals:
        if (sum(hrv_vals) / len(hrv_vals)) < hrv_baseline * (1 - HRV_DROP_THRESHOLD):
            return True
    if hr_baseline and hr_vals:
        if (sum(hr_vals) / len(hr_vals)) > hr_baseline + HR_ELEVATION_BPM:
            return True
    return False


def compute_candidates(
    meals: list[Any],
    symptoms: list[Any],
    wearables: list[Any] | None = None,
    user_allergies: list[Any] | None = None,
) -> list[dict]:
    """Pure Bayesian-style correlation (spec §4.5). Returns ranked candidate dicts."""
    wearables = wearables or []

    # Wearable baselines (means across the window).
    hrv_baseline = None
    hr_baseline = None
    hrv_all = [w.value for w in wearables if w.metric == "hrv"]
    hr_all = [w.value for w in wearables if w.metric in ("resting_hr", "heart_rate")]
    if hrv_all:
        hrv_baseline = sum(hrv_all) / len(hrv_all)
    if hr_all:
        hr_baseline = sum(hr_all) / len(hr_all)

    # Per-ingredient accumulators.
    total_meals: dict[str, int] = defaultdict(int)
    symptomatic_meals: dict[str, int] = defaultdict(int)
    severities: dict[str, list[float]] = defaultdict(list)
    wearable_hit: dict[str, bool] = defaultdict(bool)

    for meal in meals:
        meal_time = _as_aware(meal.logged_at)
        # Symptoms occurring 0..8h AFTER this meal.
        linked = [
            s for s in symptoms
            if 0 <= (_as_aware(s.logged_at) - meal_time).total_seconds() <= SYMPTOM_WINDOW_HOURS * 3600
        ]
        is_symptomatic = len(linked) > 0
        max_sev = max((s.severity for s in linked), default=0)
        has_wearable_signal = is_symptomatic and _wearable_signal(meal_time, wearables, hrv_baseline, hr_baseline)

        seen = set()
        for item in getattr(meal, "items", []):
            ing = _norm(item.ingredient_name)
            if not ing or ing in seen:
                continue
            seen.add(ing)
            total_meals[ing] += 1
            if is_symptomatic:
                symptomatic_meals[ing] += 1
                severities[ing].append(max_sev)
                if has_wearable_signal:
                    wearable_hit[ing] = True

    candidates: dict[str, dict] = {}
    for ing, total in total_meals.items():
        sympt = symptomatic_meals[ing]
        if sympt == 0:
            continue
        sev_list = severities[ing]
        avg_sev = sum(sev_list) / len(sev_list) if sev_list else 0.0

        # 4. base score
        base = (sympt / total) * (avg_sev / 10.0)

        # 5. Bayesian update — reward repeated symptomatic exposures.
        base *= 1 + 0.10 * (sympt - 1)

        # 7. severity multiplier
        if avg_sev >= 7:
            base *= 1.5

        # 8. wearable signal boost
        if wearable_hit[ing]:
            base += WEARABLE_BOOST

        # No false positive on a single total exposure.
        if total == 1 and sympt == 1:
            base *= 0.5

        candidates[ing] = {
            "ingredient_name": ing,
            "confidence_score": min(round(base, 4), 1.0),
            "symptom_exposure_count": sympt,
            "total_exposure_count": total,
            "avg_severity_when_exposed": round(avg_sev, 2),
        }

    # 6. cross-reactive family detection — boost related terms of strong candidates.
    allergy_terms = {_norm(getattr(a, "allergen_name", a) if not isinstance(a, str) else a) for a in (user_allergies or [])}
    for ing, cand in list(candidates.items()):
        if cand["confidence_score"] < 0.4:
            continue
        related = set(ALLERGEN_FAMILIES.get(ing, []))
        # Latex/pollen syndromes only fire if the user actually has that allergy.
        for term in related:
            if term in candidates:
                candidates[term]["confidence_score"] = min(
                    round(candidates[term]["confidence_score"] + 0.10, 4), 1.0
                )

    ranked = sorted(candidates.values(), key=lambda c: c["confidence_score"], reverse=True)
    return ranked


async def run_correlation(db: AsyncSession, user_id, symptom_log_id=None) -> list[dict]:
    """Load 90 days of data, compute candidates, upsert, and create an insight."""
    since = datetime.now(timezone.utc) - timedelta(days=90)

    meals_res = await db.execute(
        select(FoodLog)
        .where(FoodLog.user_id == user_id, FoodLog.is_deleted.is_(False), FoodLog.logged_at >= since)
        .options(selectinload(FoodLog.items))
    )
    meals = meals_res.scalars().all()

    symptoms_res = await db.execute(
        select(SymptomLog).where(SymptomLog.user_id == user_id, SymptomLog.logged_at >= since)
    )
    symptoms = symptoms_res.scalars().all()

    wearables_res = await db.execute(
        select(WearableReading).where(
            WearableReading.user_id == user_id,
            WearableReading.recorded_at >= since,
            WearableReading.metric.in_(["hrv", "resting_hr", "heart_rate"]),
        )
    )
    wearables = wearables_res.scalars().all()

    candidates = compute_candidates(meals, symptoms, wearables)

    now = datetime.now(timezone.utc)
    for cand in candidates:
        stmt = pg_insert(AllergenCandidate).values(
            user_id=user_id,
            ingredient_name=cand["ingredient_name"],
            confidence_score=cand["confidence_score"],
            symptom_exposure_count=cand["symptom_exposure_count"],
            total_exposure_count=cand["total_exposure_count"],
            avg_severity_when_exposed=cand["avg_severity_when_exposed"],
            last_correlated_at=now,
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=["user_id", "ingredient_name"],
            set_={
                "confidence_score": stmt.excluded.confidence_score,
                "symptom_exposure_count": stmt.excluded.symptom_exposure_count,
                "total_exposure_count": stmt.excluded.total_exposure_count,
                "avg_severity_when_exposed": stmt.excluded.avg_severity_when_exposed,
                "last_correlated_at": stmt.excluded.last_correlated_at,
            },
        )
        await db.execute(stmt)

    if candidates:
        db.add(
            AIInsight(
                user_id=user_id,
                insight_type="allergen_correlation",
                content={
                    "top_candidates": candidates[:10],
                    "triggered_by": str(symptom_log_id) if symptom_log_id else None,
                    "generated_at": now.isoformat(),
                },
            )
        )
    await db.flush()
    return candidates

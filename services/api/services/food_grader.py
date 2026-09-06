from datetime import datetime
from typing import Any

from constants import MEAL_TARGET_PCT


def _g(obj: Any, attr: str, default=0.0):
    """Attribute/key accessor that works for ORM objects and dicts."""
    if isinstance(obj, dict):
        val = obj.get(attr, default)
    else:
        val = getattr(obj, attr, default)
    return default if val is None else val


def grade_meal(
    items: list[Any],
    user_goals: Any,
    user_allergies: list[Any],
    meal_time: datetime,
    meal_type: str = "lunch",
    prior_meal_times: list[datetime] | None = None,
) -> dict:
    """Multi-dimension meal grade per spec §6.2.

    Returns { grade, score, breakdown }.
    """
    scores: dict[str, float] = {}
    items = items or []
    n = max(len(items), 1)

    total_protein = sum(_g(i, "protein_g") for i in items)
    total_fiber = sum(_g(i, "fiber_g") for i in items)

    # 1. MACRO ALIGNMENT (30%) — protein contribution toward this meal's share.
    target_pct = MEAL_TARGET_PCT.get(meal_type, 0.30)
    goal_protein = _g(user_goals, "protein_g", 0) or 0
    meal_protein_target = goal_protein * target_pct
    if meal_protein_target > 0:
        protein_ratio = min(total_protein / meal_protein_target, 1.5)
    else:
        protein_ratio = 1.0
    macro_score = min(protein_ratio, 1.0) * 100
    scores["macro_alignment"] = macro_score * 0.30

    # 2. INGREDIENT QUALITY (25%) — NOVA average (1 best .. 4 ultra-processed).
    avg_nova = sum((_g(i, "nova_group", 2) or 2) for i in items) / n if items else 2
    nova_score = max(0.0, (4 - avg_nova) / 3) * 100
    scores["ingredient_quality"] = nova_score * 0.25

    # 3. MICRONUTRIENT DENSITY (20%) — fiber proxy, 8g per meal = full marks.
    fiber_score = min(total_fiber / 8, 1.0) * 100
    scores["micronutrient_density"] = fiber_score * 0.20

    # 4. ALLERGEN SAFETY (15%) — penalise confirmed-allergen matches.
    allergy_names = [(_g(a, "allergen_name", "") or "").lower() for a in user_allergies]
    confirmed_matches = 0
    for item in items:
        flags = _g(item, "allergen_flags", []) or []
        for flag in flags:
            f = str(flag).lower()
            if any(name and (name in f or f in name) for name in allergy_names):
                confirmed_matches += 1
    allergen_score = max(0, 100 - (confirmed_matches * 40))
    scores["allergen_safety"] = allergen_score * 0.15

    # 5. MEAL TIMING (10%).
    hour = meal_time.hour
    if 7 <= hour <= 21:
        timing_score = 100
    elif hour < 7 or hour >= 22:
        timing_score = 40
    else:
        timing_score = 70
    scores["meal_timing"] = timing_score * 0.10

    total = sum(scores.values())
    grade = (
        "A" if total >= 85 else
        "B" if total >= 70 else
        "C" if total >= 55 else
        "D" if total >= 40 else
        "F"
    )
    return {"grade": grade, "score": round(total), "breakdown": {k: round(v, 2) for k, v in scores.items()}}

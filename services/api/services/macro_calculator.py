from datetime import date

from constants import ACTIVITY_MULTIPLIERS, MACRO_SPLITS


def calculate_age(dob: date | None, today: date | None = None) -> int:
    if dob is None:
        return 30  # sensible default when DOB unknown
    today = today or date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def calculate_tdee(
    weight_kg: float, height_cm: float, age_years: int, sex: str, activity_level: str
) -> int:
    """Mifflin-St Jeor BMR scaled by activity multiplier."""
    if (sex or "").lower() in ("male", "m"):
        bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age_years) + 5
    else:
        bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age_years) - 161
    multiplier = ACTIVITY_MULTIPLIERS.get(activity_level, 1.55)
    return round(bmr * multiplier)


def recommend_macros(tdee: int, goal_type: str) -> dict:
    split = MACRO_SPLITS.get(goal_type, MACRO_SPLITS["maintain"])
    target_calories = tdee + split["deficit"]
    return {
        "calories": target_calories,
        "protein_g": round((target_calories * split["protein"]) / 4),
        "carbs_g": round((target_calories * split["carbs"]) / 4),
        "fat_g": round((target_calories * split["fat"]) / 9),
        "fiber_g": round(target_calories / 1000 * 14),  # 14g per 1000 kcal guideline
    }

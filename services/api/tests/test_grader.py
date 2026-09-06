from datetime import datetime
from types import SimpleNamespace as NS

from services.food_grader import grade_meal

GOALS = NS(protein_g=150)


def test_grade_a_whole_food_balanced_meal():
    items = [
        NS(protein_g=40, fiber_g=8, nova_group=1, allergen_flags=[]),
        NS(protein_g=15, fiber_g=4, nova_group=1, allergen_flags=[]),
    ]
    result = grade_meal(items, GOALS, [], datetime(2026, 5, 22, 12, 30), "lunch")
    assert result["grade"] == "A"
    assert result["score"] >= 85


def test_grade_f_ultra_processed_high_allergen():
    items = [NS(protein_g=2, fiber_g=0, nova_group=4, allergen_flags=["milk"])]
    allergies = [NS(allergen_name="milk")]
    result = grade_meal(items, GOALS, allergies, datetime(2026, 5, 22, 23, 30), "snack")
    assert result["grade"] == "F"


def test_allergen_penalty_confirmed_vs_probable():
    items = [NS(protein_g=30, fiber_g=8, nova_group=1, allergen_flags=["peanuts"])]
    with_allergy = grade_meal(items, GOALS, [NS(allergen_name="peanuts")], datetime(2026, 5, 22, 12, 0), "lunch")
    without_allergy = grade_meal(items, GOALS, [], datetime(2026, 5, 22, 12, 0), "lunch")
    assert with_allergy["score"] < without_allergy["score"]


def test_meal_timing_penalty():
    items = [NS(protein_g=40, fiber_g=8, nova_group=1, allergen_flags=[])]
    midday = grade_meal(items, GOALS, [], datetime(2026, 5, 22, 12, 0), "lunch")
    midnight = grade_meal(items, GOALS, [], datetime(2026, 5, 22, 2, 0), "lunch")
    assert midday["breakdown"]["meal_timing"] > midnight["breakdown"]["meal_timing"]

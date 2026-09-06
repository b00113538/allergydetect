from datetime import datetime, timedelta, timezone
from types import SimpleNamespace as NS

from services.allergen_correlator import compute_candidates

BASE = datetime(2026, 5, 1, 12, 0, tzinfo=timezone.utc)


def _meal(day_offset, ingredients, hour=12):
    t = BASE + timedelta(days=day_offset)
    return NS(logged_at=t.replace(hour=hour), items=[NS(ingredient_name=i) for i in ingredients])


def _symptom(day_offset, severity=8, hours_after=2):
    return NS(logged_at=(BASE + timedelta(days=day_offset)).replace(hour=12) + timedelta(hours=hours_after), severity=severity)


def test_single_ingredient_high_confidence():
    meals = [_meal(i, ["shrimp", "lettuce"]) for i in range(4)]
    meals += [_meal(i, ["lettuce"]) for i in range(4, 8)]  # lettuce often eaten safely
    symptoms = [_symptom(i) for i in range(4)]
    cands = {c["ingredient_name"]: c for c in compute_candidates(meals, symptoms)}
    assert cands["shrimp"]["confidence_score"] > cands.get("lettuce", {"confidence_score": 0})["confidence_score"]
    assert cands["shrimp"]["confidence_score"] >= 0.7


def test_multiple_exposures_bayesian_update():
    few = compute_candidates([_meal(0, ["egg"])], [_symptom(0)])
    many = compute_candidates([_meal(i, ["egg"]) for i in range(5)], [_symptom(i) for i in range(5)])
    egg_few = next(c for c in few if c["ingredient_name"] == "egg")
    egg_many = next(c for c in many if c["ingredient_name"] == "egg")
    assert egg_many["confidence_score"] > egg_few["confidence_score"]


def test_cross_reactive_family_detection():
    # shrimp strongly implicated; crab also appears -> crab gets a family boost.
    meals = [_meal(i, ["shrimp", "crab"]) for i in range(4)]
    symptoms = [_symptom(i) for i in range(4)]
    cands = {c["ingredient_name"]: c for c in compute_candidates(meals, symptoms)}
    assert "crab" in cands
    assert cands["crab"]["confidence_score"] >= 0.7


def test_wearable_signal_boost():
    meals = [_meal(i, ["peanut"]) for i in range(3)]
    symptoms = [_symptom(i, severity=5) for i in range(3)]
    # Baseline HRV ~60; drop to 40 (>15%) within 2h after each meal.
    wearables = []
    for i in range(3):
        mt = (BASE + timedelta(days=i)).replace(hour=12)
        wearables.append(NS(metric="hrv", value=40, recorded_at=mt + timedelta(hours=1)))
    wearables += [NS(metric="hrv", value=70, recorded_at=BASE + timedelta(days=10))]  # raises baseline
    without = compute_candidates(meals, symptoms)
    with_w = compute_candidates(meals, symptoms, wearables=wearables)
    p_without = next(c for c in without if c["ingredient_name"] == "peanut")["confidence_score"]
    p_with = next(c for c in with_w if c["ingredient_name"] == "peanut")["confidence_score"]
    assert p_with > p_without


def test_no_false_positive_on_single_exposure():
    cands = compute_candidates([_meal(0, ["kiwi"])], [_symptom(0, severity=5)])
    kiwi = next(c for c in cands if c["ingredient_name"] == "kiwi")
    assert kiwi["confidence_score"] < 0.3

import json

import pytest

from services.ai_scanner import parse_vision_response
from services.allergen_matcher import cross_reference
from services.media import InvalidImage, validate_image


def test_gpt4o_response_parsing():
    raw = json.dumps(
        {
            "identified_dishes": ["pad thai"],
            "ingredients": [{"name": "peanut", "confidence_score": 0.9}],
            "allergen_flags": ["peanuts", "soy"],
            "processing_level": 3,
        }
    )
    parsed = parse_vision_response(raw)
    assert parsed["identified_dishes"] == ["pad thai"]
    assert parsed["allergen_flags"] == ["peanuts", "soy"]
    assert "total_macros" in parsed  # defaulted


def test_gpt4o_response_parsing_with_code_fence():
    raw = "```json\n{\"ingredients\": [], \"allergen_flags\": []}\n```"
    parsed = parse_vision_response(raw)
    assert parsed["ingredients"] == []


def test_allergen_crossref_with_user_profile():
    from types import SimpleNamespace as NS

    matches = cross_reference(["milk", "wheat"], [NS(allergen_name="milk", severity="severe", confirmed_by_doctor=True)])
    assert len(matches) == 1
    assert matches[0]["allergen"] == "milk"
    assert matches[0]["status"] == "confirmed"


def test_crossref_family_expansion():
    from types import SimpleNamespace as NS

    # User allergic to "gluten"; a "wheat" flag should still match via family.
    matches = cross_reference(["wheat flour"], [NS(allergen_name="gluten", severity="moderate", confirmed_by_doctor=False)])
    assert len(matches) == 1


def test_invalid_image_rejected():
    with pytest.raises(InvalidImage):
        validate_image(b"this is definitely not an image")


def test_oversized_image_rejected():
    with pytest.raises(InvalidImage):
        validate_image(b"x" * (11 * 1024 * 1024))


@pytest.mark.asyncio
async def test_barcode_open_food_facts_fallback():
    """Live Open Food Facts lookup (no key required). Skips if offline."""
    import httpx

    from services.food_database import barcode_lookup

    try:
        result = await barcode_lookup("3017620422003")  # Nutella
    except httpx.HTTPError:
        pytest.skip("network unavailable")
    if not result.get("found"):
        pytest.skip("OFF temporarily unavailable")
    assert result["source"] == "open_food_facts"
    assert "milk" in [a.lower() for a in result["allergens"]]

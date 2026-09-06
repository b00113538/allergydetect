import base64
import json
import logging

from openai import AsyncOpenAI

from config import settings

logger = logging.getLogger(__name__)

VISION_SYSTEM_PROMPT = (
    "You are a clinical nutrition AI assistant specialised in food analysis. "
    "Analyse the food image provided and return ONLY a valid JSON object "
    "(no markdown, no explanation) with this exact structure:\n"
    "{\n"
    '  "identified_dishes": ["string"],\n'
    '  "ingredients": [\n'
    "    {\n"
    '      "name": "string",\n'
    '      "confidence_score": 0.0,\n'
    '      "quantity_estimate_g": 0,\n'
    '      "is_allergen_candidate": false,\n'
    '      "common_allergen_category": null,\n'
    '      "calories_per_100g": 0,\n'
    '      "protein_g_per_100g": 0,\n'
    '      "carbs_g_per_100g": 0,\n'
    '      "fat_g_per_100g": 0,\n'
    '      "fiber_g_per_100g": 0,\n'
    '      "sugar_g_per_100g": 0\n'
    "    }\n"
    "  ],\n"
    '  "total_macros": {"calories": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0, "fiber_g": 0, "sugar_g": 0},\n'
    '  "portion_description": "string",\n'
    '  "cuisine_type": "string",\n'
    '  "allergen_flags": ["string"],\n'
    '  "processing_level": 1\n'
    "}\n"
    "Cross-reference identified allergens against this list: gluten, crustaceans, eggs, fish, "
    "peanuts, soybeans, milk, nuts, celery, mustard, sesame, sulphites, lupin, molluscs, "
    "shellfish, tree nuts. Be conservative — flag anything that might contain these even as a "
    "hidden ingredient (e.g. soy sauce contains gluten)."
)


class ScannerUnavailable(Exception):
    """Raised when OPENAI_API_KEY is not configured."""


def _client() -> AsyncOpenAI:
    if not settings.openai_api_key:
        raise ScannerUnavailable(
            "OPENAI_API_KEY is not configured; the AI camera scanner is unavailable."
        )
    return AsyncOpenAI(api_key=settings.openai_api_key)


# ---------------------------------------------------------------------------
# DEMO MODE fallback
# ---------------------------------------------------------------------------
# When OPENAI_API_KEY is unset (e.g. running a demo without paying for a real
# key), we can't call GPT-4o Vision. Rather than 503-ing the whole scan flow
# (which would make the camera scanner look broken in a demo), we return a
# realistic hardcoded response matching the exact schema the real API would
# return. This is ONLY a display fallback for the missing-key case — it does
# NOT catch or mask real OpenAI API errors (timeouts, rate limits, bad
# responses from a configured key still raise/fail normally). A clear warning
# is logged every time this path is used so it's never mistaken for a real
# analysis in production.
DEMO_MODE_MOCK_RESPONSE: dict = {
    "identified_dishes": ["Grilled chicken salad"],
    "ingredients": [
        {
            "name": "Grilled chicken breast",
            "confidence_score": 0.95,
            "quantity_estimate_g": 120,
            "is_allergen_candidate": False,
            "common_allergen_category": None,
            "calories_per_100g": 165,
            "protein_g_per_100g": 31,
            "carbs_g_per_100g": 0,
            "fat_g_per_100g": 3.6,
            "fiber_g_per_100g": 0,
            "sugar_g_per_100g": 0,
        },
        {
            "name": "Mixed lettuce & greens",
            "confidence_score": 0.9,
            "quantity_estimate_g": 80,
            "is_allergen_candidate": False,
            "common_allergen_category": None,
            "calories_per_100g": 15,
            "protein_g_per_100g": 1.4,
            "carbs_g_per_100g": 2.9,
            "fat_g_per_100g": 0.2,
            "fiber_g_per_100g": 1.3,
            "sugar_g_per_100g": 0.8,
        },
        {
            "name": "Shaved parmesan cheese",
            "confidence_score": 0.82,
            "quantity_estimate_g": 15,
            "is_allergen_candidate": True,
            "common_allergen_category": "milk",
            "calories_per_100g": 392,
            "protein_g_per_100g": 35.8,
            "carbs_g_per_100g": 3.2,
            "fat_g_per_100g": 25.8,
            "fiber_g_per_100g": 0,
            "sugar_g_per_100g": 0.9,
        },
        {
            "name": "Sesame-ginger dressing",
            "confidence_score": 0.71,
            "quantity_estimate_g": 30,
            "is_allergen_candidate": True,
            "common_allergen_category": "sesame",
            "calories_per_100g": 310,
            "protein_g_per_100g": 2.1,
            "carbs_g_per_100g": 12,
            "fat_g_per_100g": 28,
            "fiber_g_per_100g": 0.5,
            "sugar_g_per_100g": 8,
        },
        {
            "name": "Cherry tomatoes",
            "confidence_score": 0.93,
            "quantity_estimate_g": 40,
            "is_allergen_candidate": False,
            "common_allergen_category": None,
            "calories_per_100g": 18,
            "protein_g_per_100g": 0.9,
            "carbs_g_per_100g": 3.9,
            "fat_g_per_100g": 0.2,
            "fiber_g_per_100g": 1.2,
            "sugar_g_per_100g": 2.6,
        },
    ],
    "total_macros": {
        "calories": 415,
        "protein_g": 43.2,
        "carbs_g": 8.6,
        "fat_g": 20.1,
        "fiber_g": 2.4,
        "sugar_g": 3.5,
    },
    "portion_description": "One dinner-plate-sized salad, roughly 285g total",
    "cuisine_type": "American / Californian",
    "allergen_flags": ["milk", "sesame"],
    "processing_level": 1,
}


def _demo_mode_response() -> dict:
    logger.warning(
        "ai_scanner: OPENAI_API_KEY is not set — returning DEMO MODE mock "
        "scan response instead of calling GPT-4o Vision. This is a "
        "hardcoded fixture (grilled chicken salad) for demo purposes only; "
        "it does NOT reflect the actual uploaded image. Set OPENAI_API_KEY "
        "in services/api/.env to enable real analysis."
    )
    # Return a copy so callers mutating the dict don't corrupt the fixture.
    return json.loads(json.dumps(DEMO_MODE_MOCK_RESPONSE))


async def analyze_food_image(image_bytes: bytes) -> dict:
    """Call GPT-4o Vision and parse its JSON response into the scan schema.

    Falls back to a hardcoded DEMO MODE response when OPENAI_API_KEY is not
    configured, so the scan flow stays demoable without a live key. See
    `_demo_mode_response` above.
    """
    if not settings.openai_api_key:
        return _demo_mode_response()

    client = _client()
    b64 = base64.b64encode(image_bytes).decode()
    resp = await client.chat.completions.create(
        model=settings.openai_model,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": VISION_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Analyse this plate of food."},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                ],
            },
        ],
        max_tokens=1500,
        temperature=0.2,
    )
    content = resp.choices[0].message.content or "{}"
    return parse_vision_response(content)


def parse_vision_response(content: str) -> dict:
    """Robustly parse a model JSON response (tolerates accidental code fences)."""
    text = content.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.lower().startswith("json"):
            text = text[4:]
    text = text.strip()
    data = json.loads(text)

    data.setdefault("identified_dishes", [])
    data.setdefault("ingredients", [])
    data.setdefault("allergen_flags", [])
    data.setdefault(
        "total_macros",
        {"calories": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0, "fiber_g": 0, "sugar_g": 0},
    )
    data.setdefault("processing_level", 2)
    return data

import httpx

from config import settings
from constants import SUPPORTED_LANGUAGES

GOOGLE_TRANSLATE_URL = "https://translation.googleapis.com/language/translate/v2"
EMERGENCY_PHRASE_EN = "I need medical help immediately."
CARD_HEADER_EN = "I have the following food allergies:"


class TranslationUnavailable(Exception):
    pass


async def translate_texts(texts: list[str], target: str, source: str = "en") -> list[str]:
    if not settings.google_translate_api_key:
        raise TranslationUnavailable(
            "GOOGLE_TRANSLATE_API_KEY is not configured; translation is unavailable."
        )
    async with httpx.AsyncClient(timeout=20) as client:
        r = await client.post(
            GOOGLE_TRANSLATE_URL,
            params={"key": settings.google_translate_api_key},
            json={"q": texts, "target": target, "source": source, "format": "text"},
        )
        r.raise_for_status()
        translations = r.json()["data"]["translations"]
    return [t["translatedText"] for t in translations]


async def build_allergy_card(
    allergens: list[str],
    target_language: str,
    severity_by_allergen: dict[str, str] | None = None,
    severity_note: bool = True,
) -> dict:
    severity_by_allergen = severity_by_allergen or {}

    # Build English source strings.
    statements_en = []
    for a in allergens:
        sev = severity_by_allergen.get(a, "moderate")
        if severity_note:
            statements_en.append(
                f"I have a {sev} allergy to {a}. Please ensure no cross-contamination."
            )
        else:
            statements_en.append(f"I am allergic to {a}. Please ensure no cross-contamination.")

    to_translate = [CARD_HEADER_EN, EMERGENCY_PHRASE_EN, *allergens, *statements_en]
    translated = await translate_texts(to_translate, target_language)

    header_t = translated[0]
    emergency_t = translated[1]
    names_t = translated[2 : 2 + len(allergens)]
    statements_t = translated[2 + len(allergens) :]

    allergen_statements = [
        {
            "allergen": allergens[i],
            "translated_name": names_t[i],
            "translated_statement": statements_t[i],
        }
        for i in range(len(allergens))
    ]

    full_card_text = header_t + "\n" + "\n".join(s["translated_statement"] for s in allergen_statements)
    full_card_text += "\n\n" + emergency_t

    return {
        "target_language": target_language,
        "language_name": SUPPORTED_LANGUAGES.get(target_language, target_language),
        "allergen_statements": allergen_statements,
        "emergency_phrase": emergency_t,
        "full_card_text": full_card_text,
    }

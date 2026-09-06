from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from constants import BIG_14_ALLERGENS, SUPPORTED_LANGUAGES
from deps import get_current_user
from models.user import User
from services import translation_service

router = APIRouter(prefix="/api/v1/translation", tags=["translation"])


class AllergyCardRequest(BaseModel):
    allergens: list[str]
    target_language: str
    severity_note: bool = True
    severity_by_allergen: dict[str, str] | None = None


@router.post("/allergy-card")
async def allergy_card(body: AllergyCardRequest, user: User = Depends(get_current_user)):
    try:
        return await translation_service.build_allergy_card(
            body.allergens, body.target_language, body.severity_by_allergen, body.severity_note
        )
    except translation_service.TranslationUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@router.get("/languages")
async def languages():
    return [{"code": code, "name": name} for code, name in SUPPORTED_LANGUAGES.items()]


@router.get("/offline-cache")
async def offline_cache(user: User = Depends(get_current_user)):
    """Pre-translate Big-14 allergen names into all supported languages for offline use.

    Returns an empty cache (with a notice) when translation is not configured.
    """
    from config import settings

    if not settings.google_translate_api_key:
        return {"configured": False, "cache": {}, "note": "Translation API key not configured."}

    cache: dict[str, dict[str, str]] = {}
    for code in SUPPORTED_LANGUAGES:
        try:
            translated = await translation_service.translate_texts(BIG_14_ALLERGENS, code)
            cache[code] = dict(zip(BIG_14_ALLERGENS, translated))
        except translation_service.TranslationUnavailable:
            break
    return {"configured": True, "cache": cache}

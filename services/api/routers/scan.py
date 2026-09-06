from datetime import datetime, timezone
from types import SimpleNamespace

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.user import User, UserGoal
from schemas.food import BarcodeRequest, TextSearchRequest
from services import ai_scanner, food_database
from services.allergen_matcher import cross_reference
from services.food_grader import grade_meal
from services.media import InvalidImage, store_scan_image, validate_image

router = APIRouter(prefix="/api/v1/scan", tags=["scan"])


async def _latest_goal(db: AsyncSession, user_id) -> UserGoal | None:
    res = await db.execute(
        select(UserGoal).where(UserGoal.user_id == user_id).order_by(UserGoal.updated_at.desc())
    )
    return res.scalars().first()


def _ingredients_to_items(ingredients: list[dict]) -> list[SimpleNamespace]:
    items = []
    for ing in ingredients:
        qty = ing.get("quantity_estimate_g") or 100
        factor = qty / 100.0
        flags = []
        cat = ing.get("common_allergen_category")
        if ing.get("is_allergen_candidate") and cat:
            flags.append(cat)
        items.append(
            SimpleNamespace(
                ingredient_name=ing.get("name", "unknown"),
                quantity_g=qty,
                protein_g=(ing.get("protein_g_per_100g") or 0) * factor,
                carbs_g=(ing.get("carbs_g_per_100g") or 0) * factor,
                fat_g=(ing.get("fat_g_per_100g") or 0) * factor,
                fiber_g=(ing.get("fiber_g_per_100g") or 0) * factor,
                calories=(ing.get("calories_per_100g") or 0) * factor,
                allergen_flags=flags,
                nova_group=None,
            )
        )
    return items


@router.post("/camera")
async def scan_camera(
    image: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    data = await image.read()
    try:
        validate_image(data)
    except InvalidImage as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    image_url = store_scan_image(str(user.id), data)

    try:
        result = await ai_scanner.analyze_food_image(data)
    except ai_scanner.ScannerUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc))

    items = _ingredients_to_items(result.get("ingredients", []))
    nova = result.get("processing_level")
    for it in items:
        it.nova_group = nova
    grade = grade_meal(items, await _latest_goal(db, user.id), user.allergies, datetime.now(timezone.utc), "lunch")
    allergen_matches = cross_reference(result.get("allergen_flags", []), user.allergies)

    return {
        "image_url": image_url,
        "analysis": result,
        "allergen_matches": allergen_matches,
        "grade": grade,
    }


@router.post("/barcode")
async def scan_barcode(
    body: BarcodeRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    product = await food_database.barcode_lookup(body.barcode)
    if not product.get("found"):
        return {"found": False, "barcode": body.barcode}

    allergen_matches = cross_reference(product.get("allergens", []), user.allergies)

    # Build a gradeable single-item meal from per-100g macros.
    m = product.get("macros_per_100g", {})
    item = SimpleNamespace(
        ingredient_name=product["name"],
        protein_g=m.get("protein_g", 0),
        fiber_g=m.get("fiber_g", 0),
        nova_group=product.get("nova_group"),
        allergen_flags=product.get("allergens", []),
    )
    grade = grade_meal([item], await _latest_goal(db, user.id), user.allergies, datetime.now(timezone.utc), "snack")

    return {**product, "allergen_matches": allergen_matches, "grade": grade}


@router.post("/text")
async def scan_text(
    body: TextSearchRequest,
    user: User = Depends(get_current_user),
):
    try:
        result = await food_database.text_search(body.query, body.quantity_g)
    except food_database.FoodDBUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc))

    for item in result.get("items", []):
        item["allergen_matches"] = cross_reference(item.get("allergens", []), user.allergies)
    return result

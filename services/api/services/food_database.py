import httpx

from config import settings

OFF_BASE = "https://world.openfoodfacts.org/api/v2/product"
NUTRITIONIX_BASE = "https://trackapi.nutritionix.com/v2"
USER_AGENT = "AllergyDetect/1.0 (https://allergydetect.app)"


class FoodDBUnavailable(Exception):
    pass


def _num(v, default=0.0) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def _map_off_product(barcode: str, product: dict) -> dict:
    n = product.get("nutriments", {})
    allergens = [
        t.split(":")[-1].replace("-", " ")
        for t in product.get("allergens_tags", [])
        if t
    ]
    return {
        "found": True,
        "source": "open_food_facts",
        "barcode": barcode,
        "name": product.get("product_name") or product.get("generic_name") or "Unknown product",
        "brand": product.get("brands"),
        "image_url": product.get("image_url"),
        "ingredients_text": product.get("ingredients_text"),
        "nutriscore": (product.get("nutriscore_grade") or "").upper() or None,
        "nova_group": int(product["nova_group"]) if product.get("nova_group") else None,
        "allergens": allergens,
        "serving_size_g": _num(product.get("serving_quantity"), 100) or 100,
        "macros_per_100g": {
            "calories": _num(n.get("energy-kcal_100g")),
            "protein_g": _num(n.get("proteins_100g")),
            "carbs_g": _num(n.get("carbohydrates_100g")),
            "fat_g": _num(n.get("fat_100g")),
            "fiber_g": _num(n.get("fiber_100g")),
            "sugar_g": _num(n.get("sugars_100g")),
            "sodium_mg": _num(n.get("sodium_100g")) * 1000,
            "saturated_fat_g": _num(n.get("saturated-fat_100g")),
        },
        "open_food_facts_id": barcode,
    }


def _map_nutritionix_item(item: dict) -> dict:
    return {
        "found": True,
        "source": "nutritionix",
        "name": item.get("food_name") or item.get("brand_name_item_name") or "Unknown",
        "brand": item.get("brand_name"),
        "image_url": (item.get("photo") or {}).get("thumb"),
        "nova_group": None,
        "nutriscore": None,
        "allergens": [],
        "serving_size_g": _num(item.get("serving_weight_grams"), 100) or 100,
        "macros_per_serving": {
            "calories": _num(item.get("nf_calories")),
            "protein_g": _num(item.get("nf_protein")),
            "carbs_g": _num(item.get("nf_total_carbohydrate")),
            "fat_g": _num(item.get("nf_total_fat")),
            "fiber_g": _num(item.get("nf_dietary_fiber")),
            "sugar_g": _num(item.get("nf_sugars")),
            "sodium_mg": _num(item.get("nf_sodium")),
            "saturated_fat_g": _num(item.get("nf_saturated_fat")),
        },
    }


def _nutritionix_headers() -> dict:
    return {
        "x-app-id": settings.nutritionix_app_id,
        "x-app-key": settings.nutritionix_api_key,
        "Content-Type": "application/json",
    }


async def barcode_lookup(barcode: str) -> dict:
    """Open Food Facts first, then Nutritionix UPC, else {found: False}."""
    async with httpx.AsyncClient(timeout=15, headers={"User-Agent": USER_AGENT}) as client:
        try:
            r = await client.get(f"{OFF_BASE}/{barcode}.json")
            if r.status_code == 200:
                body = r.json()
                if body.get("status") == 1 and body.get("product"):
                    return _map_off_product(barcode, body["product"])
        except httpx.HTTPError:
            pass

        if settings.nutritionix_app_id and settings.nutritionix_api_key:
            try:
                r = await client.get(
                    f"{NUTRITIONIX_BASE}/search/item",
                    params={"upc": barcode},
                    headers=_nutritionix_headers(),
                )
                if r.status_code == 200:
                    foods = r.json().get("foods") or []
                    if foods:
                        return _map_nutritionix_item(foods[0])
            except httpx.HTTPError:
                pass

    return {"found": False, "barcode": barcode}


async def text_search(query: str, quantity_g: float | None = None) -> dict:
    """Nutritionix natural-language nutrients endpoint (key-gated)."""
    if not (settings.nutritionix_app_id and settings.nutritionix_api_key):
        raise FoodDBUnavailable(
            "NUTRITIONIX credentials are not configured; text food search is unavailable."
        )
    async with httpx.AsyncClient(timeout=15, headers={"User-Agent": USER_AGENT}) as client:
        r = await client.post(
            f"{NUTRITIONIX_BASE}/natural/nutrients",
            json={"query": query},
            headers=_nutritionix_headers(),
        )
        r.raise_for_status()
        foods = r.json().get("foods") or []
    items = [_map_nutritionix_item(f) for f in foods]
    return {"found": bool(items), "query": query, "items": items}

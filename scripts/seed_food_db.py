"""Seed a few public sample recipes into the database for demo/testing.

Usage (from services/api with the venv active):
    python ../../scripts/seed_food_db.py <user_email>

It pulls a handful of real products from Open Food Facts and stores them as
public custom_meals so the community recipe feed has content out of the box.
"""
import asyncio
import sys
from pathlib import Path

# Make the api package importable.
API_DIR = Path(__file__).resolve().parent.parent / "services" / "api"
sys.path.insert(0, str(API_DIR))

import httpx  # noqa: E402
from sqlalchemy import select  # noqa: E402

from database import AsyncSessionLocal  # noqa: E402
from models.food_log import CustomMeal  # noqa: E402
from models.user import User  # noqa: E402

SAMPLE_BARCODES = ["3017620422003", "5449000000996", "8000500037560"]
OFF = "https://world.openfoodfacts.org/api/v2/product"


async def main(email: str) -> None:
    async with AsyncSessionLocal() as db:
        user = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
        if user is None:
            print(f"No user with email {email}; register one first.")
            return

        async with httpx.AsyncClient(timeout=20) as client:
            for code in SAMPLE_BARCODES:
                r = await client.get(f"{OFF}/{code}.json")
                if r.status_code != 200 or r.json().get("status") != 1:
                    continue
                p = r.json()["product"]
                n = p.get("nutriments", {})
                meal = CustomMeal(
                    user_id=user.id,
                    name=p.get("product_name") or f"Product {code}",
                    ingredients=[{"name": p.get("product_name"), "quantity_g": 100}],
                    macros={
                        "calories": n.get("energy-kcal_100g", 0),
                        "protein_g": n.get("proteins_100g", 0),
                        "carbs_g": n.get("carbohydrates_100g", 0),
                        "fat_g": n.get("fat_100g", 0),
                    },
                    allergen_tags=[t.split(":")[-1] for t in p.get("allergens_tags", [])],
                    is_public=True,
                )
                db.add(meal)
                print(f"seeded: {meal.name}")
        await db.commit()
    print("done.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python seed_food_db.py <user_email>")
        sys.exit(1)
    asyncio.run(main(sys.argv[1]))

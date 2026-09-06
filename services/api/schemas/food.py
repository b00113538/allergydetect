import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class FoodLogItemIn(BaseModel):
    ingredient_name: str
    quantity_g: float = 100
    calories: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None
    fiber_g: float | None = None
    sugar_g: float | None = None
    sodium_mg: float | None = None
    saturated_fat_g: float | None = None
    allergen_flags: list[str] = Field(default_factory=list)
    confidence_score: float = 1.0
    nova_group: int | None = None
    nutriscore: str | None = None
    usda_fdc_id: int | None = None
    open_food_facts_id: str | None = None


class FoodLogItemOut(FoodLogItemIn):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    food_grade: str | None = None


class FoodLogCreate(BaseModel):
    meal_type: str = Field(pattern="^(breakfast|lunch|dinner|snack)$")
    source: str = Field(pattern="^(camera|barcode|manual|custom)$")
    food_image_url: str | None = None
    notes: str | None = None
    items: list[FoodLogItemIn]
    logged_at: datetime | None = None


class FoodLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    logged_at: datetime
    meal_type: str
    source: str
    food_image_url: str | None = None
    notes: str | None = None
    total_calories: float
    meal_grade: str | None = None
    items: list[FoodLogItemOut] = []


class MacroTotals(BaseModel):
    calories: float = 0
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0
    fiber_g: float = 0
    sugar_g: float = 0
    sodium_mg: float = 0


class GoalProgress(BaseModel):
    calories_pct: float = 0
    protein_pct: float = 0
    carbs_pct: float = 0
    fat_pct: float = 0


class TodayResponse(BaseModel):
    date: str
    logs: list[FoodLogOut]
    totals: MacroTotals
    goal_progress: GoalProgress
    daily_scores: dict


class ItemsUpdate(BaseModel):
    items: list[FoodLogItemIn]


class BarcodeRequest(BaseModel):
    barcode: str


class TextSearchRequest(BaseModel):
    query: str
    quantity_g: float | None = None

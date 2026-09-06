import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class PostCreate(BaseModel):
    post_type: str = Field(pattern="^(question|tip|story|recipe|warning)$")
    title: str | None = None
    content: str
    allergen_tags: list[str] = Field(default_factory=list)
    is_anonymous: bool = True


class PostUpdate(BaseModel):
    title: str | None = None
    content: str | None = None
    allergen_tags: list[str] | None = None


class PostOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    post_type: str
    title: str | None = None
    content: str
    allergen_tags: list[str] = []
    upvotes: int = 0
    is_anonymous: bool = True
    created_at: datetime


class RecipeIngredient(BaseModel):
    name: str
    quantity_g: float = 100
    calories: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None


class RecipeCreate(BaseModel):
    name: str
    ingredients: list[RecipeIngredient]
    allergen_tags: list[str] = Field(default_factory=list)
    is_public: bool = True


class RecipeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str
    ingredients: list[dict]
    macros: dict
    allergen_tags: list[str] = []
    use_count: int = 0
    created_at: datetime

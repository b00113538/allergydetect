import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = Field(min_length=1, max_length=255)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class ProfileUpdate(BaseModel):
    name: str | None = None
    dob: date | None = None
    biological_sex: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    activity_level: str | None = None
    timezone: str | None = None
    locale: str | None = None
    onboarding_complete: bool | None = None


class GoalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    goal_type: str
    tdee_kcal: int | None = None
    calories_target: int | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None
    fiber_g: float | None = None
    water_ml: int = 2000
    sodium_mg: float | None = None


class GoalUpsert(BaseModel):
    goal_type: str
    calories_target: int | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None
    fiber_g: float | None = None
    water_ml: int | None = None
    sodium_mg: float | None = None


class AllergyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    allergen_name: str
    allergen_category: str | None = None
    severity: str
    confirmed_by_doctor: bool = False


class AllergyCreate(BaseModel):
    allergen_name: str
    allergen_category: str | None = None
    severity: str = "moderate"
    confirmed_by_doctor: bool = False


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    email: EmailStr
    name: str
    dob: date | None = None
    biological_sex: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    activity_level: str = "moderate"
    timezone: str = "UTC"
    locale: str = "en"
    avatar_url: str | None = None
    onboarding_complete: bool = False
    created_at: datetime | None = None


class MeResponse(BaseModel):
    user: UserOut
    goals: list[GoalOut] = []
    allergies: list[AllergyOut] = []


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

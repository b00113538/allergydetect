import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class SymptomCreate(BaseModel):
    symptoms: list[str]
    severity: int = Field(ge=1, le=10)
    notes: str | None = None
    linked_food_log_ids: list[uuid.UUID] | None = None
    logged_at: datetime | None = None


class SymptomOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    logged_at: datetime
    symptoms: list[str]
    severity: int
    notes: str | None = None
    linked_food_log_ids: list[uuid.UUID] = []
    anaphylaxis_suspected: bool = False


class SymptomCreateResponse(BaseModel):
    symptom: SymptomOut
    emergency_flag: bool

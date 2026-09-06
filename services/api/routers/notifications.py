from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.user import User
from services.notification_scheduler import get_preferences, save_preferences

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


class RegisterTokenRequest(BaseModel):
    expo_push_token: str
    platform: str


class PreferencesRequest(BaseModel):
    symptom_checkin_enabled: bool = True
    symptom_checkin_delay_minutes: int = 45
    daily_reminder_enabled: bool = True
    daily_reminder_time: str = "19:00"
    weekly_report_enabled: bool = True
    allergen_alert_enabled: bool = True
    quiet_hours_start: str = "22:00"
    quiet_hours_end: str = "07:00"


@router.post("/register-token")
async def register_token(
    body: RegisterTokenRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    user.expo_push_token = body.expo_push_token
    user.push_platform = body.platform
    await db.flush()
    return {"registered": True}


@router.post("/preferences")
async def set_preferences(
    body: PreferencesRequest, user: User = Depends(get_current_user)
):
    await save_preferences(str(user.id), body.model_dump())
    return {"saved": True}


@router.get("/preferences")
async def read_preferences(user: User = Depends(get_current_user)):
    return await get_preferences(str(user.id))

import json

import httpx

from config import settings
from redis_client import redis_client

EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send"


async def send_push(expo_push_token: str, title: str, body: str, data: dict | None = None) -> dict:
    """Send an Expo push. No-op (returns skipped) when no token is present."""
    if not expo_push_token:
        return {"sent": False, "reason": "no_token"}

    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if settings.expo_access_token:
        headers["Authorization"] = f"Bearer {settings.expo_access_token}"

    payload = {"to": expo_push_token, "title": title, "body": body, "sound": "default", "data": data or {}}
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.post(EXPO_PUSH_URL, headers=headers, json=payload)
            return {"sent": r.status_code == 200, "status": r.status_code}
    except httpx.HTTPError as exc:
        return {"sent": False, "reason": str(exc)}


def _prefs_key(user_id: str) -> str:
    return f"notif:prefs:{user_id}"


async def save_preferences(user_id: str, prefs: dict) -> None:
    await redis_client.set(_prefs_key(user_id), json.dumps(prefs))


async def get_preferences(user_id: str) -> dict:
    raw = await redis_client.get(_prefs_key(user_id))
    if raw:
        return json.loads(raw)
    return {
        "symptom_checkin_enabled": True,
        "symptom_checkin_delay_minutes": 45,
        "daily_reminder_enabled": True,
        "daily_reminder_time": "19:00",
        "weekly_report_enabled": True,
        "allergen_alert_enabled": True,
        "quiet_hours_start": "22:00",
        "quiet_hours_end": "07:00",
    }

from sqlalchemy import select

from tasks import run_async, task_session
from tasks.celery_app import celery_app


@celery_app.task(name="tasks.notification_task.schedule_meal_followup")
def schedule_meal_followup(user_id: str, meal_id: str, meal_type: str):
    """Sent ~45 min after a meal (via countdown) to prompt a symptom check-in."""

    async def _work():
        from models.user import User
        from services.notification_scheduler import get_preferences, send_push

        engine, maker = task_session()
        try:
            async with maker() as db:
                res = await db.execute(select(User).where(User.id == user_id))
                user = res.scalar_one_or_none()
                if user is None or not user.expo_push_token:
                    return {"sent": False, "reason": "no_user_or_token"}
                prefs = await get_preferences(str(user_id))
                if not prefs.get("symptom_checkin_enabled", True):
                    return {"sent": False, "reason": "disabled"}
                return await send_push(
                    user.expo_push_token,
                    "How are you feeling?",
                    f"You logged a {meal_type} ~45 minutes ago. Any symptoms to log?",
                    {"type": "symptom_checkin", "meal_id": meal_id},
                )
        finally:
            await engine.dispose()

    return run_async(_work())

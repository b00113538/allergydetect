from datetime import date, timedelta

from sqlalchemy import select

from tasks import run_async, task_session
from tasks.celery_app import celery_app


@celery_app.task(name="tasks.streak_task.validate_all_streaks")
def validate_all_streaks():
    """Break logging streaks for users who logged < 2 meals yesterday."""

    async def _work():
        from models.user import User
        from services.streak_engine import break_streak, count_meals_for_date

        yesterday = date.today() - timedelta(days=1)
        engine, maker = task_session()
        broken = 0
        try:
            async with maker() as db:
                res = await db.execute(select(User.id))
                for (user_id,) in res.all():
                    if await count_meals_for_date(db, user_id, yesterday) < 2:
                        await break_streak(db, user_id, "logging", yesterday)
                        broken += 1
                await db.commit()
        finally:
            await engine.dispose()
        return broken

    return run_async(_work())

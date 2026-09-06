from datetime import date, timedelta

from sqlalchemy import select

from tasks import run_async, task_session
from tasks.celery_app import celery_app


@celery_app.task(name="tasks.report_task.generate_weekly_reports")
def generate_weekly_reports():
    """Pre-compute last week's report and store it as an AI insight per user."""

    async def _work():
        from models.insight import AIInsight
        from models.user import User
        from services.report_generator import weekly_report

        last_monday = date.today() - timedelta(days=date.today().weekday() + 7)
        engine, maker = task_session()
        generated = 0
        try:
            async with maker() as db:
                res = await db.execute(select(User.id))
                for (user_id,) in res.all():
                    report = await weekly_report(db, user_id, last_monday)
                    db.add(
                        AIInsight(
                            user_id=user_id,
                            insight_type="weekly_report",
                            content={"week_start": last_monday.isoformat(), "report": report},
                        )
                    )
                    generated += 1
                await db.commit()
        finally:
            await engine.dispose()
        return generated

    return run_async(_work())

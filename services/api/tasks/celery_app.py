from celery import Celery
from celery.schedules import crontab

from config import settings

celery_app = Celery(
    "allergydetect",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=[
        "tasks.correlation_task",
        "tasks.streak_task",
        "tasks.report_task",
        "tasks.notification_task",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
    beat_schedule={
        "validate-streaks-nightly": {
            "task": "tasks.streak_task.validate_all_streaks",
            "schedule": crontab(hour=0, minute=5),
        },
        "weekly-reports-monday": {
            "task": "tasks.report_task.generate_weekly_reports",
            "schedule": crontab(hour=8, minute=0, day_of_week=1),
        },
    },
)

from tasks import run_async, task_session
from tasks.celery_app import celery_app


@celery_app.task(name="tasks.correlation_task.run_correlation_task")
def run_correlation_task(user_id: str, symptom_log_id: str | None = None):
    """Background allergen correlation after a symptom log."""

    async def _work():
        from services.allergen_correlator import run_correlation

        engine, maker = task_session()
        try:
            async with maker() as db:
                candidates = await run_correlation(db, user_id, symptom_log_id)
                await db.commit()
                return len(candidates)
        finally:
            await engine.dispose()

    return run_async(_work())

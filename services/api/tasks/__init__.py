"""Celery entrypoint. `celery -A tasks worker` discovers `app` here."""
import asyncio

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from config import settings
from tasks.celery_app import celery_app as app

__all__ = ["app", "run_async", "task_session"]


def run_async(coro):
    """Run an async coroutine to completion from a synchronous Celery task."""
    return asyncio.run(coro)


def task_session():
    """Fresh engine + sessionmaker per task run (avoids cross-event-loop pool reuse)."""
    engine = create_async_engine(settings.database_url, pool_pre_ping=True)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    return engine, maker

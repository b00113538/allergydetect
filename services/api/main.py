import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from redis_client import redis_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    os.makedirs(settings.local_media_dir, exist_ok=True)
    yield
    await redis_client.aclose()


app = FastAPI(title="AllergyDetect API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    redis_ok = False
    try:
        redis_ok = await redis_client.ping()
    except Exception:
        redis_ok = False
    return {"status": "ok", "redis": redis_ok}


def register_routers() -> None:
    from routers import (
        auth,
        coach,
        community,
        food_log,
        insights,
        notifications,
        reports,
        scan,
        symptoms,
        translation,
        users,
        wearables,
    )

    for module in (
        auth,
        users,
        scan,
        food_log,
        symptoms,
        insights,
        coach,
        reports,
        wearables,
        translation,
        community,
        notifications,
    ):
        app.include_router(module.router)


register_routers()

from collections import defaultdict
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.symptom_log import SymptomLog
from models.user import User
from models.wearable import WearableReading

router = APIRouter(prefix="/api/v1/wearables", tags=["wearables"])


class Reading(BaseModel):
    metric: str
    value: float
    unit: str | None = None
    recorded_at: datetime


class SyncRequest(BaseModel):
    source: str
    readings: list[Reading]


@router.post("/sync")
async def sync(body: SyncRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    count = 0
    for r in body.readings:
        stmt = pg_insert(WearableReading).values(
            user_id=user.id,
            source=body.source,
            metric=r.metric,
            value=r.value,
            unit=r.unit,
            recorded_at=r.recorded_at,
        )
        # No natural unique constraint in schema; emulate idempotency by skipping exact dupes.
        existing = await db.execute(
            select(WearableReading.id).where(
                WearableReading.user_id == user.id,
                WearableReading.metric == r.metric,
                WearableReading.recorded_at == r.recorded_at,
            )
        )
        if existing.scalar_one_or_none() is None:
            await db.execute(stmt)
            count += 1
    await db.flush()
    return {"synced_count": count}


@router.get("/summary")
async def summary(days: int = 7, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    since = datetime.now(timezone.utc) - timedelta(days=days)
    res = await db.execute(
        select(WearableReading.metric, func.avg(WearableReading.value))
        .where(WearableReading.user_id == user.id, WearableReading.recorded_at >= since)
        .group_by(WearableReading.metric)
    )
    averages = {m: round(v, 1) for m, v in res.all()}

    # Daily breakdown for charts.
    daily_res = await db.execute(
        select(
            func.date(WearableReading.recorded_at).label("d"),
            WearableReading.metric,
            func.avg(WearableReading.value),
        )
        .where(WearableReading.user_id == user.id, WearableReading.recorded_at >= since)
        .group_by("d", WearableReading.metric)
        .order_by("d")
    )
    daily: dict[str, dict] = defaultdict(dict)
    for d, metric, val in daily_res.all():
        daily[d.isoformat()][metric] = round(val, 1)

    return {
        "avg_hrv": averages.get("hrv"),
        "avg_resting_hr": averages.get("resting_hr") or averages.get("heart_rate"),
        "avg_sleep_score": averages.get("sleep_score"),
        "avg_steps": averages.get("steps"),
        "avg_spo2": averages.get("spo2") or averages.get("oxygen_saturation"),
        "daily": [{"date": k, **v} for k, v in sorted(daily.items())],
    }


@router.get("/reaction-correlation")
async def reaction_correlation(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    since = datetime.now(timezone.utc) - timedelta(days=30)

    # 7-day baselines.
    base_since = datetime.now(timezone.utc) - timedelta(days=7)
    base_res = await db.execute(
        select(WearableReading.metric, func.avg(WearableReading.value))
        .where(WearableReading.user_id == user.id, WearableReading.recorded_at >= base_since)
        .group_by(WearableReading.metric)
    )
    baselines = {m: v for m, v in base_res.all()}
    hrv_base = baselines.get("hrv")
    hr_base = baselines.get("resting_hr") or baselines.get("heart_rate")

    sym_res = await db.execute(
        select(SymptomLog).where(SymptomLog.user_id == user.id, SymptomLog.logged_at >= since)
    )
    out = []
    for s in sym_res.scalars().all():
        win_start = s.logged_at + timedelta(hours=1)
        win_end = s.logged_at + timedelta(hours=3)
        w_res = await db.execute(
            select(WearableReading.metric, func.avg(WearableReading.value))
            .where(
                WearableReading.user_id == user.id,
                WearableReading.recorded_at >= win_start,
                WearableReading.recorded_at <= win_end,
            )
            .group_by(WearableReading.metric)
        )
        win = {m: v for m, v in w_res.all()}
        hrv_after = win.get("hrv")
        hr_after = win.get("resting_hr") or win.get("heart_rate")
        out.append(
            {
                "date": s.logged_at.date().isoformat(),
                "reaction": True,
                "severity": s.severity,
                "hrv_delta": round(hrv_after - hrv_base, 1) if (hrv_after and hrv_base) else None,
                "hr_delta": round(hr_after - hr_base, 1) if (hr_after and hr_base) else None,
            }
        )
    return out

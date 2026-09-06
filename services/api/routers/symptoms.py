from collections import defaultdict
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from constants import ANAPHYLAXIS_SYMPTOMS
from database import get_db
from deps import get_current_user
from models.food_log import FoodLog
from models.symptom_log import SymptomLog
from models.user import User
from schemas.symptom import SymptomCreate, SymptomCreateResponse, SymptomOut

router = APIRouter(prefix="/api/v1/symptoms", tags=["symptoms"])


@router.post("", response_model=SymptomCreateResponse, status_code=201)
async def create_symptom(
    body: SymptomCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    logged_at = body.logged_at or datetime.now(timezone.utc)

    # Auto-link to food logs in the 0-8h prior window (unless explicit links given).
    linked = body.linked_food_log_ids or []
    if not linked:
        window_start = logged_at - timedelta(hours=8)
        res = await db.execute(
            select(FoodLog.id).where(
                FoodLog.user_id == user.id,
                FoodLog.is_deleted.is_(False),
                FoodLog.logged_at >= window_start,
                FoodLog.logged_at <= logged_at,
            )
        )
        linked = [r for (r,) in res.all()]

    emergency = body.severity >= 9 or any(
        s in ANAPHYLAXIS_SYMPTOMS for s in body.symptoms
    )

    symptom = SymptomLog(
        user_id=user.id,
        logged_at=logged_at,
        symptoms=body.symptoms,
        severity=body.severity,
        notes=body.notes,
        linked_food_log_ids=linked,
        anaphylaxis_suspected=emergency,
    )
    db.add(symptom)
    await db.flush()

    # Break reaction-free streak if severity > 3.
    from services.streak_engine import update_streaks_for_user

    await update_streaks_for_user(db, user.id, "symptom_log", logged_at.date())

    # Dispatch correlation: Celery when a worker is configured, else inline so
    # insights still appear in local dev.
    await db.commit()
    from config import settings

    dispatched = False
    if settings.use_celery:
        try:
            from tasks.correlation_task import run_correlation_task

            run_correlation_task.delay(str(user.id), str(symptom.id))
            dispatched = True
        except Exception:  # noqa: BLE001 — broker unreachable: fall back to inline
            dispatched = False
    if not dispatched:
        from services.allergen_correlator import run_correlation

        await run_correlation(db, user.id, symptom.id)
        await db.commit()

    return SymptomCreateResponse(symptom=SymptomOut.model_validate(symptom), emergency_flag=emergency)


@router.get("", response_model=list[SymptomOut])
async def list_symptoms(
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    limit: int = Query(20, le=100),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = select(SymptomLog).where(SymptomLog.user_id == user.id)
    if start_date:
        q = q.where(SymptomLog.logged_at >= start_date)
    if end_date:
        q = q.where(SymptomLog.logged_at <= end_date)
    q = q.order_by(SymptomLog.logged_at.desc()).limit(limit).offset(offset)
    res = await db.execute(q)
    return [SymptomOut.model_validate(s) for s in res.scalars().all()]


@router.get("/weekly-summary")
async def weekly_summary(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    since = datetime.now(timezone.utc) - timedelta(days=7)
    res = await db.execute(
        select(SymptomLog).where(SymptomLog.user_id == user.id, SymptomLog.logged_at >= since)
    )
    logs = res.scalars().all()

    by_day: dict[str, dict] = defaultdict(lambda: {"count": 0, "severity_sum": 0})
    by_symptom: dict[str, int] = defaultdict(int)
    for log in logs:
        day = log.logged_at.date().isoformat()
        by_day[day]["count"] += 1
        by_day[day]["severity_sum"] += log.severity
        for s in log.symptoms:
            by_symptom[s] += 1

    daily = [
        {"date": d, "count": v["count"], "avg_severity": round(v["severity_sum"] / v["count"], 1)}
        for d, v in sorted(by_day.items())
    ]
    return {
        "daily": daily,
        "by_symptom": dict(by_symptom),
        "total": len(logs),
        "avg_severity": round(sum(s.severity for s in logs) / len(logs), 1) if logs else 0,
    }

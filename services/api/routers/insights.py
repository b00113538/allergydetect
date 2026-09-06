import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.insight import AIInsight, AllergenCandidate
from models.user import User
from services.allergen_correlator import run_correlation

router = APIRouter(prefix="/api/v1/insights", tags=["insights"])


@router.get("/allergen-candidates")
async def allergen_candidates(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    res = await db.execute(
        select(AllergenCandidate)
        .where(AllergenCandidate.user_id == user.id)
        .order_by(AllergenCandidate.confidence_score.desc())
        .limit(10)
    )
    return [
        {
            "ingredient_name": c.ingredient_name,
            "confidence_score": round(c.confidence_score, 4),
            "symptom_exposure_count": c.symptom_exposure_count,
            "total_exposure_count": c.total_exposure_count,
            "avg_severity_when_exposed": c.avg_severity_when_exposed,
            "label": f"{round(c.confidence_score * 100)}% likely trigger",
        }
        for c in res.scalars().all()
    ]


@router.get("/recent")
async def recent_insights(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    res = await db.execute(
        select(AIInsight)
        .where(AIInsight.user_id == user.id, AIInsight.dismissed.is_(False))
        .order_by(AIInsight.generated_at.desc())
        .limit(20)
    )
    return [
        {
            "id": str(i.id),
            "insight_type": i.insight_type,
            "content": i.content,
            "read": i.read,
            "generated_at": i.generated_at.isoformat() if i.generated_at else None,
        }
        for i in res.scalars().all()
    ]


@router.post("/{insight_id}/read", status_code=204)
async def mark_read(insight_id: uuid.UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    res = await db.execute(
        select(AIInsight).where(AIInsight.id == insight_id, AIInsight.user_id == user.id)
    )
    insight = res.scalar_one_or_none()
    if insight is None:
        raise HTTPException(status_code=404, detail="Insight not found")
    insight.read = True
    await db.flush()
    return None


@router.post("/trigger-correlation")
async def trigger_correlation(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    candidates = await run_correlation(db, user.id)
    return {"candidates": candidates[:10], "count": len(candidates)}


@router.get("/weekly-summary")
async def weekly_ai_summary(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    """AI-generated plain-English weekly summary (falls back to a deterministic summary
    when OPENAI_API_KEY is not configured)."""
    from services.coach_service import build_user_context

    context = await build_user_context(db, user)

    from config import settings

    if not settings.openai_api_key:
        sym = context["symptom_summary_30d"]
        cands = context["top_allergen_candidates"]
        top = cands[0]["ingredient"] if cands else "none yet"
        return {
            "summary": (
                f"This period you logged {sym['count']} symptom event(s) "
                f"(avg severity {sym['avg_severity']}). Top suspected trigger: {top}. "
                f"Keep logging meals consistently to sharpen these insights."
            ),
            "ai_generated": False,
        }

    from openai import AsyncOpenAI
    import json

    client = AsyncOpenAI(api_key=settings.openai_api_key)
    resp = await client.chat.completions.create(
        model=settings.openai_model,
        messages=[
            {"role": "system", "content": "You summarise a user's weekly food-allergy patterns in 3-4 plain sentences."},
            {"role": "user", "content": f"Summarise this week:\n{json.dumps(context)}"},
        ],
        max_tokens=200,
        temperature=0.5,
    )
    return {"summary": (resp.choices[0].message.content or "").strip(), "ai_generated": True}

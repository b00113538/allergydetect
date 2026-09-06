import json
import uuid
from datetime import datetime, timedelta, timezone

from openai import AsyncOpenAI
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from models.food_log import FoodLog, FoodLogItem
from models.insight import AllergenCandidate
from models.streak import UserBadge, UserStreak
from models.symptom_log import SymptomLog
from models.user import User, UserGoal
from models.wearable import WearableReading
from redis_client import redis_client

CONV_TTL = 24 * 60 * 60
MAX_HISTORY = 20

COACH_SYSTEM_TEMPLATE = (
    "You are AllergyDetect's personal AI health coach. You have access to {user_name}'s health "
    "data below. Your role is to help them understand their food-allergy patterns, optimise their "
    "nutrition, and stay safe.\n\n"
    "USER DATA SUMMARY:\n{json_summary}\n\n"
    "Rules:\n"
    "- Answer ONLY about topics related to this user's actual data\n"
    "- Never fabricate data points not in the summary\n"
    "- For clinical decisions (diagnosis, medication) always say: 'Please discuss this with your "
    "doctor or a registered allergist.'\n"
    "- Keep responses under 150 words unless the user asks for detail\n"
    "- Use an encouraging, expert-friend tone\n"
    "- If asked about anaphylaxis, severe reactions, or emergency symptoms, always recommend "
    "calling emergency services immediately"
)


class CoachUnavailable(Exception):
    pass


def _client() -> AsyncOpenAI:
    if not settings.openai_api_key:
        raise CoachUnavailable("OPENAI_API_KEY is not configured; the AI coach is unavailable.")
    return AsyncOpenAI(api_key=settings.openai_api_key)


async def build_user_context(db: AsyncSession, user: User) -> dict:
    now = datetime.now(timezone.utc)
    since_30 = now - timedelta(days=30)
    since_7 = now - timedelta(days=7)

    # Top ingredients (30d)
    top_ing = await db.execute(
        select(FoodLogItem.ingredient_name, func.count().label("c"))
        .join(FoodLog, FoodLog.id == FoodLogItem.food_log_id)
        .where(FoodLog.user_id == user.id, FoodLog.logged_at >= since_30, FoodLog.is_deleted.is_(False))
        .group_by(FoodLogItem.ingredient_name)
        .order_by(func.count().desc())
        .limit(10)
    )
    top_ingredients = [{"name": n, "count": c} for n, c in top_ing.all()]

    # Avg daily macros (30d)
    macro_row = await db.execute(
        select(
            func.coalesce(func.sum(FoodLogItem.calories), 0),
            func.coalesce(func.sum(FoodLogItem.protein_g), 0),
            func.coalesce(func.sum(FoodLogItem.carbs_g), 0),
            func.coalesce(func.sum(FoodLogItem.fat_g), 0),
        )
        .join(FoodLog, FoodLog.id == FoodLogItem.food_log_id)
        .where(FoodLog.user_id == user.id, FoodLog.logged_at >= since_30, FoodLog.is_deleted.is_(False))
    )
    cal, pro, carb, fat = macro_row.one()
    avg_macros = {
        "calories": round(cal / 30, 1),
        "protein_g": round(pro / 30, 1),
        "carbs_g": round(carb / 30, 1),
        "fat_g": round(fat / 30, 1),
    }

    # Top allergen candidates
    cand_res = await db.execute(
        select(AllergenCandidate)
        .where(AllergenCandidate.user_id == user.id)
        .order_by(AllergenCandidate.confidence_score.desc())
        .limit(5)
    )
    candidates = [
        {"ingredient": c.ingredient_name, "confidence": round(c.confidence_score, 2)}
        for c in cand_res.scalars().all()
    ]

    # Symptom summary (30d)
    sym_res = await db.execute(
        select(SymptomLog).where(SymptomLog.user_id == user.id, SymptomLog.logged_at >= since_30)
    )
    symptoms = sym_res.scalars().all()
    sym_types: dict[str, int] = {}
    for s in symptoms:
        for sym in s.symptoms:
            sym_types[sym] = sym_types.get(sym, 0) + 1
    symptom_summary = {
        "count": len(symptoms),
        "avg_severity": round(sum(s.severity for s in symptoms) / len(symptoms), 1) if symptoms else 0,
        "types": sym_types,
    }

    # Goals
    goal_res = await db.execute(
        select(UserGoal).where(UserGoal.user_id == user.id).order_by(UserGoal.updated_at.desc())
    )
    goal = goal_res.scalars().first()
    goals = (
        {
            "goal_type": goal.goal_type,
            "calories_target": goal.calories_target,
            "protein_g": goal.protein_g,
            "carbs_g": goal.carbs_g,
            "fat_g": goal.fat_g,
        }
        if goal
        else None
    )

    # Streaks & badges
    streaks_res = await db.execute(select(UserStreak).where(UserStreak.user_id == user.id))
    streaks = [
        {"type": s.streak_type, "current": s.current_count, "record": s.record_count}
        for s in streaks_res.scalars().all()
    ]
    badges_res = await db.execute(select(UserBadge.badge_id).where(UserBadge.user_id == user.id))
    badges = [b for (b,) in badges_res.all()]

    # Wearable summary (7d)
    wear_res = await db.execute(
        select(WearableReading.metric, func.avg(WearableReading.value))
        .where(WearableReading.user_id == user.id, WearableReading.recorded_at >= since_7)
        .group_by(WearableReading.metric)
    )
    wearables = {m: round(v, 1) for m, v in wear_res.all()}

    return {
        "name": user.name,
        "top_ingredients_30d": top_ingredients,
        "avg_daily_macros_30d": avg_macros,
        "top_allergen_candidates": candidates,
        "symptom_summary_30d": symptom_summary,
        "goals": goals,
        "streaks": streaks,
        "badges_earned": badges,
        "wearable_summary_7d": wearables,
    }


def _conv_key(conversation_id: str) -> str:
    return f"coach:conv:{conversation_id}"


async def _load_history(conversation_id: str) -> list[dict]:
    raw = await redis_client.get(_conv_key(conversation_id))
    return json.loads(raw) if raw else []


async def _save_history(conversation_id: str, history: list[dict]) -> None:
    trimmed = history[-MAX_HISTORY:]
    await redis_client.set(_conv_key(conversation_id), json.dumps(trimmed), ex=CONV_TTL)


async def chat(db: AsyncSession, user: User, message: str, conversation_id: str | None = None):
    """Returns an async generator yielding text chunks, plus the conversation id.

    Usage: stream, conversation_id = await chat(...); async for chunk in stream: ...
    """
    client = _client()
    conversation_id = conversation_id or uuid.uuid4().hex
    context = await build_user_context(db, user)
    system_prompt = COACH_SYSTEM_TEMPLATE.format(
        user_name=user.name, json_summary=json.dumps(context, indent=2)
    )
    history = await _load_history(conversation_id)
    history.append({"role": "user", "content": message})

    messages = [{"role": "system", "content": system_prompt}, *history]

    async def generator():
        collected = ""
        stream = await client.chat.completions.create(
            model=settings.openai_model, messages=messages, stream=True, temperature=0.5, max_tokens=400
        )
        async for chunk in stream:
            delta = chunk.choices[0].delta.content or ""
            if delta:
                collected += delta
                yield delta
        history.append({"role": "assistant", "content": collected})
        await _save_history(conversation_id, history)

    return generator(), conversation_id


async def daily_insight(db: AsyncSession, user: User) -> str:
    """One proactive tip per day, cached in Redis."""
    cache_key = f"coach:daily:{user.id}:{datetime.now(timezone.utc).date().isoformat()}"
    cached = await redis_client.get(cache_key)
    if cached:
        return cached

    client = _client()
    context = await build_user_context(db, user)
    resp = await client.chat.completions.create(
        model=settings.openai_model,
        messages=[
            {"role": "system", "content": COACH_SYSTEM_TEMPLATE.format(user_name=user.name, json_summary=json.dumps(context))},
            {"role": "user", "content": "Give me ONE short proactive health tip for today based on my data. One sentence."},
        ],
        temperature=0.6,
        max_tokens=80,
    )
    tip = (resp.choices[0].message.content or "").strip()
    await redis_client.set(cache_key, tip, ex=CONV_TTL)
    return tip

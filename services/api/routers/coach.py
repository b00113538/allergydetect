import json

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.user import User
from services import coach_service

router = APIRouter(prefix="/api/v1/coach", tags=["coach"])


class ChatRequest(BaseModel):
    message: str
    conversation_id: str | None = None


@router.post("/chat")
async def chat(
    body: ChatRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Streams the coach reply as Server-Sent Events.

    Each `data:` line is a JSON object: {type: 'chunk'|'done', ...}.
    """
    try:
        stream, conversation_id = await coach_service.chat(db, user, body.message, body.conversation_id)
    except coach_service.CoachUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc))

    async def event_source():
        yield f"data: {json.dumps({'type': 'meta', 'conversation_id': conversation_id})}\n\n"
        async for token in stream:
            yield f"data: {json.dumps({'type': 'chunk', 'text': token})}\n\n"
        # Persisting history requires the DB session; commit after stream completes.
        await db.commit()
        yield f"data: {json.dumps({'type': 'done', 'conversation_id': conversation_id})}\n\n"

    return StreamingResponse(event_source(), media_type="text/event-stream")


@router.get("/daily-insight")
async def daily_insight(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    try:
        tip = await coach_service.daily_insight(db, user)
    except coach_service.CoachUnavailable:
        # Deterministic fallback so the home screen always has content.
        tip = "Log at least two meals today to keep your allergy insights accurate."
    return {"insight": tip}

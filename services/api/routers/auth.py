import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.user import User
from redis_client import redis_client
from schemas.user import (
    AccessTokenResponse,
    MeResponse,
    RefreshRequest,
    TokenResponse,
    UserCreate,
    UserLogin,
    UserOut,
)
from security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    hash_password,
    hash_token,
    refresh_redis_key,
    verify_password,
)
from config import settings

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

REFRESH_TTL = settings.refresh_token_expire_days * 24 * 60 * 60


async def _issue_tokens(user: User) -> TokenResponse:
    access = create_access_token(user.id)
    refresh, refresh_hash = create_refresh_token(user.id)
    await redis_client.set(refresh_redis_key(str(user.id), refresh_hash), "1", ex=REFRESH_TTL)
    return TokenResponse(access_token=access, refresh_token=refresh, user=UserOut.model_validate(user))


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(body: UserCreate, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.email == body.email.lower()))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="Email already registered")
    user = User(email=body.email.lower(), name=body.name, password_hash=hash_password(body.password))
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return await _issue_tokens(user)


@router.post("/login", response_model=TokenResponse)
async def login(body: UserLogin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not user.password_hash or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return await _issue_tokens(user)


@router.post("/refresh", response_model=AccessTokenResponse)
async def refresh(body: RefreshRequest):
    try:
        payload = decode_refresh_token(body.refresh_token)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user_id = payload["sub"]
    key = refresh_redis_key(user_id, hash_token(body.refresh_token))
    if not await redis_client.exists(key):
        raise HTTPException(status_code=401, detail="Refresh token revoked or expired")
    return AccessTokenResponse(access_token=create_access_token(user_id))


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(body: RefreshRequest):
    try:
        payload = decode_refresh_token(body.refresh_token)
        await redis_client.delete(refresh_redis_key(payload["sub"], hash_token(body.refresh_token)))
    except JWTError:
        pass  # idempotent logout
    return None


@router.get("/me", response_model=MeResponse)
async def me(current_user: User = Depends(get_current_user)):
    return MeResponse(
        user=UserOut.model_validate(current_user),
        goals=current_user.goals,
        allergies=current_user.allergies,
    )

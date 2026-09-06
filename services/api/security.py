import hashlib
import uuid
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(user_id: str | uuid.UUID) -> str:
    expire = _now() + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {"sub": str(user_id), "type": "access", "exp": expire, "iat": _now()}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_refresh_token(user_id: str | uuid.UUID) -> tuple[str, str]:
    """Returns (token, token_hash). token_hash is what we store in Redis."""
    jti = uuid.uuid4().hex
    expire = _now() + timedelta(days=settings.refresh_token_expire_days)
    payload = {"sub": str(user_id), "type": "refresh", "jti": jti, "exp": expire, "iat": _now()}
    token = jwt.encode(payload, settings.jwt_refresh_secret, algorithm=settings.jwt_algorithm)
    return token, hash_token(token)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def decode_access_token(token: str) -> dict:
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != "access":
        raise JWTError("Not an access token")
    return payload


def decode_refresh_token(token: str) -> dict:
    payload = jwt.decode(token, settings.jwt_refresh_secret, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != "refresh":
        raise JWTError("Not a refresh token")
    return payload


def refresh_redis_key(user_id: str, token_hash: str) -> str:
    return f"refresh:{user_id}:{token_hash}"

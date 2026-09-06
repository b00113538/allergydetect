from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Core
    jwt_secret: str = "dev-insecure-secret-change-me"
    jwt_refresh_secret: str = "dev-insecure-refresh-secret-change-me"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30
    jwt_algorithm: str = "HS256"

    # Datastores
    database_url: str = "postgresql+asyncpg://ad_user:ad_pass@127.0.0.1:5432/allergydetect"
    redis_url: str = "redis://127.0.0.1:6379/0"

    # When False (local dev with no Celery worker), background jobs run inline.
    # The docker-compose worker sets USE_CELERY=true.
    use_celery: bool = False

    # External APIs (key-gated: features that need these degrade clearly when unset)
    openai_api_key: str | None = None
    openai_model: str = "gpt-4o"
    usda_api_key: str | None = None
    nutritionix_app_id: str | None = None
    nutritionix_api_key: str | None = None
    google_translate_api_key: str | None = None

    # Storage
    aws_access_key_id: str | None = None
    aws_secret_access_key: str | None = None
    aws_region: str = "eu-west-1"
    s3_bucket: str | None = None

    # Local fallback storage when S3 is not configured
    local_media_dir: str = "/tmp/allergydetect-media"

    # Push
    expo_access_token: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()

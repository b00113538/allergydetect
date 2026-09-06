import io
import os
import uuid

from PIL import Image

from config import settings

ALLOWED_FORMATS = {"JPEG", "PNG", "HEIC", "MPO", "WEBP"}
MAX_BYTES = 10 * 1024 * 1024  # 10MB


class InvalidImage(Exception):
    pass


def validate_image(data: bytes) -> str:
    """Validate size/format. Returns a normalized format string. Raises InvalidImage."""
    if len(data) > MAX_BYTES:
        raise InvalidImage("Image exceeds 10MB limit")
    try:
        img = Image.open(io.BytesIO(data))
        fmt = (img.format or "").upper()
    except Exception as exc:  # noqa: BLE001
        raise InvalidImage("File is not a valid image") from exc
    if fmt not in ALLOWED_FORMATS:
        raise InvalidImage(f"Unsupported image format: {fmt or 'unknown'}")
    return fmt


def store_scan_image(user_id: str, data: bytes) -> str:
    """Upload to S3 when configured; otherwise persist locally. Returns a URL/path."""
    key = f"scans/{user_id}/{uuid.uuid4().hex}.jpg"

    if settings.s3_bucket and settings.aws_access_key_id:
        import boto3  # imported lazily so the app runs without AWS configured

        client = boto3.client(
            "s3",
            region_name=settings.aws_region,
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
        )
        client.put_object(Bucket=settings.s3_bucket, Key=key, Body=data, ContentType="image/jpeg")
        return f"s3://{settings.s3_bucket}/{key}"

    # Local fallback
    path = os.path.join(settings.local_media_dir, key)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(data)
    return f"file://{path}"

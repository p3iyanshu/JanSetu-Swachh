"""Photo storage for citizen reports and worker proof photos.

MEDIA_STORAGE=db (default) keeps the bytes in the media_files table and
serves them from /api/v1/media/<id>/<filename>. That works on hosts with an
ephemeral disk (Render free tier wipes local files on every restart).
MEDIA_STORAGE=disk writes under ./uploads and serves them from /uploads,
as the project originally did.
"""

import os
import uuid

from fastapi import HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.models import MediaFile

MAX_UPLOAD_BYTES = 10 * 1024 * 1024
ALLOWED_PREFIX = "image/"


def _storage_mode() -> str:
    return os.getenv("MEDIA_STORAGE", "db").strip().lower()


def _safe_name(filename: str) -> str:
    name = os.path.basename(filename or "photo.jpg")
    return "".join(ch for ch in name if ch.isalnum() or ch in "._-")[-100:] or "photo.jpg"


async def save_upload(db: Session, upload: UploadFile, folder: str = "") -> str:
    """Stores an uploaded image and returns the URL path to fetch it."""
    content = await upload.read()
    if not content:
        raise HTTPException(status_code=400, detail="The uploaded file is empty")
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Photo is too large (max 10 MB)")
    content_type = upload.content_type or "image/jpeg"
    if not content_type.startswith(ALLOWED_PREFIX):
        content_type = "image/jpeg"

    name = _safe_name(upload.filename)
    file_id = str(uuid.uuid4())

    if _storage_mode() == "disk":
        directory = os.path.join("uploads", folder) if folder else "uploads"
        os.makedirs(directory, exist_ok=True)
        filename = f"{file_id}_{name}"
        with open(os.path.join(directory, filename), "wb") as handle:
            handle.write(content)
        return f"/uploads/{folder + '/' if folder else ''}{filename}"

    db.add(MediaFile(id=file_id, filename=name, content_type=content_type, size=len(content), data=content))
    db.commit()
    return f"/api/v1/media/{file_id}/{name}"

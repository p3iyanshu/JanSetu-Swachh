from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import MediaFile

router = APIRouter(prefix="/media", tags=["Media"])


@router.get("/{media_id}/{filename}")
@router.get("/{media_id}")
def get_media(media_id: str, filename: str = "", db: Session = Depends(get_db)):
    media = db.query(MediaFile).filter(MediaFile.id == media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Photo not found")
    return Response(
        content=media.data,
        media_type=media.content_type,
        # Photos never change once uploaded - let browsers/phones cache them.
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )

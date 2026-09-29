from fastapi.testclient import TestClient

from app.database import SessionLocal
from app.main import app
from app.models import MediaFile

client = TestClient(app)

PNG_1X1 = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
    b"\x00\x00\x00\rIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfe\xa7\x9a\xa0\xa6\x00\x00\x00\x00IEND\xaeB`\x82"
)


def test_uploaded_photo_is_stored_in_database_and_served():
    response = client.post(
        "/api/v1/reports/upload-photo",
        files={"file": ("spot photo.png", PNG_1X1, "image/png")},
    )
    assert response.status_code == 200
    photo_url = response.json()["photo_url"]
    assert photo_url.startswith("/api/v1/media/")

    served = client.get(photo_url)
    assert served.status_code == 200
    assert served.content == PNG_1X1
    assert served.headers["content-type"] == "image/png"

    media_id = photo_url.split("/")[4]
    db = SessionLocal()
    try:
        db.query(MediaFile).filter(MediaFile.id == media_id).delete()
        db.commit()
    finally:
        db.close()


def test_empty_upload_is_rejected():
    response = client.post(
        "/api/v1/reports/upload-photo",
        files={"file": ("empty.jpg", b"", "image/jpeg")},
    )
    assert response.status_code == 400


def test_unknown_media_returns_404():
    assert client.get("/api/v1/media/00000000-0000-0000-0000-000000000000").status_code == 404

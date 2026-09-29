import time
import uuid

import pytest
from fastapi.testclient import TestClient

from app.database import SessionLocal
from app.main import app
from app.models import CollectionLog, Report
from app.services.waste_guide import stream_for_label

client = TestClient(app)

# Everything these tests create is removed again afterwards, so running the
# suite doesn't leave fake tickets/wards on the Swachh dashboard.
_created_report_ids: list[int] = []
_created_wards: list[str] = []


@pytest.fixture(autouse=True)
def _cleanup_created_rows():
    yield
    db = SessionLocal()
    try:
        if _created_report_ids:
            db.query(Report).filter(Report.id.in_(_created_report_ids)).delete(synchronize_session=False)
        if _created_wards:
            db.query(CollectionLog).filter(CollectionLog.ward.in_(_created_wards)).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()
        _created_report_ids.clear()
        _created_wards.clear()


def _create_report(payload):
    response = client.post("/api/v1/reports/", json=payload)
    if response.status_code == 201:
        _created_report_ids.append(response.json()["id"])
    return response


def _unique_point():
    # Far away from the Bengaluru demo data and from other test runs, so
    # hotspot clustering only ever sees this test's reports.
    offset = (time.time() % 1000) * 0.01
    return 20.0 + offset, 80.0 + offset


def test_waste_guide_has_four_streams():
    response = client.get("/api/v1/swachh/waste-guide")
    assert response.status_code == 200
    data = response.json()
    assert [stream["id"] for stream in data["streams"]] == ["wet", "dry", "sanitary", "special_care"]
    stream_ids = {stream["id"] for stream in data["streams"]}
    assert data["items"]
    assert all(item["stream"] in stream_ids for item in data["items"])


def test_stream_for_label_mapping():
    assert stream_for_label("banana peel") == "wet"
    assert stream_for_label("Plastic bottles") == "dry"
    assert stream_for_label("sanitary_pad") == "sanitary"
    assert stream_for_label("battery pack") == "special_care"
    assert stream_for_label("") is None
    assert stream_for_label("spaceship") is None


def test_new_swachh_categories_route_to_sanitation():
    lat, lng = _unique_point()
    for category in ("unsegregated_waste", "missed_pickup", "waste_burning", "public_toilet"):
        response = _create_report({
            "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
            "latitude": lat,
            "longitude": lng,
            "category": category,
            "description": f"Swachh test {category}",
        })
        assert response.status_code == 201, response.text
        data = response.json()
        assert data["category"] == category
        assert data["status"] == "assigned"
        assert data["assigned_department_name"] is not None
        department = data["assigned_department_name"].lower()
        assert "waste" in department or "sanitation" in department


def test_hotspot_detection_clusters_nearby_reports():
    lat, lng = _unique_point()
    lat += 0.5  # keep clear of the category test above
    created_ids = []
    for index in range(3):
        response = _create_report({
            "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
            "latitude": lat + index * 0.0002,  # ~22 m apart
            "longitude": lng,
            "category": "illegal_dumping",
            "description": "Recurring dumping spot",
        })
        assert response.status_code == 201
        created_ids.append(response.json()["id"])

    response = client.get("/api/v1/swachh/hotspots", params={"days": 1, "radius_m": 150, "min_reports": 3})
    assert response.status_code == 200
    hotspots = response.json()["hotspots"]
    matching = [spot for spot in hotspots if set(created_ids) <= set(spot["report_ids"])]
    assert len(matching) == 1
    assert matching[0]["report_count"] >= 3
    assert matching[0]["risk"] in {"medium", "high"}


def test_collection_logs_and_segregation_stats():
    ward = f"Test Ward {uuid.uuid4().hex[:6]}"
    _created_wards.append(ward)
    visits = [
        ("h-001", "segregated"),
        ("h-002", "mixed"),
        ("h-002", "mixed"),
        ("h-003", "partial"),
        ("h-004", "no_waste"),
    ]
    for household, status in visits:
        response = client.post("/api/v1/swachh/collections", json={
            "household_code": household,
            "ward": ward,
            "status": status,
        })
        assert response.status_code == 201, response.text
        assert response.json()["household_code"] == household.upper()

    listed = client.get("/api/v1/swachh/collections", params={"ward": ward}).json()
    assert len(listed) == len(visits)

    stats = client.get("/api/v1/swachh/segregation-stats", params={"days": 1}).json()
    ward_stats = next(item for item in stats["wards"] if item["ward"] == ward)
    assert ward_stats["visits"] == 5
    assert ward_stats["households"] == 4
    # 1 segregated out of 4 households that handed over waste (no_waste excluded)
    assert ward_stats["segregation_rate"] == 25.0
    offender = next(item for item in stats["repeat_offenders"] if item["ward"] == ward)
    assert offender["household_code"] == "H-002"
    assert offender["mixed_count"] == 2


def test_collection_log_rejects_blank_household():
    _created_wards.append("Ward 1")
    response = client.post("/api/v1/swachh/collections", json={
        "household_code": "   ",
        "ward": "Ward 1",
        "status": "segregated",
    })
    assert response.status_code == 400


def test_citizen_impact_points():
    phone = f"+9197{int(time.time() * 1000) % 10000000:07d}"
    client.post("/api/v1/auth/request-otp", json={"phone": phone})
    user = client.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": "123456"}).json()

    impact = client.get(f"/api/v1/swachh/citizens/{user['id']}/impact").json()
    assert impact["points"] == 0
    assert impact["level"] == "Swachh Starter"

    lat, lng = _unique_point()
    _create_report({
        "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "latitude": lat,
        "longitude": lng,
        "category": "garbage_overflow",
        "user_id": user["id"],
    })

    impact = client.get(f"/api/v1/swachh/citizens/{user['id']}/impact").json()
    assert impact["reports_filed"] == 1
    assert impact["swachh_reports"] == 1
    assert impact["points"] == 15
    assert impact["next_level"]["name"] == "Swachh Sathi"

    mine = client.get("/api/v1/reports/", params={"user_id": user["id"]}).json()
    assert len(mine) == 1


def test_report_with_unknown_user_id_still_created():
    lat, lng = _unique_point()
    response = _create_report({
        "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "latitude": lat,
        "longitude": lng,
        "category": "missed_pickup",
        "user_id": 987654321,
    })
    assert response.status_code == 201
    assert response.json()["user_id"] is None


def test_sanitation_summary():
    response = client.get("/api/v1/swachh/summary", params={"days": 30})
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= data["open"]
    assert {item["category"] for item in data["by_category"]} >= {"garbage_overflow", "public_toilet"}


def test_classify_item_without_model_configured(monkeypatch):
    monkeypatch.delenv("ROBOFLOW_WASTE_ITEM_MODEL_ID", raising=False)
    response = client.post(
        "/api/v1/swachh/classify-item",
        files={"file": ("item.jpg", b"not-really-an-image", "image/jpeg")},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["detected"] is False
    assert data["stream"] is None

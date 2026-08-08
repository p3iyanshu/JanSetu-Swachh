import io
import time

from fastapi.testclient import TestClient
from app.main import app
from app.database import SessionLocal
from app.models import NotificationEvent

client = TestClient(app)


def test_worker_assign_start_resolve_flow_with_notifications():
    unique_offset = (time.time() % 100) * 0.001
    test_lat = 12.8000 + unique_offset
    test_lng = 77.4000 + unique_offset

    departments = client.get("/api/v1/departments/").json()
    pwd_department = next(d for d in departments if "PWD" in d["name"] or "Public Works" in d["name"])

    emp_id = f"TESTWORKER{int(time.time() * 1000)}"
    signup_payload = {
        "name": "Test Field Worker",
        "emp_id": emp_id,
        "department_id": pwd_department["id"],
        "password": "worker_pw_123",
        "contact": "+91-9000000000",
    }
    signup_response = client.post("/api/v1/admin/signup", json=signup_payload)
    assert signup_response.status_code == 201
    officer = signup_response.json()
    officer_id = officer["id"]

    login_response = client.post(
        "/api/v1/admin/login",
        json={"emp_id": emp_id, "password": "worker_pw_123"},
    )
    assert login_response.status_code == 200

    assigned_before = client.get(f"/api/v1/admin/reports/assigned-to/{officer_id}").json()
    assert assigned_before == []

    citizen_phone = f"+9198{int(time.time() * 1000) % 10000000:07d}"
    otp_request = client.post("/api/v1/auth/request-otp", json={"phone": citizen_phone})
    demo_otp = otp_request.json()["demo_otp"]
    verify_response = client.post(
        "/api/v1/auth/verify-otp", json={"phone": citizen_phone, "otp": demo_otp}
    )
    assert verify_response.status_code == 200
    citizen_user_id = verify_response.json()["id"]

    token_response = client.post(
        "/api/v1/auth/register-device-token",
        json={"phone": citizen_phone, "fcm_token": "test-fcm-token-abc"},
    )
    assert token_response.status_code == 200
    assert token_response.json()["status"] == "ok"

    report_payload = {
        "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "latitude": test_lat,
        "longitude": test_lng,
        "category": "pothole",
        "description": "Worker flow test pothole.",
        "user_id": citizen_user_id,
    }
    report_response = client.post("/api/v1/reports/", json=report_payload)
    assert report_response.status_code == 201
    report_id = report_response.json()["id"]

    assign_response = client.post(
        f"/api/v1/admin/reports/{report_id}/assign",
        json={"officer_id": officer_id, "estimated_hours": 12},
    )
    assert assign_response.status_code == 200
    assigned_data = assign_response.json()
    assert assigned_data["status"] == "assigned"
    assert assigned_data["assigned_officer_id"] == officer_id

    assigned_after = client.get(f"/api/v1/admin/reports/assigned-to/{officer_id}").json()
    assert any(r["id"] == report_id for r in assigned_after)

    department_scoped = client.get(f"/api/v1/admin/reports/department/{pwd_department['id']}").json()
    assert any(r["id"] == report_id for r in department_scoped)

    other_department = next(d for d in departments if d["id"] != pwd_department["id"])
    other_scoped = client.get(f"/api/v1/admin/reports/department/{other_department['id']}").json()
    assert all(r["id"] != report_id for r in other_scoped)

    start_response = client.post(
        f"/api/v1/admin/reports/{report_id}/start",
        json={"officer_id": officer_id},
    )
    assert start_response.status_code == 200
    assert start_response.json()["status"] == "in_progress"

    resolve_response = client.post(
        f"/api/v1/admin/reports/{report_id}/resolve",
        data={"officer_id": officer_id, "latitude": test_lat, "longitude": test_lng},
        files={"after_photo": ("proof.jpg", io.BytesIO(b"fake-image-bytes"), "image/jpeg")},
    )
    assert resolve_response.status_code == 200
    resolved_data = resolve_response.json()
    # Worker submitting proof goes to admin review first, not straight to resolved.
    assert resolved_data["status"] == "pending_approval"
    assert resolved_data["resolved_at"] is not None

    officers = client.get(f"/api/v1/admin/officers?department_id={pwd_department['id']}").json()
    resolved_officer = next(o for o in officers if o["id"] == officer_id)
    assert resolved_officer["is_available"] is True

    # "Ticket Resolved" notification should NOT have fired yet - only after admin approval.
    db = SessionLocal()
    try:
        events_before_approval = (
            db.query(NotificationEvent)
            .filter(NotificationEvent.report_id == report_id)
            .order_by(NotificationEvent.id.asc())
            .all()
        )
        assert len(events_before_approval) == 2
        assert [e.title for e in events_before_approval] == ["Worker Assigned", "Work Started"]
    finally:
        db.close()

    approve_response = client.post(
        f"/api/v1/admin/reports/{report_id}/approve",
        json={"comment": "Looks good"},
    )
    assert approve_response.status_code == 200
    assert approve_response.json()["status"] == "resolved"

    db = SessionLocal()
    try:
        events = (
            db.query(NotificationEvent)
            .filter(NotificationEvent.report_id == report_id)
            .order_by(NotificationEvent.id.asc())
            .all()
        )
        assert len(events) == 3
        titles = [e.title for e in events]
        assert titles == ["Worker Assigned", "Work Started", "Ticket Resolved"]
        for event in events:
            assert event.status.value in ("sent", "skipped", "failed")
    finally:
        db.close()

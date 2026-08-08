import time

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def _create_report(offset):
    jitter = (time.time() % 100) * 0.001
    payload = {
        "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "latitude": 12.7 + offset + jitter,
        "longitude": 77.5 + offset + jitter,
        "category": "pothole",
        "description": "Admin review flow test",
    }
    response = client.post("/api/v1/reports/", json=payload)
    assert response.status_code == 201
    return response.json()["id"]


def _setup_worker_and_report(name_suffix, offset):
    departments = client.get("/api/v1/departments/").json()
    pwd = next(d for d in departments if "PWD" in d["name"])
    suffix = int(time.time() * 1000)
    worker = client.post(
        "/api/v1/admin/signup",
        json={
            "name": f"Review Worker {name_suffix}",
            "emp_id": f"TESTREVIEW{name_suffix}{suffix}",
            "department_id": pwd["id"],
            "password": "pw123",
        },
    ).json()
    report_id = _create_report(offset)
    client.post(f"/api/v1/admin/reports/{report_id}/assign", json={"officer_id": worker["id"], "estimated_hours": 24})
    client.post(f"/api/v1/admin/reports/{report_id}/start", json={"officer_id": worker["id"]})
    client.post(
        f"/api/v1/admin/reports/{report_id}/resolve",
        data={"officer_id": worker["id"], "latitude": 12.71, "longitude": 77.51},
        files={"after_photo": ("proof.jpg", b"fake-bytes", "image/jpeg")},
    )
    return worker, report_id, pwd


def test_only_pending_approval_can_be_approved_or_rejected():
    report_id = _create_report(0.5)  # still 'assigned', not pending_approval
    approve = client.post(f"/api/v1/admin/reports/{report_id}/approve", json={})
    assert approve.status_code == 400
    reject = client.post(f"/api/v1/admin/reports/{report_id}/reject", json={})
    assert reject.status_code == 400


def test_reject_sends_back_to_in_progress_and_recounts_capacity():
    worker, report_id, pwd = _setup_worker_and_report("A", 0.61)

    officers_after_submit = client.get(f"/api/v1/admin/officers?department_id={pwd['id']}").json()
    worker_after_submit = next(o for o in officers_after_submit if o["id"] == worker["id"])
    assert worker_after_submit["is_available"] is True  # free once submitted, awaiting review

    reject = client.post(
        f"/api/v1/admin/reports/{report_id}/reject",
        json={"comment": "Photo doesn't clearly show the fix"},
    )
    assert reject.status_code == 200
    data = reject.json()
    assert data["status"] == "in_progress"
    assert data["admin_review_comment"] == "Photo doesn't clearly show the fix"

    # Rejected ticket is active again against the worker's capacity.
    officers_after_reject = client.get(f"/api/v1/admin/officers?department_id={pwd['id']}").json()
    worker_after_reject = next(o for o in officers_after_reject if o["id"] == worker["id"])
    assert worker_after_reject["is_available"] is True  # still under cap (1 active)

    # Citizen cannot give feedback on a rejected (not-yet-resolved) ticket.
    feedback = client.post(f"/api/v1/reports/{report_id}/feedback", json={"satisfied": True})
    assert feedback.status_code == 400


def test_full_three_stage_close_flow():
    worker, report_id, pwd = _setup_worker_and_report("B", 0.72)

    report = client.get(f"/api/v1/reports/{report_id}").json()
    assert report["status"] == "pending_approval"
    assert report["citizen_verified"] is False

    approve = client.post(f"/api/v1/admin/reports/{report_id}/approve", json={"comment": "Verified onsite"})
    assert approve.status_code == 200
    approved = approve.json()
    assert approved["status"] == "resolved"
    assert approved["admin_review_comment"] == "Verified onsite"

    feedback = client.post(f"/api/v1/reports/{report_id}/feedback", json={"satisfied": True})
    assert feedback.status_code == 200
    final = feedback.json()
    assert final["status"] == "resolved"
    assert final["citizen_verified"] is True

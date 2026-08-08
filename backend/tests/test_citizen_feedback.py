import time

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def _create_report(offset):
    jitter = (time.time() % 100) * 0.001
    payload = {
        "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "latitude": 12.6 + offset + jitter,
        "longitude": 77.4 + offset + jitter,
        "category": "pothole",
        "description": "Feedback flow test",
    }
    response = client.post("/api/v1/reports/", json=payload)
    assert response.status_code == 201
    return response.json()["id"]


def test_feedback_requires_resolved_status():
    report_id = _create_report(0.11)
    response = client.post(
        f"/api/v1/reports/{report_id}/feedback",
        json={"satisfied": True, "comment": "n/a"},
    )
    assert response.status_code == 400


def test_satisfied_feedback_marks_verified():
    departments = client.get("/api/v1/departments/").json()
    pwd = next(d for d in departments if "PWD" in d["name"])
    suffix = int(time.time() * 1000)
    worker = client.post(
        "/api/v1/admin/signup",
        json={"name": "Feedback Worker", "emp_id": f"TESTFB{suffix}", "department_id": pwd["id"], "password": "pw123"},
    ).json()

    report_id = _create_report(0.22)
    client.post(f"/api/v1/admin/reports/{report_id}/assign", json={"officer_id": worker["id"], "estimated_hours": 24})
    client.post(f"/api/v1/admin/reports/{report_id}/start", json={"officer_id": worker["id"]})
    resolve = client.post(
        f"/api/v1/admin/reports/{report_id}/resolve",
        data={"officer_id": worker["id"], "latitude": 12.61, "longitude": 77.41},
        files={"after_photo": ("proof.jpg", b"fake-bytes", "image/jpeg")},
    )
    assert resolve.status_code == 200
    assert resolve.json()["status"] == "pending_approval"

    approve = client.post(f"/api/v1/admin/reports/{report_id}/approve", json={})
    assert approve.status_code == 200
    assert approve.json()["status"] == "resolved"

    feedback = client.post(
        f"/api/v1/reports/{report_id}/feedback",
        json={"satisfied": True, "comment": "Great work"},
    )
    assert feedback.status_code == 200
    data = feedback.json()
    assert data["status"] == "resolved"
    assert data["citizen_verified"] is True
    assert data["citizen_feedback_comment"] == "Great work"


def test_unsatisfied_feedback_reopens_and_frees_capacity():
    departments = client.get("/api/v1/departments/").json()
    pwd = next(d for d in departments if "PWD" in d["name"])
    suffix = int(time.time() * 1000)
    worker = client.post(
        "/api/v1/admin/signup",
        json={"name": "Feedback Worker 2", "emp_id": f"TESTFB2{suffix}", "department_id": pwd["id"], "password": "pw123"},
    ).json()

    report_id = _create_report(0.33)
    client.post(f"/api/v1/admin/reports/{report_id}/assign", json={"officer_id": worker["id"], "estimated_hours": 24})
    client.post(f"/api/v1/admin/reports/{report_id}/start", json={"officer_id": worker["id"]})
    client.post(
        f"/api/v1/admin/reports/{report_id}/resolve",
        data={"officer_id": worker["id"], "latitude": 12.62, "longitude": 77.42},
        files={"after_photo": ("proof.jpg", b"fake-bytes", "image/jpeg")},
    )
    client.post(f"/api/v1/admin/reports/{report_id}/approve", json={})

    officers_before = client.get(f"/api/v1/admin/officers?department_id={pwd['id']}").json()
    worker_before = next(o for o in officers_before if o["id"] == worker["id"])
    assert worker_before["is_available"] is True

    feedback = client.post(
        f"/api/v1/reports/{report_id}/feedback",
        json={"satisfied": False, "comment": "Pothole still there"},
    )
    assert feedback.status_code == 200
    data = feedback.json()
    assert data["status"] == "reopened"
    assert data["citizen_verified"] is False
    assert data["citizen_feedback_comment"] == "Pothole still there"

    # Reopened counts as an active ticket again, so availability is refreshed.
    officers_after = client.get(f"/api/v1/admin/officers?department_id={pwd['id']}").json()
    worker_after = next(o for o in officers_after if o["id"] == worker["id"])
    assert worker_after["is_available"] is True  # still under capacity (1 active ticket)

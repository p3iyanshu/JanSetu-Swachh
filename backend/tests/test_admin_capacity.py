import time

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def _create_pothole_report(offset):
    lat = 12.7000 + offset
    lng = 77.3000 + offset
    payload = {
        "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "latitude": lat,
        "longitude": lng,
        "category": "pothole",
        "description": f"Capacity test pothole {offset}",
    }
    response = client.post("/api/v1/reports/", json=payload)
    assert response.status_code == 201
    return response.json()["id"]


def test_worker_capacity_limit_enforced_and_eligible_workers_filtered():
    departments = client.get("/api/v1/departments/").json()
    pwd_department = next(d for d in departments if "PWD" in d["name"] or "Public Works" in d["name"])
    other_department = next(d for d in departments if d["id"] != pwd_department["id"])

    suffix = int(time.time() * 1000)

    pwd_worker_signup = client.post(
        "/api/v1/admin/signup",
        json={
            "name": "Capacity Worker",
            "emp_id": f"TESTCAP{suffix}",
            "department_id": pwd_department["id"],
            "password": "pw12345",
        },
    )
    assert pwd_worker_signup.status_code == 201
    pwd_worker_id = pwd_worker_signup.json()["id"]

    second_pwd_worker_signup = client.post(
        "/api/v1/admin/signup",
        json={
            "name": "Overflow Worker",
            "emp_id": f"TESTCAP2{suffix}",
            "department_id": pwd_department["id"],
            "password": "pw12345",
        },
    )
    assert second_pwd_worker_signup.status_code == 201
    second_pwd_worker_id = second_pwd_worker_signup.json()["id"]

    other_dept_worker_signup = client.post(
        "/api/v1/admin/signup",
        json={
            "name": "Wrong Department Worker",
            "emp_id": f"TESTCAP3{suffix}",
            "department_id": other_department["id"],
            "password": "pw12345",
        },
    )
    assert other_dept_worker_signup.status_code == 201
    other_dept_worker_id = other_dept_worker_signup.json()["id"]

    report_ids = [_create_pothole_report(offset * 0.01) for offset in range(1, 5)]

    # Wrong-department worker cannot be assigned to a PWD-routed ticket.
    mismatch_response = client.post(
        f"/api/v1/admin/reports/{report_ids[0]}/assign",
        json={"officer_id": other_dept_worker_id, "estimated_hours": 24},
    )
    assert mismatch_response.status_code == 400

    # First 3 assignments to the same PWD worker succeed.
    for i in range(3):
        eligible_before = client.get(f"/api/v1/admin/reports/{report_ids[i]}/eligible-workers").json()
        worker_entry = next(w for w in eligible_before["workers"] if w["id"] == pwd_worker_id)
        assert worker_entry["active_ticket_count"] == i

        assign_response = client.post(
            f"/api/v1/admin/reports/{report_ids[i]}/assign",
            json={"officer_id": pwd_worker_id, "estimated_hours": 24},
        )
        assert assign_response.status_code == 200
        assert assign_response.json()["status"] == "assigned"

    # Worker is now at 3/3 - eligible-workers must exclude them.
    eligible_after = client.get(f"/api/v1/admin/reports/{report_ids[3]}/eligible-workers").json()
    assert all(w["id"] != pwd_worker_id for w in eligible_after["workers"])
    assert any(w["id"] == second_pwd_worker_id for w in eligible_after["workers"])

    # 4th assignment attempt to the maxed-out worker is rejected by the backend.
    fourth_assign_response = client.post(
        f"/api/v1/admin/reports/{report_ids[3]}/assign",
        json={"officer_id": pwd_worker_id, "estimated_hours": 24},
    )
    assert fourth_assign_response.status_code == 400
    assert "active tickets" in fourth_assign_response.json()["detail"]

    # A different eligible PWD worker can still take the 4th ticket.
    fallback_assign_response = client.post(
        f"/api/v1/admin/reports/{report_ids[3]}/assign",
        json={"officer_id": second_pwd_worker_id, "estimated_hours": 24},
    )
    assert fallback_assign_response.status_code == 200
    assert fallback_assign_response.json()["assigned_officer_id"] == second_pwd_worker_id

    # Officer availability reflects capacity: maxed worker (3/3) is unavailable,
    # a worker under cap (1/3) is still available for more work.
    officers = client.get(f"/api/v1/admin/officers?department_id={pwd_department['id']}").json()
    maxed_officer = next(o for o in officers if o["id"] == pwd_worker_id)
    fresh_officer = next(o for o in officers if o["id"] == second_pwd_worker_id)
    assert maxed_officer["is_available"] is False
    assert fresh_officer["is_available"] is True

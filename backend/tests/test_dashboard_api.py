from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_dashboard_stats_endpoint():
    response = client.get("/api/v1/reports/stats")
    assert response.status_code == 200
    data = response.json()
    assert "open_count" in data
    assert "in_progress_count" in data
    assert "resolved_count" in data
    assert "avg_resolution_hours" in data

def test_report_status_update():
    # First fetch list of reports
    reports_res = client.get("/api/v1/reports/")
    reports = reports_res.json()
    assert len(reports) > 0
    report_id = reports[0]["id"]

    # Patch status to in_progress
    patch_payload = {
        "status": "in_progress",
        "assigned_department_id": 1
    }
    patch_res = client.patch(f"/api/v1/reports/{report_id}/status", json=patch_payload)
    assert patch_res.status_code == 200
    updated_data = patch_res.json()
    assert updated_data["status"] == "in_progress"
    assert updated_data["assigned_department_id"] == 1

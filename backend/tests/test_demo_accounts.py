from fastapi.testclient import TestClient

from app.main import app
from app.services.demo_accounts import DEMO_ADMIN_ID, DEMO_PASSWORD, DEMO_WORKER_ID

client = TestClient(app)


def test_demo_admin_login():
    response = client.post("/api/v1/admin/login", json={"emp_id": DEMO_ADMIN_ID, "password": DEMO_PASSWORD})
    assert response.status_code == 200
    assert response.json()["department_id"] is None


def test_demo_worker_login_is_in_sanitation():
    response = client.post("/api/v1/admin/login", json={"emp_id": DEMO_WORKER_ID, "password": DEMO_PASSWORD})
    assert response.status_code == 200
    department_id = response.json()["department_id"]
    departments = {item["id"]: item["name"] for item in client.get("/api/v1/departments/").json()}
    assert "waste" in departments[department_id].lower()

from fastapi.testclient import TestClient
from app.main import app
import time

client = TestClient(app)


def test_report_creation_end_to_end():
    unique_offset = (time.time() % 100) * 0.001
    test_lat = 12.9000 + unique_offset
    test_lng = 77.5000 + unique_offset

    payload = {
        "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "latitude": test_lat,
        "longitude": test_lng,
        "category": "pothole",
        "description": "Deep pothole created after heavy rainfall."
    }


    response = client.post("/api/v1/reports/", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["category"] == "pothole"
    assert data["status"] == "assigned"
    assert data["assigned_department_id"] is not None
    assert data["upvote_count"] == 1
    assert data["priority_score"] > 0
    assert data["sla_deadline"] is not None
    report_id = data["id"]

    # A second report for the same issue at (nearly) the same spot must still
    # become its own ticket with its own ID - no merging into report_id.
    second_payload = {
        "photo_url": "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7",
        "latitude": test_lat + 0.0001, # ~11 meters away
        "longitude": test_lng + 0.0001,
        "category": "pothole",
        "description": "Another citizen reporting the exact same pothole."
    }

    second_response = client.post("/api/v1/reports/", json=second_payload)
    assert second_response.status_code == 201
    second_data = second_response.json()
    assert second_data["id"] != report_id  # Distinct ticket, not merged
    assert second_data["upvote_count"] == 1  # Its own fresh count, not incremented

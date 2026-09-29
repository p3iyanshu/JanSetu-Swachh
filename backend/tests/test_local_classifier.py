import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.main import app
from app.ml import local_classifier
from app.ml.local_classifier import classify_civic_issue, civic_classifier

client = TestClient(app)

VALID_CATEGORIES = {"garbage_overflow", "pothole", "sewage_overflow", "water_leakage", "other"}

needs_model = pytest.mark.skipif(not civic_classifier.available, reason="trained civic model not installed")


def _image_bytes(color=(120, 120, 120)):
    buffer = io.BytesIO()
    Image.new("RGB", (320, 240), color).save(buffer, format="JPEG")
    return buffer.getvalue()


@needs_model
def test_local_model_returns_a_valid_category(tmp_path):
    path = tmp_path / "plain.jpg"
    path.write_bytes(_image_bytes())
    result = classify_civic_issue(str(path))
    assert result is not None
    assert result["category"] in VALID_CATEGORIES
    assert 0.0 <= result["confidence"] <= 1.0
    assert set(result["raw_result"]["scores"]) == {"garbage", "other", "pothole", "sewage", "water_leakage"}


@needs_model
def test_analyze_endpoint_uses_the_local_model():
    response = client.post(
        "/api/v1/ai/analyze-issue",
        files={"file": ("plain.jpg", _image_bytes(), "image/jpeg")},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["category"] in VALID_CATEGORIES
    if data["detected"]:
        assert "JanSetu-Swachh model" in data["message"]


def test_missing_model_falls_back(monkeypatch, tmp_path):
    empty = local_classifier.LocalClassifier("does_not_exist", "UNUSED_THRESHOLD", 0.5)
    monkeypatch.setattr(local_classifier, "civic_classifier", empty)
    assert classify_civic_issue(str(tmp_path / "x.jpg")) is None

from fastapi.testclient import TestClient
import io
from PIL import Image

from app.main import app

client = TestClient(app)

def test_ai_analyze_endpoint():
    # Generate mock image in memory
    img = Image.new('RGB', (100, 100), color='red')
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG')
    img_bytes = img_byte_arr.getvalue()

    files = {'file': ('test.jpg', img_bytes, 'image/jpeg')}
    data = {'transcript': 'Big hole in asphalt', 'latitude': '13.0827', 'longitude': '77.5877'}

    response = client.post("/api/v1/ai/analyze-issue", files=files, data=data)
    assert response.status_code == 200
    res = response.json()
    assert "category" in res
    assert "confidence" in res
    assert "severity_score" in res
    assert "description" in res
    assert len(res["clip_embedding_preview"]) == 5

from fastapi.testclient import TestClient
import io
from PIL import Image

from app.main import app
from app.ml.yolo_classifier import YOLOv8CivicClassifier
from app.ml.clip_embeddings import CLIPEmbeddingExtractor
from app.ml.llm_describer import MultimodalLLMDescriber

client = TestClient(app)

def test_yolo_classifier():
    classifier = YOLOv8CivicClassifier()
    result = classifier.classify_image("non_existent_file.jpg")
    assert "category" in result
    assert "confidence" in result
    assert result["category"] in ["pothole", "garbage_overflow", "water_leakage", "broken_streetlight"]

def test_clip_embeddings():
    extractor = CLIPEmbeddingExtractor()
    vec1 = extractor.extract_image_embedding("test1.jpg")
    vec2 = extractor.extract_image_embedding("test2.jpg")
    assert len(vec1) == 512
    sim = extractor.cosine_similarity(vec1, vec2)
    assert 0.0 <= sim <= 1.0

def test_llm_describer():
    describer = MultimodalLLMDescriber()
    result = describer.generate_issue_description("pothole", user_transcript="Deep crater on main road", latitude=13.0827, longitude=77.5877)
    assert result["category"] == "pothole"
    assert result["severity_score"] >= 1
    assert "pothole" in result["description"].lower()

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

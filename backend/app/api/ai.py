from fastapi import APIRouter, UploadFile, File, Form
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool
from typing import Optional
import os
import uuid

from app.ml.roboflow_civic_classifier import RoboflowCivicClassifier

router = APIRouter(prefix="/ai", tags=["AI Pipeline"])

roboflow_civic_service = RoboflowCivicClassifier()

class ImageAnalysisResponse(BaseModel):
    category: str
    confidence: float
    severity_score: int
    description: str
    clip_embedding_preview: list
    detected: bool = False
    message: str = ""
    label: str = "Other"

@router.post("/analyze-issue", response_model=ImageAnalysisResponse)
async def analyze_issue(
    file: UploadFile = File(...),
    transcript: Optional[str] = Form(""),
    latitude: Optional[float] = Form(13.0827),
    longitude: Optional[float] = Form(77.5877)
):
    filename = f"{uuid.uuid4()}_{file.filename}"
    temp_dir = "temp_uploads"
    os.makedirs(temp_dir, exist_ok=True)
    temp_path = os.path.join(temp_dir, filename)

    try:
        content = await file.read()
        with open(temp_path, "wb") as f:
            f.write(content)

        roboflow_result = await run_in_threadpool(roboflow_civic_service.classify_image, temp_path)
        category = roboflow_result["category"]
        label = roboflow_result.get("label", "Other")
        severity_score = 4 if category != "other" else 1
        description = f"{label} detected from the uploaded image." if category != "other" else "No confident civic issue detection from the uploaded image."
        if transcript:
            description = f"{description} Citizen detail: '{transcript.strip()}'."

        return ImageAnalysisResponse(
            category=category,
            confidence=roboflow_result["confidence"],
            severity_score=severity_score,
            description=description,
            clip_embedding_preview=[
                roboflow_result["confidence"],
                severity_score / 5,
                latitude / 100,
                longitude / 100,
                1.0 if roboflow_result["detected"] else 0.0,
            ],
            detected=roboflow_result["detected"],
            message=roboflow_result["message"],
            label=label,
        )
    finally:
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                pass

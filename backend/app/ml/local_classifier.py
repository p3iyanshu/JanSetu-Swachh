"""Locally-run image classifiers trained for JanSetu-Swachh (see ml/).

The weights live in app/ml/weights/ (civic_cls.pt, waste_cls.pt). They run
on the backend's CPU in a few tens of milliseconds, so issue detection works
offline and doesn't depend on hosted-model credits.
"""

import os
import threading
from pathlib import Path
from typing import Any, Optional

WEIGHTS_DIR = Path(__file__).resolve().parent / "weights"

# Trained class name -> backend CategoryType value.
CIVIC_CLASS_TO_CATEGORY = {
    "garbage": ("garbage_overflow", "Garbage"),
    "pothole": ("pothole", "Pothole"),
    "sewage": ("sewage_overflow", "Sewage"),
    "water_leakage": ("water_leakage", "Water Leak"),
}


class LocalClassifier:
    def __init__(self, weights_name: str, env_threshold: str, default_threshold: float) -> None:
        self.path = WEIGHTS_DIR / weights_name
        self.threshold = float(os.getenv(env_threshold, str(default_threshold)))
        self._model: Optional[Any] = None
        self._lock = threading.Lock()
        self._failed = False

    @property
    def available(self) -> bool:
        return self.path.exists() and not self._failed

    def _load(self):
        if self._model is None:
            with self._lock:
                if self._model is None:
                    from ultralytics import YOLO

                    self._model = YOLO(str(self.path), task="classify")
        return self._model

    def predict(self, image_path: str) -> Optional[tuple[str, float, dict[str, float]]]:
        """Returns (top class, confidence, all class scores) or None on failure."""
        try:
            model = self._load()
            result = model.predict(image_path, verbose=False, device="cpu")[0]
        except Exception:
            self._failed = True
            return None
        probs = result.probs.data.tolist()
        scores = {result.names[i]: float(p) for i, p in enumerate(probs)}
        top = result.probs.top1
        return result.names[top], float(result.probs.top1conf), scores


civic_classifier = LocalClassifier("civic_cls.pt", "JANSETU_CIVIC_THRESHOLD", 0.55)
waste_classifier = LocalClassifier("waste_cls.pt", "JANSETU_WASTE_THRESHOLD", 0.5)


def classify_civic_issue(image_path: str) -> Optional[dict[str, Any]]:
    """Same result shape as RoboflowCivicClassifier.classify_image, or None
    when no local model is installed."""
    if not civic_classifier.available:
        return None
    prediction = civic_classifier.predict(image_path)
    if prediction is None:
        return None
    name, confidence, scores = prediction
    mapped = CIVIC_CLASS_TO_CATEGORY.get(name)
    detected = mapped is not None and confidence >= civic_classifier.threshold
    if detected:
        category, label = mapped
        message = f"{label} detected by the JanSetu-Swachh model."
    else:
        category, label = "other", "Other"
        message = "No confident civic issue detection."
    return {
        "category": category,
        "label": label,
        "confidence": round(confidence, 3),
        "detected": detected,
        "message": message,
        "raw_result": {"model": "local", "scores": {k: round(v, 3) for k, v in scores.items()}},
    }

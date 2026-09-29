"""Locally-run image classifiers trained for JanSetu-Swachh (see ml/).

Weights live in app/ml/weights/:
  civic_cls*.onnx / waste_cls*.onnx + matching .json class names
                                     -> onnxruntime (light, fits Render's free tier)
  civic_cls.pt    / waste_cls.pt     -> ultralytics (dev fallback)
ONNX is preferred when onnxruntime is installed. When several ONNX models
share a stem (civic_cls.onnx, civic_cls_v1.onnx) their probabilities are
averaged - the two civic models make different mistakes, and the average
had zero false alarms on the held-out "no issue" photos. Either way issue detection
runs on the backend itself - offline and without hosted-model credits.
"""

import json
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


class _OnnxBackend:
    def __init__(self, model_path: Path, meta_path: Path) -> None:
        import numpy as np
        import onnxruntime as ort

        self._np = np
        meta = json.loads(meta_path.read_text())
        self.names = meta["names"]
        self.imgsz = int(meta["imgsz"])
        self.session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name

    def predict(self, image_path: str) -> list[float]:
        from PIL import Image

        np = self._np
        # Same preprocessing as Ultralytics' classify transforms: resize the
        # short side to imgsz, centre-crop, scale to 0..1, CHW.
        image = Image.open(image_path).convert("RGB")
        width, height = image.size
        scale = self.imgsz / min(width, height)
        image = image.resize((max(self.imgsz, round(width * scale)), max(self.imgsz, round(height * scale))), Image.BILINEAR)
        left = (image.width - self.imgsz) // 2
        top = (image.height - self.imgsz) // 2
        image = image.crop((left, top, left + self.imgsz, top + self.imgsz))
        array = np.asarray(image, dtype=np.float32).transpose(2, 0, 1)[None] / 255.0
        output = self.session.run(None, {self.input_name: array})[0][0]
        total = float(output.sum())
        if not 0.99 < total < 1.01:  # exported without softmax -> apply it
            exp = np.exp(output - output.max())
            output = exp / exp.sum()
        return [float(value) for value in output]


class _UltralyticsBackend:
    def __init__(self, model_path: Path) -> None:
        from ultralytics import YOLO

        self.model = YOLO(str(model_path), task="classify")
        self.names = [self.model.names[i] for i in range(len(self.model.names))]

    def predict(self, image_path: str) -> list[float]:
        result = self.model.predict(image_path, verbose=False, device="cpu")[0]
        return [float(p) for p in result.probs.data.tolist()]


class _Ensemble:
    """Averages the class probabilities of models trained on the same classes."""

    def __init__(self, members) -> None:
        names = members[0].names
        if any(member.names != names for member in members):
            raise ValueError("Ensemble members must share the same class names")
        self.names = names
        self.members = members

    def predict(self, image_path: str) -> list[float]:
        outputs = [member.predict(image_path) for member in self.members]
        return [sum(values) / len(values) for values in zip(*outputs)]


class LocalClassifier:
    def __init__(self, stem: str, env_threshold: str, default_threshold: float) -> None:
        self.stem = stem
        self.pt_path = WEIGHTS_DIR / f"{stem}.pt"
        self.threshold = float(os.getenv(env_threshold, str(default_threshold)))
        self._backend: Optional[Any] = None
        self._lock = threading.Lock()
        self._failed = False

    def _onnx_models(self) -> list[tuple[Path, Path]]:
        pairs = []
        for model_path in sorted(WEIGHTS_DIR.glob(f"{self.stem}*.onnx")):
            meta_path = model_path.with_suffix(".json")
            if meta_path.exists():
                pairs.append((model_path, meta_path))
        return pairs

    @property
    def available(self) -> bool:
        has_weights = bool(self._onnx_models()) or self.pt_path.exists()
        return has_weights and not self._failed

    def _load(self):
        if self._backend is None:
            with self._lock:
                if self._backend is None:
                    backend = None
                    pairs = self._onnx_models()
                    if pairs:
                        try:
                            members = [_OnnxBackend(model, meta) for model, meta in pairs]
                            backend = members[0] if len(members) == 1 else _Ensemble(members)
                        except ImportError:
                            backend = None
                    if backend is None and self.pt_path.exists():
                        backend = _UltralyticsBackend(self.pt_path)
                    if backend is None:
                        raise RuntimeError("No usable model backend")
                    self._backend = backend
        return self._backend

    def predict(self, image_path: str) -> Optional[tuple[str, float, dict[str, float]]]:
        """Returns (top class, confidence, all class scores) or None on failure."""
        try:
            backend = self._load()
            probs = backend.predict(image_path)
        except Exception:
            self._failed = True
            return None
        scores = {backend.names[i]: p for i, p in enumerate(probs)}
        top = max(range(len(probs)), key=lambda i: probs[i])
        return backend.names[top], probs[top], scores


civic_classifier = LocalClassifier("civic_cls", "JANSETU_CIVIC_THRESHOLD", 0.55)
waste_classifier = LocalClassifier("waste_cls", "JANSETU_WASTE_THRESHOLD", 0.5)


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

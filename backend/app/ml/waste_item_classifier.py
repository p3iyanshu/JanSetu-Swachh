import os
from typing import Any, Optional

from dotenv import load_dotenv

from app.services.waste_guide import stream_for_label

load_dotenv()


class WasteItemClassifier:
    """Optional "Which bin?" photo classifier.

    Runs a Roboflow classification/detection model (for example a public
    waste-sorting model from Roboflow Universe) on a photo of a single waste
    item and maps the predicted class name to one of the four SWM Rules 2026
    streams. Configure with ROBOFLOW_WASTE_ITEM_MODEL_ID (+ ROBOFLOW_API_KEY or
    ROBOFLOW_WASTE_ITEM_API_KEY). When it isn't configured the endpoint says
    so and the app falls back to the searchable offline guide.
    """

    def __init__(self) -> None:
        self.api_url = os.getenv("ROBOFLOW_API_URL", "https://serverless.roboflow.com")
        self.confidence_threshold = float(os.getenv("ROBOFLOW_CONFIDENCE_THRESHOLD", "0.35"))
        self._client: Optional[Any] = None

    @property
    def model_id(self) -> str:
        return os.getenv("ROBOFLOW_WASTE_ITEM_MODEL_ID", "").strip()

    @property
    def api_key(self) -> str:
        return os.getenv("ROBOFLOW_WASTE_ITEM_API_KEY", "").strip() or os.getenv("ROBOFLOW_API_KEY", "").strip()

    def classify(self, image_path: str) -> dict[str, Any]:
        if not self.model_id or not self.api_key:
            return self._result(message="AI item scan is not configured on the server. Search the guide instead.")

        try:
            if self._client is None:
                from inference_sdk import InferenceHTTPClient

                self._client = InferenceHTTPClient(api_url=self.api_url, api_key=self.api_key)
            raw = self._client.infer(image_path, model_id=self.model_id)
        except Exception:
            return self._result(message="AI item scan is unavailable right now. Search the guide instead.")

        label, confidence = self._top_prediction(raw)
        if not label or confidence < self.confidence_threshold:
            return self._result(
                label=label,
                confidence=confidence,
                message="Could not confidently identify the item. Search the guide instead.",
            )

        stream = stream_for_label(label)
        if stream is None:
            return self._result(
                label=label,
                confidence=confidence,
                message=f"Detected '{label}', but it doesn't map to a waste stream. Search the guide instead.",
            )

        return self._result(
            label=label,
            confidence=confidence,
            stream=stream,
            detected=True,
            message=f"Looks like {label}.",
        )

    def _top_prediction(self, value: Any) -> tuple[Optional[str], float]:
        """Find the highest-confidence (class, confidence) pair anywhere in a
        Roboflow response - works for both classification ("top"/"predictions")
        and detection ("predictions": [{"class": ..., "confidence": ...}]) shapes."""
        best: tuple[Optional[str], float] = (None, 0.0)

        def walk(node: Any) -> None:
            nonlocal best
            if isinstance(node, dict):
                label = node.get("class") or node.get("top")
                confidence = node.get("confidence")
                if isinstance(label, str) and isinstance(confidence, (int, float)) and confidence > best[1]:
                    best = (label, float(confidence))
                predictions = node.get("predictions")
                # Multi-class classification returns {"predictions": {"plastic": {"confidence": 0.9}}}
                if isinstance(predictions, dict):
                    for class_name, details in predictions.items():
                        if isinstance(details, dict):
                            score = details.get("confidence")
                            if isinstance(score, (int, float)) and score > best[1]:
                                best = (class_name, float(score))
                for child in node.values():
                    walk(child)
            elif isinstance(node, list):
                for child in node:
                    walk(child)

        walk(value)
        return best

    @staticmethod
    def _result(
        label: Optional[str] = None,
        confidence: float = 0.0,
        stream: Optional[str] = None,
        detected: bool = False,
        message: str = "",
    ) -> dict[str, Any]:
        return {
            "detected": detected,
            "label": label,
            "confidence": round(confidence, 3),
            "stream": stream,
            "message": message,
        }

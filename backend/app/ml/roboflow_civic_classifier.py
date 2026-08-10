import os
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from typing import Any, Optional

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class RoboflowWorkflow:
    category: str
    label: str
    env_key: str
    # Optional overrides for workflows hosted on a different Roboflow
    # account/workspace than the shared default (e.g. garbage detection).
    api_key_env: Optional[str] = None
    workspace_env: Optional[str] = None
    # "workflow" calls client.run_workflow(...); "model" calls client.infer(...)
    # directly against a trained model_id (no workspace needed).
    kind: str = "workflow"


class RoboflowCivicClassifier:
    # The citizen-facing category picker only offers these four (see
    # mobile/lib/core/constants/app_constants.dart) - streetlight and road
    # damage were deliberately dropped from it, but their Roboflow workflows
    # were still running here and could win the overall confidence race,
    # leaving the app unable to auto-select anything and showing "AI could
    # not confidently detect" even when the AI *did* detect something (just
    # not a choosable category). Restricting the competition to these four
    # keeps this endpoint's only consumer (the citizen quick-report
    # AI-suggest flow) from ever "winning" on an undisplayable category.
    _CITIZEN_FACING_CATEGORIES = {"pothole", "garbage_overflow", "water_leakage", "sewage_overflow"}

    _workflows = [
        RoboflowWorkflow("pothole", "Pothole", "ROBOFLOW_POTHOLE_WORKFLOW_ID"),
        RoboflowWorkflow("damaged_public_property", "Road Damage", "ROBOFLOW_ROAD_DAMAGE_WORKFLOW_ID"),
        RoboflowWorkflow(
            "garbage_overflow",
            "Garbage",
            "ROBOFLOW_GARBAGE_WORKFLOW_ID",
            api_key_env="ROBOFLOW_GARBAGE_API_KEY",
            workspace_env="ROBOFLOW_GARBAGE_WORKSPACE_NAME",
        ),
        RoboflowWorkflow("water_leakage", "Water Leak", "ROBOFLOW_WATER_LEAK_WORKFLOW_ID"),
        RoboflowWorkflow("sewage_overflow", "Sewage", "ROBOFLOW_SEWAGE_WORKFLOW_ID"),
        RoboflowWorkflow("broken_streetlight", "Street Light", "ROBOFLOW_STREET_LIGHT_WORKFLOW_ID"),
        RoboflowWorkflow(
            "sewage_overflow",
            "Sewage (Classifier)",
            "ROBOFLOW_SEWAGE_CLASSIFY_MODEL_ID",
            api_key_env="ROBOFLOW_SECONDARY_API_KEY",
            kind="model",
        ),
        RoboflowWorkflow(
            "broken_streetlight",
            "Street Light (Detector)",
            "ROBOFLOW_STREET_LIGHT_DETECT_MODEL_ID",
            api_key_env="ROBOFLOW_SECONDARY_API_KEY",
            kind="model",
        ),
        RoboflowWorkflow(
            "sewage_overflow",
            "Sewage Leak",
            "ROBOFLOW_SEWAGE_LEAK_WORKFLOW_ID",
            api_key_env="ROBOFLOW_SECONDARY_API_KEY",
            workspace_env="ROBOFLOW_SECONDARY_WORKSPACE_NAME",
        ),
        RoboflowWorkflow(
            "broken_streetlight",
            "Street Light (Workflow 2)",
            "ROBOFLOW_STREET_LIGHT_SECONDARY_WORKFLOW_ID",
            api_key_env="ROBOFLOW_SECONDARY_API_KEY",
            workspace_env="ROBOFLOW_SECONDARY_WORKSPACE_NAME",
        ),
    ]

    def __init__(self) -> None:
        self.api_url = os.getenv("ROBOFLOW_API_URL", "https://serverless.roboflow.com")
        self.api_key = os.getenv("ROBOFLOW_API_KEY", "")
        self.workspace_name = os.getenv("ROBOFLOW_WORKSPACE_NAME", "")
        self.confidence_threshold = float(os.getenv("ROBOFLOW_CONFIDENCE_THRESHOLD", "0.35"))
        self._clients: dict[tuple[str, str], Any] = {}
        self._client_cls: Optional[Any] = None

    def classify_image(self, image_path: str) -> dict[str, Any]:
        if not self.api_key or not self.workspace_name:
            return self._not_configured()

        configured_workflows = [
            workflow
            for workflow in self._workflows
            if os.getenv(workflow.env_key, "").strip()
            and workflow.category in self._CITIZEN_FACING_CATEGORIES
        ]
        if not configured_workflows:
            return self._not_configured()

        try:
            from inference_sdk import InferenceHTTPClient

            self._client_cls = InferenceHTTPClient
        except Exception:
            return {
                "category": "other",
                "label": "Other",
                "confidence": 0.0,
                "detected": False,
                "message": "Roboflow inference SDK is not installed on the backend.",
                "raw_result": None,
            }

        # Each workflow is a separate network round-trip to Roboflow - run them
        # concurrently instead of one after another, so total wait time is
        # roughly the slowest single call instead of the sum of all of them.
        with ThreadPoolExecutor(max_workers=len(configured_workflows)) as executor:
            results = list(
                executor.map(lambda workflow: self._run_workflow(workflow, image_path), configured_workflows)
            )
        best = max(results, key=lambda item: item["confidence"])

        if best["confidence"] < self.confidence_threshold:
            return {
                "category": "other",
                "label": "Other",
                "confidence": round(best["confidence"], 3),
                "detected": False,
                "message": "No confident civic issue detection.",
                "raw_result": {"workflow_results": results},
            }

        return {
            "category": best["category"],
            "label": best["label"],
            "confidence": round(best["confidence"], 3),
            "detected": True,
            "message": f"{best['label']} detected by Roboflow.",
            "raw_result": {"workflow_results": results},
        }

    def _client_for(self, workflow: RoboflowWorkflow) -> Any:
        api_key = os.getenv(workflow.api_key_env, "") if workflow.api_key_env else ""
        api_key = api_key or self.api_key
        cache_key = (self.api_url, api_key)
        if cache_key not in self._clients:
            self._clients[cache_key] = self._client_cls(api_url=self.api_url, api_key=api_key)
        return self._clients[cache_key]

    def _workspace_for(self, workflow: RoboflowWorkflow) -> str:
        if workflow.workspace_env:
            workspace = os.getenv(workflow.workspace_env, "").strip()
            if workspace:
                return workspace
        return self.workspace_name

    def _run_workflow(
        self,
        workflow: RoboflowWorkflow,
        image_path: str,
    ) -> dict[str, Any]:
        try:
            client = self._client_for(workflow)
            if workflow.kind == "model":
                result = client.infer(image_path, model_id=os.getenv(workflow.env_key, ""))
            else:
                result = client.run_workflow(
                    workspace_name=self._workspace_for(workflow),
                    workflow_id=os.getenv(workflow.env_key, ""),
                    images={"image": image_path},
                    use_cache=True,
                )
            return {
                "category": workflow.category,
                "label": workflow.label,
                "confidence": self._extract_confidence(result),
                "error": None,
            }
        except Exception as exc:
            return {
                "category": workflow.category,
                "label": workflow.label,
                "confidence": 0.0,
                "error": str(exc),
            }

    def _extract_confidence(self, value: Any) -> float:
        scores: list[float] = []

        def walk(node: Any) -> None:
            if isinstance(node, dict):
                for key, child in node.items():
                    normalized = key.lower()
                    if normalized in {"confidence", "score"} and isinstance(
                        child, (int, float)
                    ):
                        scores.append(float(child))
                    else:
                        walk(child)
            elif isinstance(node, list):
                for child in node:
                    walk(child)

        walk(value)
        return max(scores) if scores else 0.0

    def _not_configured(self) -> dict[str, Any]:
        return {
            "category": "other",
            "label": "Other",
            "confidence": 0.0,
            "detected": False,
            "message": "Roboflow is not configured on the backend.",
            "raw_result": None,
        }

"""Runs the civic-issue classifier (local model if installed, else Roboflow) over a folder of images and
prints every model's confidence plus the final decision, so you can see
whether detection is working and which model is responsible for a result.

Usage (from backend/, venv active):
    python -m scripts.evaluate_classifier <folder> [--labels labels.csv]

labels.csv (optional) has lines "filename,expected_category" and turns the
output into an accuracy report.
"""

import argparse
import csv
import os
from concurrent.futures import ThreadPoolExecutor

from app.ml.local_classifier import classify_civic_issue
from app.ml.roboflow_civic_classifier import RoboflowCivicClassifier

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folder")
    parser.add_argument("--labels")
    parser.add_argument("--roboflow", action="store_true", help="Force the hosted Roboflow models instead of the local one")
    args = parser.parse_args()

    expected = {}
    if args.labels:
        with open(args.labels, newline="", encoding="utf-8") as handle:
            expected = {row[0]: row[1] for row in csv.reader(handle) if len(row) >= 2}

    files = sorted(
        name for name in os.listdir(args.folder)
        if os.path.splitext(name)[1].lower() in IMAGE_EXTENSIONS
    )
    classifier = RoboflowCivicClassifier()

    def run(name):
        path = os.path.join(args.folder, name)
        result = None if args.roboflow else classify_civic_issue(path)
        return name, result or classifier.classify_image(path)

    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(run, files))

    correct = total = 0
    for name, result in results:
        raw = result.get("raw_result") or {}
        workflows = raw.get("workflow_results", []) or [
            {"label": label, "confidence": score} for label, score in raw.get("scores", {}).items()
        ]
        scores = ", ".join(
            f"{item['label']}={item['confidence']:.2f}" + (" (ERROR)" if item.get("error") else "")
            for item in sorted(workflows, key=lambda item: -item["confidence"])
        )
        verdict = ""
        if name in expected:
            total += 1
            hit = result["category"] == expected[name]
            correct += hit
            verdict = f"  expected={expected[name]} {'OK' if hit else 'WRONG'}"
        print(f"{name}\n  -> {result['category']} ({result['confidence']:.2f}) {result['message']}{verdict}\n  scores: {scores}")
        errors = [item["error"] for item in workflows if item.get("error")]
        if errors:
            print(f"  first error: {errors[0][:200]}")

    if total:
        print(f"\nAccuracy: {correct}/{total} = {100 * correct / total:.0f}%")


if __name__ == "__main__":
    main()

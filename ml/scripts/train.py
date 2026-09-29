"""Train the JanSetu-Swachh image classifiers (YOLO11n-cls, fine-tuned).

  python scripts/train.py civic   # garbage / pothole / sewage / water_leakage / other
  python scripts/train.py waste   # household waste item -> material (Which Bin?)

Writes the best weights to ml/weights/<task>_cls.pt and copies them into
backend/app/ml/weights/ where the API loads them. Prints held-out test
accuracy and a confusion matrix.
"""

import json
import shutil
import sys
from collections import Counter
from pathlib import Path

from ultralytics import YOLO

ROOT = Path(__file__).resolve().parents[1]
BACKEND_WEIGHTS = ROOT.parent / "backend" / "app" / "ml" / "weights"

SETTINGS = {
    "civic": {"epochs": 40, "imgsz": 256},
    "waste": {"epochs": 30, "imgsz": 224},
}


def evaluate(model: YOLO, test_dir: Path) -> None:
    classes = sorted(p.name for p in test_dir.iterdir() if p.is_dir())
    confusion = {actual: Counter() for actual in classes}
    for actual in classes:
        images = [p for p in (test_dir / actual).iterdir() if p.is_file()]
        for result in model.predict([str(p) for p in images], imgsz=model.overrides.get("imgsz", 224), verbose=False, stream=True):
            confusion[actual][result.names[result.probs.top1]] += 1

    total = sum(sum(row.values()) for row in confusion.values())
    correct = sum(confusion[c][c] for c in classes)
    print(f"\nTest accuracy: {correct}/{total} = {100 * correct / total:.1f}%")
    width = max(len(c) for c in classes) + 2
    print("\nConfusion (rows = actual, cols = predicted):")
    print(" " * width + "".join(f"{c[:8]:>9}" for c in classes))
    for actual in classes:
        row = confusion[actual]
        recall = row[actual] / max(1, sum(row.values()))
        print(f"{actual:<{width}}" + "".join(f"{row[p]:>9}" for p in classes) + f"   recall {100 * recall:.0f}%")


def main() -> None:
    task = sys.argv[1] if len(sys.argv) > 1 else "civic"
    if task not in SETTINGS:
        sys.exit(f"Unknown task {task!r}; use one of {list(SETTINGS)}")
    data = ROOT / "datasets" / task
    settings = SETTINGS[task]

    model = YOLO("yolo11n-cls.pt")
    model.train(
        data=str(data),
        epochs=settings["epochs"],
        imgsz=settings["imgsz"],
        batch=64,
        patience=10,
        device=0,
        workers=4,
        project=str(ROOT / "runs"),
        name=task,
        exist_ok=True,
        seed=2026,
        verbose=False,
    )

    best = ROOT / "runs" / task / "weights" / "best.pt"
    (ROOT / "weights").mkdir(exist_ok=True)
    target = ROOT / "weights" / f"{task}_cls.pt"
    shutil.copy2(best, target)
    BACKEND_WEIGHTS.mkdir(parents=True, exist_ok=True)
    shutil.copy2(best, BACKEND_WEIGHTS / f"{task}_cls.pt")

    # ONNX copy + class names for the lightweight onnxruntime backend used on
    # the cloud deployment (no PyTorch there).
    trained = YOLO(str(target))
    onnx_file = Path(trained.export(format="onnx", imgsz=settings["imgsz"], simplify=True, dynamic=False))
    shutil.copy2(onnx_file, BACKEND_WEIGHTS / f"{task}_cls.onnx")
    names = [trained.names[i] for i in range(len(trained.names))]
    (BACKEND_WEIGHTS / f"{task}_cls.json").write_text(json.dumps({"names": names, "imgsz": settings["imgsz"]}, indent=2))
    print(f"\nSaved {target}, and .pt/.onnx/.json into {BACKEND_WEIGHTS}")

    evaluate(YOLO(str(target)), data / "test")


if __name__ == "__main__":
    main()

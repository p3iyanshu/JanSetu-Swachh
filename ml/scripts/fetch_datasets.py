"""Download public datasets and build the two classification datasets:

  datasets/civic/<split>/<class>/   garbage, pothole, sewage, water_leakage, other
  datasets/waste/<split>/<class>/   biodegradable, cardboard, cloth, glass, metal,
                                    paper, plastic, hazardous, medical

Sources are open Roboflow Universe projects (exported with ROBOFLOW_API_KEY
from backend/.env) plus Imagenette for generic "no civic issue" photos.
Detection datasets are turned into whole-image labels: an image counts for a
class if it has at least one box. Augmented copies of the same photo
("name_jpg.rf.<hash>.jpg") are kept in the same split so validation accuracy
isn't inflated by near-duplicates.

Usage (from ml/, venv active):  python scripts/fetch_datasets.py
"""

import hashlib
import os
import random
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path

from dotenv import dotenv_values

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "datasets" / "raw"
OUT = ROOT / "datasets"
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
SPLITS = {"train": 0.8, "val": 0.1, "test": 0.1}
MAX_PER_CLASS = 1500
random.seed(2026)

# (workspace, project, format, how to label) - "detection:<class>" labels
# images that contain boxes; "classification:{source_class: target}" maps
# folder classes; "empty:<class>" labels images with NO boxes (e.g. roads
# without potholes -> other).
CIVIC_SOURCES = [
    # Checked by eye: street-level garbage heaps, dumped bags, overflowing bins.
    # (Excluded after inspection: "street-trash" = close-ups of single items,
    # "garbage-clixe" = one CCTV view of the same dumpsters, "sewage/sewage" =
    # CCTV from inside sewer pipes - none look like a citizen's photo.)
    ("garbage-detection-czeg5", "garbage_detection-wvzwv", "yolov8", "detection:garbage"),
    ("wastemanager", "waste-1k6gv", "yolov8", "detection:garbage"),
    ("mariswary-deepak-4ajr0", "garbage-can-overflow", "yolov8", "detection:garbage"),
    ("brad-dwyer", "pothole-voxrl", "yolov8", "detection:pothole"),
    ("indian-institute-of-technology-madras-xamot", "pothole-detection-huf2x", "yolov8", "detection:pothole"),
    ("chaitanya-kharche", "drain-overflow", "yolov8", "detection:sewage"),
    ("sewage-3rtqt", "water-leakage-agrsb", "yolov8", "detection:water_leakage"),
    ("water-leakage-detection", "water-leakage", "yolov8", "detection:water_leakage"),
    # Streetlights / poles (day and night) are civic scenes that are NOT a
    # waste, road or water issue - teach the model to say "other" for them.
    ("pothole-fw8hn", "street_light-0wrmn", "yolov8", "detection:other"),
    ("sashank-s", "street-light", "yolov8", "detection:other"),
    ("carto", "road-quality-classification", "folder",
     "classification:{'01_asphalt(Good)': 'other', '05_paved(Regular)': 'other', '02_asphalt(Regular)': 'other'}"),
]

WASTE_SOURCES = [
    ("material-identification", "garbage-classification-3", "yolov8", "detection-classes"),
    # Despite the name this set has hazardous / medical / organic / clothes
    # classes - the only public source here for the special-care and
    # sanitary streams.
    ("long-hng-trn-ba1ey", "garbage-classification-juvcb", "yolov8",
     "detection-classes:{'hazardous-waste': 'hazardous', 'medical-waste': 'medical', "
     "'organic-waste': 'biodegradable', 'recyclable-waste-clothes': 'cloth', "
     "'recyclable-waste-cardboard': 'cardboard', 'recyclable-waste-glass': 'glass', "
     "'recyclable-waste-metal': 'metal', 'recyclable-waste-paper': 'paper', "
     "'recyclable-waste-plastic': 'plastic', 'recyclable-waste-nylonbag': 'plastic'}"),
]

WASTE_CLASS_MAP = {
    "biodegradable": "biodegradable", "cardboard": "cardboard", "cloth": "cloth", "glass": "glass",
    "metal": "metal", "paper": "paper", "plastic": "plastic",
}


def api_key() -> str:
    env = dotenv_values(ROOT.parent / "backend" / ".env")
    key = os.getenv("ROBOFLOW_API_KEY") or env.get("ROBOFLOW_API_KEY")
    if not key:
        sys.exit("ROBOFLOW_API_KEY not found (set it or fill backend/.env)")
    return key


def download_roboflow(rf, workspace, project, fmt):
    target = RAW / f"{workspace}__{project}"
    if target.exists() and any(target.rglob("*.jpg")):
        print(f"  cached {workspace}/{project}")
        return target
    for attempt in range(1, 4):  # downloads occasionally get cut off
        try:
            proj = rf.workspace(workspace).project(project)
            versions = sorted(proj.versions(), key=lambda v: int(str(v.version).split("/")[-1]))
            if not versions:
                print(f"  ! {workspace}/{project}: no versions")
                return None
            version = versions[-1]
            print(f"  downloading {workspace}/{project} v{str(version.version).split('/')[-1]} ({fmt})")
            version.download(fmt, location=str(target), overwrite=True)
            return target
        except Exception as exc:  # keep going with the other sources
            print(f"  ! {workspace}/{project} (attempt {attempt}): {str(exc)[:160]}")
            shutil.rmtree(target, ignore_errors=True)
    return None


def base_key(path: Path) -> str:
    """Groups Roboflow augmentations of one photo together."""
    stem = path.stem
    stem = re.split(r"\.rf\.", stem)[0]
    return f"{path.parent.parent.parent.name}/{stem}"


def label_lines(image: Path):
    label = image.parent.parent / "labels" / (image.stem + ".txt")
    if not label.exists():
        return None
    return [line.split() for line in label.read_text().splitlines() if line.strip()]


def collect_civic(folder: Path, rule: str, bucket):
    kind, _, arg = rule.partition(":")
    if kind == "classification":
        mapping = eval(arg)  # noqa: S307 - literal dict from this file
        for split_dir in folder.iterdir():
            if not split_dir.is_dir():
                continue
            for class_dir in split_dir.iterdir():
                target = mapping.get(class_dir.name)
                if not target:
                    continue
                for image in class_dir.iterdir():
                    if image.suffix.lower() in IMAGE_EXT:
                        bucket[target].append(image)
        return
    for image in folder.rglob("*"):
        if image.suffix.lower() not in IMAGE_EXT or image.parent.name != "images":
            continue
        lines = label_lines(image)
        if lines is None:
            continue
        if kind == "detection" and lines:
            bucket[arg].append(image)
        elif kind == "empty" and not lines:
            bucket[arg].append(image)


def collect_waste(folder: Path, rule: str, bucket):
    yaml_path = next(folder.rglob("data.yaml"), None)
    if yaml_path is None:
        return
    names_match = re.search(r"names:\s*\[(.*?)\]", yaml_path.read_text(), re.S)
    if names_match:
        names = [n.strip().strip("'\"") for n in names_match.group(1).split(",")]
    else:
        names = re.findall(r"^\s*-\s*(.+)$", yaml_path.read_text().split("names:")[1], re.M)
    only = eval(rule.partition(":")[2]) if ":" in rule else None  # noqa: S307
    for image in folder.rglob("*"):
        if image.suffix.lower() not in IMAGE_EXT or image.parent.name != "images":
            continue
        lines = label_lines(image)
        if not lines:
            continue
        classes = {names[int(parts[0])].strip().lower() for parts in lines if parts and parts[0].isdigit() and int(parts[0]) < len(names)}
        if len(classes) != 1:
            continue  # only single-material images make clean labels
        name = classes.pop()
        if only is not None:
            target = only.get(name)
        else:
            target = WASTE_CLASS_MAP.get(name)
        if target:
            bucket[target].append(image)


IMAGENETTE_URL = "https://s3.amazonaws.com/fast-ai-imageclas/imagenette2-160.tgz"
IMAGENETTE_GARBAGE_TRUCK = "n03417042"


def add_imagenette(bucket, limit=700):
    """Generic everyday photos (minus the garbage-truck class) as 'other'.
    Fetched from fast.ai's official mirror (~94 MB)."""
    import tarfile
    import urllib.request

    folder = RAW / "imagenette2-160"
    if not folder.exists():
        archive = RAW / "imagenette2-160.tgz"
        if not archive.exists():
            print("  downloading Imagenette (160px, ~94 MB) for 'other'")
            urllib.request.urlretrieve(IMAGENETTE_URL, archive)
        with tarfile.open(archive) as tar:
            tar.extractall(RAW)
        archive.unlink()
    images = [
        path for path in folder.rglob("*.JPEG")
        if path.parent.name != IMAGENETTE_GARBAGE_TRUCK
    ]
    random.shuffle(images)
    bucket["other"].extend(images[:limit])
    print(f"    +{min(limit, len(images))} images")


def write_split(bucket, name):
    out = OUT / name
    if out.exists():
        shutil.rmtree(out)
    summary = {}
    for cls, images in bucket.items():
        groups = defaultdict(list)
        for image in images:
            groups[base_key(image)].append(image)
        keys = sorted(groups)
        random.shuffle(keys)
        # Cap by photos, keeping all augmentations of a kept photo together.
        kept, count = [], 0
        for key in keys:
            if count >= MAX_PER_CLASS:
                break
            kept.append(key)
            count += len(groups[key])
        n = len(kept)
        cut_train = int(n * SPLITS["train"])
        cut_val = cut_train + max(1, int(n * SPLITS["val"]))
        parts = {"train": kept[:cut_train], "val": kept[cut_train:cut_val], "test": kept[cut_val:]}
        summary[cls] = {}
        for split, split_keys in parts.items():
            target = out / split / cls
            target.mkdir(parents=True, exist_ok=True)
            total = 0
            for key in split_keys:
                # Only the original (first) copy goes to val/test.
                files = groups[key] if split == "train" else groups[key][:1]
                for image in files:
                    digest = hashlib.md5(str(image).encode()).hexdigest()[:10]
                    shutil.copy2(image, target / f"{digest}{image.suffix.lower()}")
                    total += 1
            summary[cls][split] = total
    print(f"\n{name}:")
    for cls, counts in sorted(summary.items()):
        print(f"  {cls:15s} " + "  ".join(f"{k}={v}" for k, v in counts.items()))


def main():
    from roboflow import Roboflow

    RAW.mkdir(parents=True, exist_ok=True)
    rf = Roboflow(api_key=api_key())
    only = sys.argv[1] if len(sys.argv) > 1 else None

    if only == "waste":
        return build_waste(rf)

    civic = defaultdict(list)
    print("Civic issue sources:")
    for workspace, project, fmt, rule in CIVIC_SOURCES:
        folder = download_roboflow(rf, workspace, project, fmt)
        if folder:
            before = sum(len(v) for v in civic.values())
            collect_civic(folder, rule, civic)
            print(f"    +{sum(len(v) for v in civic.values()) - before} images")
    add_imagenette(civic)
    write_split(civic, "civic")
    if only != "civic":
        build_waste(rf)


def build_waste(rf):
    waste = defaultdict(list)
    print("\nWaste item sources:")
    for workspace, project, fmt, rule in WASTE_SOURCES:
        folder = download_roboflow(rf, workspace, project, fmt)
        if folder:
            before = sum(len(v) for v in waste.values())
            collect_waste(folder, rule, waste)
            print(f"    +{sum(len(v) for v in waste.values()) - before} images")
    write_split(waste, "waste")


if __name__ == "__main__":
    main()

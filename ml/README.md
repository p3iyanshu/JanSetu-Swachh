# JanSetu-Swachh image models

Two small image classifiers (YOLO11n-cls, fine-tuned from ImageNet weights) that run inside the backend. They power the AI category suggestion on a citizen's photo and the "Which Bin?" item scan, without internet access or hosted-model credits.

| Model | Classes | Used by |
|---|---|---|
| **civic** | garbage, pothole, sewage, water_leakage, other | `POST /api/v1/ai/analyze-issue` |
| **waste** | biodegradable, cardboard, cloth, glass, hazardous, medical, metal, paper, plastic | `POST /api/v1/swachh/classify-item` (mapped to wet / dry / sanitary / special care) |

The backend loads `backend/app/ml/weights/*.onnx` with onnxruntime, which is light enough for Render's free tier. It falls back to the `.pt` file through Ultralytics, and then to the hosted Roboflow models. When several civic ONNX files are present (`civic_cls.onnx`, `civic_cls_v1.onnx`), their probabilities are averaged.

## Results

### Civic model

- **Old hosted Roboflow setup, on 9 real citizen photos:** 4/9 correct. It missed an obvious garbage heap and flagged a website screenshot as sewage.
- **v1:** 97.0% on its own held-out test set. It had not seen Indian street scenes as "no issue" examples.
- **v2:** adds Indian street scenes and more water-leak photos, and scores 98.2% on the broader held-out test set (393 images). It flags non-issue images as water leaks.
- **v1 + v2 averaged (deployed):**
  - 95.4% on the broader test set, with **0 of 116** "no issue" photos flagged.
  - **7/9** on the real photos, with 0 false alarms. Both garbage photos are detected at 1.00 confidence.

The remaining weak spot is water leaks and sewage: public datasets for them are small. The backend only auto-selects a category above 0.55 confidence, and the citizen can always change it.

### Waste model

The waste model scores **93.5%** on 1,042 held-out test photos. Every class has at least 90% recall: hazardous 97%, biodegradable 95%, metal 95%, medical 94%, glass 93%, cardboard 93%, paper 92%, cloth 90%, plastic 90%. The API maps each class to a stream: biodegradable → wet; hazardous → special care; medical → sanitary; the rest → dry.

## Data

`scripts/fetch_datasets.py` downloads open Roboflow Universe datasets using `ROBOFLOW_API_KEY` from `backend/.env`. It also downloads Imagenette (from fast.ai's mirror) for generic "other" photos. It builds whole-image classification folders with 80/10/10 train/val/test splits. All augmented copies of one photo stay in the same split.

Every source was checked by eye before it was used. Three were dropped for not looking like a citizen's photo:
- in-sewer-pipe CCTV footage;
- close-ups of single litter items;
- thermal-camera leak images.

Small classes (sewage, water leak, cloth, medical) are oversampled in the training split only.

| Class | Sources |
|---|---|
| garbage | garbage-detection-czeg5/garbage_detection, mariswary-deepak/garbage-can-overflow |
| pothole | brad-dwyer/pothole, IIT Madras pothole-detection |
| sewage | chaitanya-kharche/drain-overflow |
| water_leakage | sewage-3rtqt/water-leakage, water-leakage-detection/water-leakage |
| other | carto/road-quality-classification (good roads), sashank-s/street-light (Indian streets), Imagenette |
| waste items | material-identification/garbage-classification-3, long-hng-trn/garbage-classification (hazardous, medical, organic, clothes) |

## Reproduce

```powershell
cd ml
python -m venv venv
.\venv\Scripts\pip install torch torchvision --index-url https://download.pytorch.org/whl/cu128
.\venv\Scripts\pip install ultralytics roboflow python-dotenv onnx onnxslim onnxruntime
.\venv\Scripts\python scripts\fetch_datasets.py        # ~1 GB of data into ml/datasets/
.\venv\Scripts\python scripts\train.py civic            # writes backend/app/ml/weights/civic_cls.*
.\venv\Scripts\python scripts\train.py waste
```

Run one training at a time: two at once ran out of memory on a 16 GB laptop. To check the backend on your own photos, run:

```powershell
cd ..\backend
.\venv\Scripts\python -m scripts.evaluate_classifier <folder> --labels labels.csv
```

# JanSetu (জনসেতু / जनसेतु) — Crowdsourced Civic Issue Reporting & Resolution System

**Smart India Hackathon 2026 — Problem Statement SIH25031**  
**Team JanSetu | Presidency University, Bengaluru**  
*Team Lead:* Priyanshu Choudhary | *Members:* Rajat Choudhury, Nihal Jeremiah, Shreya Saha, Khushi Singh

---

## Architecture Overview

JanSetu is built across three primary layers:

1. **Mobile Citizen App (`/mobile`)**: Flutter cross-platform app designed for extreme accessibility (voice input, auto GPS, icon-first UI, minimum 48dp targets, OTP-only auth).
2. **FastAPI Backend (`/backend`)**: Python FastAPI async REST API powered by PostgreSQL + PostGIS for spatial queries, YOLOv8 for issue classification, CLIP embeddings for duplicate detection, LLM structured description generation, and automated SLA escalation timers.
3. **Admin Dashboard (`/dashboard`)**: ReactJS web application for department officers and municipal admins featuring live GIS mapping, ticket assignment, computer-vision before/after resolution verification, and public trust leaderboards.

---

## Quick Start (Local Setup on Windows)

### Prerequisites
- Python 3.11+
- Node.js v18+ & npm
- Flutter SDK 3.x
- PostgreSQL 14+ with PostGIS extension enabled

---

### 1. Backend Service Setup

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env

# Run database migrations
alembic upgrade head

# Start API server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
- API Swagger UI: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

---

### 2. Admin Dashboard Setup

```powershell
cd dashboard
npm install
npm run dev
```
- Local Web Server: http://localhost:5173

---

### 3. Citizen Mobile App Setup

```powershell
cd mobile
flutter pub get
flutter run
```

---

## Directory Structure

```
D:\JanSetu
├── mobile/            # Flutter citizen app (Riverpod, go_router, flutter_map)
├── backend/           # Python FastAPI backend (SQLAlchemy, PostGIS, YOLO, CLIP)
├── dashboard/         # ReactJS admin dashboard (Vite, Leaflet maps)
├── ml/                # Dataset configs, fine-tuning scripts, model weights
├── docs/              # Specifications, API documentation
└── README.md
```

# JanSetu — Project Context & Onboarding Guide

**Read this before touching the code.** It reflects what's actually true in the codebase today — not the original pitch/spec. Where the two disagree, this document wins; `README.md` and `docs/spec.md` describe the original plan and are stale in places (flagged below).

---

## 1. What JanSetu is

JanSetu is a crowdsourced civic issue reporting and resolution platform built for **Smart India Hackathon 2026** (Problem Statement SIH25031, Team JanSetu, Presidency University Bengaluru). Citizens photograph a civic problem (pothole, garbage, water leak, sewage overflow) in a mobile app, an AI model classifies it, it's auto-routed to the right municipal department, a department officer/worker resolves it with GPS-tagged photo proof, an admin reviews and approves the resolution, and the citizen confirms they're satisfied (or reopens it if not).

## 2. The four services

| Service | Path | Stack | Port (local) |
|---|---|---|---|
| Backend API | `/backend` | FastAPI (Python), SQLAlchemy, PostgreSQL | 8000 |
| Admin Dashboard | `/dashboard` | React 18 + Vite, plain CSS | 5173 |
| Mobile App (citizen + worker) | `/mobile` | Flutter, Riverpod, go_router | — (device/emulator) |
| Voice-to-Text Service | `/voice-backend` | FastAPI, wraps Sarvam AI's speech-to-text API | 8001 |
| Solid Waste Demo Mobile App (citizen + worker) | `/mobile_demo` | Flutter, same stack as `/mobile` | — (device/emulator) |
| Department-scoped Demo Admin Dashboard | `/dashboard_demo` | React 18 + Vite, same stack as `/dashboard` | 5174 (garbage) / 5175 (pwd) / 5176 (water) |

All three FastAPI-adjacent things (`backend`, `voice-backend`) are separate processes with separate `.env` files and separate venvs — they don't share a virtualenv or config.

**Demo builds (`mobile_demo/`, `dashboard_demo/`) point at the same shared backend and database as the real apps** — they don't have their own backend, so tickets filed from any citizen app show up in every dashboard that's scoped to see them.

- **Citizen + worker reporting/resolving uses the real `/mobile` app** (all 4 citizen-facing categories: garbage, pothole, water leakage, sewage; auto-routes by category via `backend/app/services/routing.py`). `mobile_demo` still exists as an earlier, separate single-department (Garbage/Solid-Waste-only) Flutter build — it wasn't folded into this; leave it alone unless asked.
- **Admin is split into department-scoped dashboards, one shared codebase.** `dashboard_demo/src/App.jsx` picks a `DEPARTMENT_PRESETS` entry (`pwd` | `water` | `garbage`) from the `VITE_DEMO_DEPARTMENT` env var at build/dev-server time — not three separate copied projects. Each preset filters every fetch (reports/departments/officers) down to just its department/categories:
  - `pwd` → PWD Public Works, category: pothole. `npm run dev:pwd` (port 5175), `.env.pwd`.
  - `water` → BWSSB Water & Sewage Board, categories: water_leakage + sewage_overflow (these already share one department in the backend, no extra combining logic needed). `npm run dev:water` (port 5176), `.env.water`.
  - `garbage` → BBMP Solid Waste Management, category: garbage_overflow. `npm run dev:garbage` or plain `npm run dev` (port 5174, the default/backward-compatible mode), `.env.garbage`.
  - Streetlight/illegal-dumping/damaged-property/other are out of scope for all three — no admin page, and the citizen app already doesn't expose them for selection.
  - `npm run build:pwd` / `build:water` / `build:garbage` build each mode's `dist/`.
- Keep UI/UX identical to the real `/dashboard` otherwise — any admin-flow change made to `/dashboard` should usually be ported to `dashboard_demo/src/App.jsx` too (it stays a fork, not a shared package).

---

## 3. Local setup (corrected — the README's steps are partially stale)

### Prerequisites
- Python 3.11+
- Node.js v18+ & npm
- Flutter SDK 3.x
- PostgreSQL 17 with the PostGIS extension installed (extension is installed but not actually used by any query — see §6)

### Backend
```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env   # then fill in real values, see §7
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
Or just `.\start.ps1` once `.env` is filled in. **Do not run `alembic upgrade head`** — the README mentions it but there are no migrations in `backend/alembic/versions/` (that folder doesn't exist). Schema is created via `Base.metadata.create_all()` plus an `ensure_runtime_schema()` function in `app/main.py` that runs raw `ALTER TABLE`/`ALTER TYPE` statements on every startup. See §8 for a real gotcha this causes.

- Swagger UI: http://localhost:8000/docs
- On first run, four departments are auto-seeded (PWD, BBMP Solid Waste, BWSSB Water & Sewage, BESCOM Electrical) — this seed is idempotent, safe to restart repeatedly.

### Admin Dashboard
```powershell
cd dashboard
npm install
npm run dev
```
http://localhost:5173 — no `.env` needed; the API base URL is hardcoded to `http://localhost:8000/api/v1` in `src/api/client.js`.

### Voice-to-Text Service
```powershell
cd voice-backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env   # needs a free SARVAM_API_KEY from sarvam.ai
.\start.ps1
```
Runs on port 8001. The mobile app's voice-note feature calls this, not the main backend.

### Mobile App
```powershell
cd mobile
flutter pub get
flutter run --dart-define=JANSETU_API_BASE_URL=http://<your-lan-ip>:8000/api/v1
```
**Important:** `mobile/lib/core/constants/app_constants.dart` has a hardcoded fallback LAN IP for Android devices, because a physical/emulated device can't reach `localhost` on your dev machine. Always pass `--dart-define=JANSETU_API_BASE_URL=...` with your current machine's LAN IP (check `ipconfig`) when running on a device — the fallback IP baked into the code will be stale for you.

### Getting a clean slate for testing
```powershell
cd backend
.\venv\Scripts\python.exe -m scripts.reset_demo_data
```
Wipes all tickets/resolutions/notifications and resets the ticket-ID counter back to 1 (so the next ticket is `JAN-000001`), deletes any leftover officer accounts with `emp_id` starting `TEST` (pytest leftovers), and **never touches departments**. Pass `--all-officers` to also wipe every officer/admin/worker and every citizen user for a fully blank slate.

---

## 4. Repo structure

```
D:\JanSetu
├── backend/
│   ├── app/
│   │   ├── main.py            # entrypoint, CORS, static /uploads mount, ensure_runtime_schema()
│   │   ├── database.py        # SQLAlchemy engine/session
│   │   ├── api/                # admin.py, ai.py, auth.py, departments.py, reports.py, router.py
│   │   ├── models/__init__.py  # ALL SQLAlchemy models in one file
│   │   ├── schemas/__init__.py # ALL Pydantic schemas in one file
│   │   ├── services/            # dedup.py, notification_service.py, routing.py, scoring.py, sla.py
│   │   └── ml/                  # roboflow_civic_classifier.py — the only file here, and it's LIVE
│   ├── scripts/reset_demo_data.py
│   ├── tests/                   # pytest, 16 tests, all passing
│   └── .env / .env.example
├── voice-backend/                # separate FastAPI service, Sarvam AI speech-to-text
├── dashboard/
│   └── src/
│       ├── App.jsx               # the ENTIRE dashboard UI lives in this one file (~660 lines)
│       ├── api/client.js
│       └── index.css             # all styling, no CSS framework
├── dashboard_demo/                # department-scoped demo admin (see §2) — fork of dashboard/, not shared code
├── mobile/
│   └── lib/
│       ├── main.dart             # go_router route table
│       ├── core/                 # constants, network client, services (FCM, geocoding, speech-to-text, photo stamping)
│       ├── data/                 # models + repositories
│       ├── features/
│       │   ├── auth/, home/, report/, tracking/    # citizen screens
│       │   └── worker/                              # worker screens
│       └── widgets/
├── mobile_demo/                   # single-department (Garbage) demo mobile app (see §2) — fork of mobile/, not shared code
├── docs/
│   ├── spec.md                              # original architecture spec — see §6 for what's now stale in it
│   ├── design-brief-for-claude-design.md    # visual redesign brief for the admin dashboard
│   └── PROJECT_CONTEXT.md                   # this file
└── README.md                                # original pitch doc — also stale in places, see §6
```

---

## 5. Core domain concepts

**Ticket lifecycle** (`ReportStatus`):
```
submitted → assigned → in_progress → pending_approval → resolved
                ↑_________________________|   (admin reject sends pending_approval back to in_progress)
                                  resolved → reopened → in_progress   (citizen "not satisfied")
```
Every ticket gets its own row and its own ID (`JAN-000042`, derived from the DB primary key) — **there is no merging of duplicate/nearby reports.** Each submission is always a distinct ticket, even if it's the same issue at the same spot reported twice.

**Citizen self-cancel:** the citizen can cancel their own ticket at any point up to `resolved` (`POST /api/v1/reports/{id}/cancel`, any status except `resolved`/already-`cancelled`) — e.g. if they filed it by mistake. This is a soft-cancel: the row stays in the DB with `status = cancelled` and an optional `cancellation_reason`, it's not deleted. If a worker was already assigned, cancelling frees their capacity slot the same way rejecting/reopening does. Both dashboards (`/dashboard` and `/dashboard_demo`) render `cancelled` as its own badge/status box rather than falling back to an unstyled default.

**Officers table** does double duty: a row with a `department_id` is a department worker/head; a row with `department_id = NULL` is a platform admin. `is_department_head` is true for whoever signs up first against a department.

**Worker capacity rule:** an officer can have at most 3 active tickets (`assigned`/`in_progress`/`reopened`) at once — enforced both when listing "eligible workers" and when assigning.

**Citizen-selectable categories** (mobile Report Issue screen): `garbage_overflow`, `pothole`, `water_leakage`, `sewage_overflow` — only these 4. Two categories that exist in the backend/admin filters (`broken_streetlight`, `illegal_dumping`) were deliberately removed from the citizen picker; they still exist as valid category values for historical tickets and admin filtering, just not selectable when filing a new report.

**No authentication middleware anywhere.** Every `/admin/*` endpoint is reachable by anyone who knows the URL — there's no session/JWT check confirming the caller is actually the officer they claim to be. The frontend just doesn't expose UI for actions a given role shouldn't do. This is a known, long-standing gap, not something that broke recently — treat any admin-side change with that in mind.

---

## 6. What's real vs. what's aspirational (stale doc corrections)

The original `README.md` / `docs/spec.md` describe some things that were never built or were built differently. Don't trust those docs for the items below:

| Docs claim | Reality |
|---|---|
| YOLOv8 for classification | Actually **Roboflow-hosted YOLOv11-nano models**, called via their serverless inference API — nothing runs locally. **6 detectors** run in parallel per image across 3 Roboflow accounts/workspaces, scoped to only the 4 citizen-facing categories (pothole, garbage, water leak, sewage — 3 of those categories have multiple redundant detectors; sewage alone has 3). Highest-confidence result above a 0.35 threshold wins. Streetlight and road-damage workflows are still configured/callable in `roboflow_civic_classifier.py._workflows` but are filtered out of `classify_image()`'s competition via `_CITIZEN_FACING_CATEGORIES`, since those two categories were already removed from the citizen picker (see §5) — before this filter, one of them winning the overall confidence race could make the app wrongly claim "AI could not confidently detect" on a photo it actually detected fine, just as a category the citizen can't pick. `illegal_dumping` and `other` have no trained model at all. |
| CLIP embeddings for duplicate detection | Not implemented. There's no dedup logic at all now (see §5 — duplicates aren't merged, every submission is its own ticket). |
| PostGIS spatial queries (`ST_DWithin` etc.) | The PostGIS extension is installed but the `Report.location` geometry column is never written to and never queried — always NULL. All location logic uses plain `latitude`/`longitude` floats. |
| `alembic upgrade head` in Quick Start | Does nothing — no migrations exist. Real schema changes happen via `ensure_runtime_schema()` in `app/main.py` (see §8 for a gotcha this causes). |
| Automated SLA escalation timers | `apscheduler` is a dependency but is never imported/scheduled anywhere. `sla_deadline` is computed once at ticket creation and never re-checked. There's no "SLA breached" status or indicator anywhere in the UI today (the admin-dashboard redesign brief in `docs/design-brief-for-claude-design.md` defines a color for this state, forward-looking, but it doesn't exist yet). |
| Computer-vision before/after resolution verification | `cv_similarity_score` is hardcoded to `0.91` on every ticket resolution. No real image comparison happens. |
| Live GIS map / Leaderboard on the dashboard | No map or leaderboard renders anywhere in the admin dashboard — it's a single-file app that implements everything inline. (The unused `LiveMap.jsx`/`Leaderboard.jsx`/`MetricCards.jsx`/`ReportList.jsx` stub components that used to sit in `dashboard/src/components/` unreferenced have since been deleted — see §9.) |

Map tiles/geocoding that *is* real: the mobile app's location picker uses `flutter_map` with raw OpenStreetMap tiles, and forward/reverse geocoding via OSM's Nominatim API — no Google Maps or paid map API anywhere in the codebase.

---

## 7. External services & credentials

All of these live in gitignored `.env` files — real values are **not** in the repo, only `.env.example` placeholders. Get the real values from whoever holds them (team lead) rather than creating fresh accounts, since several are already wired to trained models specific to this project:

| Service | Used for | Where configured |
|---|---|---|
| Roboflow (3 separate accounts/workspaces) | Image classification — see the table in §6 | `backend/.env` — `ROBOFLOW_*` vars, see `.env.example` for the full list |
| Sarvam AI | Speech-to-text for the voice-note feature | `voice-backend/.env` — `SARVAM_API_KEY` |
| Firebase (project `jansetu-66cd8`) | Push notifications | `backend/firebase-service-account.json` (gitignored) + `mobile/android/app/google-services.json` (gitignored) |
| PostgreSQL | Main database | `backend/.env` — `DATABASE_URL` |

**Do not commit real `.env` files, `firebase-service-account.json`, or `google-services.json`.** The root `.gitignore` covers all of these — double-check `git status` before committing if you add new credential files.

---

## 8. Known gotchas (things that will genuinely trip you up)

1. **Postgres enum stores UPPERCASE member names, not the lowercase `.value` strings.** `ReportStatus` is a Python `str, enum.Enum` with lowercase values (`"pending_approval"`), but SQLAlchemy binds native Postgres enums by `.name`, so the actual Postgres type stores `PENDING_APPROVAL`. If you ever add a new `ReportStatus` value, the `ALTER TYPE reportstatus ADD VALUE '...'` must use the **uppercase** member name, run in its own autocommit connection (see `ensure_runtime_schema()`), not inside a normal transaction.
2. **LAN IP hardcoded for mobile.** See §3 — always pass `--dart-define=JANSETU_API_BASE_URL=...` when running on a device.
3. **Two backend-adjacent servers can silently fight over the same port** if you have more than one terminal running `uvicorn`. Check `netstat -ano | findstr ":8000 :8001 :5173"` before starting anything if things seem to be serving stale behavior.
4. **`--reload` doesn't always save you.** If backend behavior seems out of date, confirm the server actually restarted — don't assume a running `uvicorn --reload` process picked up your latest edit.
5. **Mobile code changes need a real rebuild to show up on a device.** A hot reload only helps if you have an active `flutter run` debug session attached; an already-installed APK needs a fresh `flutter run`/reinstall.
6. **Password hashing is SHA-256, not bcrypt.** Known weak point, not fixed. Don't build anything that assumes it's secure.
7. **This repo is public on GitHub.** Never put real credentials, workspace names, or workflow/model IDs into `.env.example` files (or any other tracked file) — only placeholders like `your_x_here`. This already went wrong once: the original `backend/.env.example` shipped with real Roboflow workspace names and workflow IDs (including team members' names in the workspace slugs) from the very first commit, and was live on the public repo before being caught and sanitized. No actual API keys were exposed (those were already placeholders), so the practical risk was low, but git history wasn't rewritten to scrub the old values — treat anything ever committed to this repo as permanently public, `.gitignore` only stops *future* commits, not past ones.

---

## 9. Recent changes (most recent session)

- **Citizens can now cancel their own ticket** at any point before it's resolved (`POST /api/v1/reports/{id}/cancel`) — soft-cancel (`status = cancelled`, row stays for audit), frees the assigned officer's capacity slot if one was assigned. See §5.
- **AI category auto-suggest fixed**: `roboflow_civic_classifier.py` used to let streetlight/road-damage detectors (not citizen-selectable categories) win the overall confidence race, making the app wrongly claim "AI could not confidently detect" on photos it actually detected fine. Now filtered to only compete among the 4 citizen-facing categories. See §6's table.
- **Two new department-scoped demo builds**, sharing the real backend/database (§2 has the full breakdown): `mobile_demo/` (single-department, Garbage-only citizen+worker Flutter app) and `dashboard_demo/` (one React codebase, three `VITE_DEMO_DEPARTMENT` presets — pwd/water/garbage — instead of three separate admin dashboards).
- **Repo hygiene pass before making the repo widely shared**: deleted the dead-code files that used to sit unreferenced in the repo (`backend/app/ml/{yolo_classifier,clip_embeddings,llm_describer}.py` and their direct tests in `test_ai_pipeline.py`; `dashboard/src/components/{LiveMap,Leaderboard,MetricCards,ReportList}.jsx`), deleted the superseded `files/` directory (an old local-Whisper voice-backend prototype doc that contradicted the real, Sarvam-AI-based `voice-backend/`), sanitized real Roboflow workspace/workflow identifiers out of `backend/.env.example` (see §8, gotcha 7), and closed two `.gitignore` gaps (`.kotlin/` build caches, `backend/temp_uploads/`).
- Removed duplicate-ticket merging — every submission is now always its own ticket (§5).
- Fixed the mobile Report Issue screen retaining a previous photo/category/location across navigations — it now resets to a blank form every time it's opened.
- Added a tap-to-view detail sheet on the citizen tracking screen showing the original submitted photo + full description (previously only visible on the resolution proof photo, not the original submission).
- Removed "Street Light" and "Illegal Dumping" from the citizen-facing category picker (still valid values elsewhere).
- Added 4 more Roboflow detectors (2 direct-model, 2 workflow) across a third Roboflow workspace for sewage/streetlight, layered onto the existing 6 (later filtered down per the AI fix above).
- Added a "Resolution Time (hrs)" label above the previously-unlabeled hours input in the admin dashboard's assign-worker control.
- `reset_demo_data.py` now also resets the ticket-ID Postgres sequence back to 1, not just deleting rows.
- Fixed a real bug in the root `.gitignore`: a leftover Python-venv `lib/`/`lib64/` pattern was silently matching `mobile/lib/` at any depth, which would have excluded the entire Flutter app's source code from git. Now scoped to `venv/lib/` only.
- Repo pushed to GitHub for the first time (`github.com/p3iyanshu/JanSetu`, **public**) — there was **no git history at all** before that first push. `CLAUDE_CODE_HANDOVER.md` and `jansetu_state_dump.md` (an earlier, more narrative session-handoff doc) are intentionally excluded from the repo via `.gitignore` — read them locally if you want more blow-by-blow history, but don't expect them on GitHub.
- A visual redesign brief for the admin dashboard was written (`docs/design-brief-for-claude-design.md`) — no visual changes have been implemented yet, it's a spec for a future pass.

---

## 10. Suggested next steps

Pick based on what actually needs to work for the next demo/judging round, not necessarily in this order:

1. **Real SLA escalation** — spec'd, dependency installed, nothing built. If judges check `docs/spec.md` against the live app, this is one of the more visible gaps.
2. **Real CV resolution verification** — same story, currently faked with a hardcoded score.
3. **Admin endpoint auth** — genuinely worth fixing before any real deployment, not just for the demo.
4. **Apply the admin dashboard redesign** in `docs/design-brief-for-claude-design.md` once it's been through Claude Design.
5. Always run `python -m scripts.reset_demo_data` before a demo/testing round so ticket IDs and data are clean.

---

## 11. Team

From `README.md`: **Priyanshu Choudhary** (Team Lead), Rajat Choudhury, Nihal Jeremiah, Shreya Saha, Khushi Singh. Specific module ownership beyond the team lead isn't recorded anywhere in the code/commit history (there was no commit history until this session) — worth the team explicitly agreeing on/documenting who owns what going forward, e.g. in this file.

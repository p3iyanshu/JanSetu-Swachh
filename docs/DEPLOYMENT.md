# Deploying JanSetu-Swachh (free tier)

| Part | Host | Result |
|---|---|---|
| Database | [Neon](https://neon.tech) (PostgreSQL + PostGIS) | connection string |
| Backend API | [Render](https://render.com) (Blueprint in `render.yaml`) | `https://jansetu-swachh-api.onrender.com` |
| Web portal | [Netlify](https://netlify.com) (`dashboard/netlify.toml`) | `https://<your-site>.netlify.app` |
| Android app / admin exe | GitHub Releases | rebuilt to point at the Render URL |

Free Render services sleep after ~15 minutes without traffic; the first request afterwards takes 30-60 seconds while it wakes up.

## 1. Database - Neon

1. Sign up at neon.tech (GitHub login is fine) and create a project, region **Asia Pacific (Singapore)**.
2. On the project dashboard click **Connect** and copy the connection string. It looks like
   `postgresql://user:password@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`.

The backend enables PostGIS and creates all tables on first start.

## 2. Backend - Render

1. Sign up at render.com with GitHub and allow access to the `JanSetu-Swachh` repository.
2. **New -> Blueprint**, pick `JanSetu-Swachh`, branch `main`. Render reads `render.yaml`.
3. When asked for `DATABASE_URL`, paste the Neon connection string. Click **Apply**.
4. Wait for the first deploy (5-10 minutes). Open `https://<service>.onrender.com/health` - it should say `healthy`.
5. Optional AI features: service -> **Environment** -> **Add from .env**, paste the Roboflow / Sarvam lines from your local `backend/.env` (not `DATABASE_URL`), save.

On first start the backend creates the demo logins (`DEMO-ADMIN` / `DEMO-WORKER`, password `Demo@123`) and seeds sample waste tickets and collection rounds (`JANSETU_SEED_DEMO_DATA=1`).

## 3. Web portal - Netlify

1. **Add new site -> Import an existing project -> GitHub -> JanSetu-Swachh**.
2. Base directory `dashboard` (build command and publish folder come from `dashboard/netlify.toml`).
3. Environment variable `VITE_API_BASE_URL` = `https://<service>.onrender.com/api/v1`.
4. Deploy. If the site already exists, change the variable and **Deploys -> Trigger deploy**.

## 4. Apps pointing at the cloud backend

```powershell
cd mobile
flutter build apk --release --dart-define=JANSETU_API_BASE_URL=https://<service>.onrender.com/api/v1

cd ..\admin_desktop
$env:JANSETU_API_BASE_URL="https://<service>.onrender.com/api/v1"; npm run dist
```

Both apps still have a server-address setting on their login screens.

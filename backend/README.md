# Open Campus — Backend

A **stateless** FastAPI proxy that logs into UCAM on a student's behalf and
normalizes its responses to clean JSON. It stores nothing — no database, no copy
of student data; every response is fetched live and forgotten. The UCAM password
is used once at login and never stored.

## Run locally

```bash
cd backend
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements-dev.txt    # Windows
# source .venv/bin/activate && pip install -r requirements-dev.txt   # macOS/Linux

cp .env.example .env        # then set OC_SESSION_SECRET (see below)
uvicorn app.main:app --reload
```

Open http://127.0.0.1:8000/docs for the interactive API.

### Configuration (`.env`)

| Var | Required | Default | Notes |
|-----|----------|---------|-------|
| `OC_SESSION_SECRET` | yes (prod) | dev placeholder | Random string signing our JWTs. Generate: `python -c "import secrets; print(secrets.token_urlsafe(48))"` |
| `OC_DEBUG` | no | `false` | `true` only for local dev — bypasses the prod-safety gate. Keep `false` anywhere shared. |
| `OC_SESSION_TTL_MINUTES` | no | `60` | App token lifetime. |
| `OC_PER_USER_MIN_INTERVAL_SECONDS` | no | `1.0` | Min spacing between a session's UCAM requests. |
| `OC_CORS_ORIGINS` | web only | `[]` | JSON list of allowed web origins. Never `"*"`. |

The app refuses to start in non-debug mode with the placeholder secret or a
short key (`require_production_safety` in `config.py`).

## API

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/auth/login` | UCAM login → our JWT + roll. Password never stored. Rate-limited per IP. |
| POST | `/auth/logout` | Drop the in-memory UCAM session. |
| GET | `/auth/me` | Current student's roll. |
| GET | `/student/home` | Profile + term + CGPA + balance + advisor + routine. |
| GET | `/student/results` | Per-semester GPA + CGPA. |
| GET | `/student/attendance` | Per-course attendance. |
| GET | `/student/bill` | Fees, payments, waivers, dues. |
| GET | `/student/course-history` | All courses, grades, credits. |
| GET | `/student/advising` | Pre-advising data. |
| GET | `/student/marks`, `/student/marks/trimesters` | Item-wise marks per course. |
| GET | `/student/exam-routine` | Published exam routine links. |
| GET | `/student/notices` | Notices. |
| GET | `/student/avatar` | Profile photo (proxied with the session). |
| GET | `/transparency` | What the server does / doesn't store. |
| GET | `/health`, `/disclaimer` | Meta. |

All data is live. If the UCAM session expires, data routes return **409** so the
app shows a gentle "tap to re-login" prompt instead of a hard logout.

## Tests

```bash
.venv/Scripts/python -m pytest        # offline; no live UCAM needed
```

Parsing tests use the exact JSON/HTML shapes from UCAM, so they double as a
regression guard if the portal's format changes.

## Deploy to Render

This folder is Render-ready (Docker, honors `$PORT`, `/health` check).

**Option A — Blueprint (one click).** In Render: **New → Blueprint**, select this
repo. It reads [`render.yaml`](render.yaml), builds from the Dockerfile, and
generates `OC_SESSION_SECRET` automatically. Set `OC_CORS_ORIGINS` if you ship a
web build.

**Option B — manual web service.**
1. **New → Web Service**, connect the repo.
2. **Root Directory:** `backend`  ·  **Runtime:** Docker (uses `Dockerfile`).
3. Environment variables:
   - `OC_SESSION_SECRET` — a fresh 48-byte secret
   - `OC_DEBUG=false`
   - `OC_CORS_ORIGINS=["https://<your-web-origin>"]` (omit for native-only)
4. **Health check path:** `/health`. Deploy.

After deploy, confirm `https://<your-service>.onrender.com/health` returns
`{"status":"ok"}`. That URL is what the app is built against
(`--dart-define=OC_API_BASE=…`).

> Free-tier services sleep when idle; the first request after a sleep is slow.
> The app caches the last view on-device to hide that cold start.

Runs as a single process (sessions + rate-limit are in-memory). For multiple
instances, move `session_store` and `rate_limit` to Redis.

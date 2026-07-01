<div align="center">

# Open Campus

### A fast, private, open-source companion app for UIU's UCAM student portal

View your results, CGPA, attendance, bills, class routine, notices and more.
Your data. Your credentials. Nothing stored on our servers.

**Version 0.5.0 Beta** &nbsp;|&nbsp; Open for testing. Feedback and bug reports are very welcome.

<br />

[![Deploy Web](https://github.com/Cord1ess/Open-Campus/actions/workflows/deploy-web.yml/badge.svg)](https://github.com/Cord1ess/Open-Campus/actions/workflows/deploy-web.yml)
[![Tests](https://github.com/Cord1ess/Open-Campus/actions/workflows/test.yml/badge.svg)](https://github.com/Cord1ess/Open-Campus/actions/workflows/test.yml)
[![Backend Uptime](https://github.com/Cord1ess/Open-Campus/actions/workflows/keepalive.yml/badge.svg)](https://github.com/Cord1ess/Open-Campus/actions/workflows/keepalive.yml)

[![Flutter](https://img.shields.io/badge/Flutter-3.5%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://www.python.org)

[![Version](https://img.shields.io/badge/version-0.5.0%20Beta-orange)](https://github.com/Cord1ess/Open-Campus/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Cord1ess/Open-Campus?color=orange)](https://github.com/Cord1ess/Open-Campus/commits/main)
[![Repo Size](https://img.shields.io/github/repo-size/Cord1ess/Open-Campus?color=orange)](https://github.com/Cord1ess/Open-Campus)
[![Top Language](https://img.shields.io/github/languages/top/Cord1ess/Open-Campus?color=orange)](https://github.com/Cord1ess/Open-Campus)
[![Stars](https://img.shields.io/github/stars/Cord1ess/Open-Campus?style=social)](https://github.com/Cord1ess/Open-Campus/stargazers)

<br />

[**Live Web App**](https://cord1ess.github.io/Open-Campus/) &nbsp;|&nbsp;
[**Report a Bug**](https://github.com/Cord1ess/Open-Campus/issues) &nbsp;|&nbsp;
[**Request a Feature**](https://github.com/Cord1ess/Open-Campus/issues)

</div>

---

## Table of Contents

- [About](#about)
- [Why Open Campus](#why-open-campus)
- [Privacy First](#privacy-first)
- [Features](#features)
- [How It Works](#how-it-works)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Repository Layout](#repository-layout)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Testing](#testing)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Disclaimer](#disclaimer)
- [License](#license)

---

## About

**Open Campus** is an independent, unofficial companion app for **UCAM**, the
student portal of United International University (UIU). UCAM is a server-driven
ASP.NET Web Forms site with no public API, so it is functional but slow to
navigate on a phone. Open Campus wraps it in a clean, fast, modern interface that
runs on **Android and the web**, built entirely with Flutter.

You sign in with **your own** UCAM ID and password and see **only your own**
academic data, exactly what you can already see when you log into UCAM yourself.
There is no separate account to create and no third party in the middle who keeps
a copy of your records.

> The single most important design decision: **the server stores nothing.** No
> database, no student records, no saved passwords. Everything is fetched live
> from your own UCAM session and forgotten the moment it is shown to you.

---

## Why Open Campus

| The problem | The Open Campus answer |
|-------------|------------------------|
| UCAM has no mobile app and is slow to navigate on a phone | A native-feeling Flutter app for Android and web |
| Raw data with no insight (just numbers on a page) | Charts, trends, GPA projections, attendance risk, tuition and installment breakdowns |
| Third-party "portal" apps often hoard credentials and data | Stateless by design: password discarded after login, nothing stored server side |
| Closed-source tools you have to trust blindly | Fully open source, MIT licensed, auditable end to end |

---

## Privacy First

Open Campus is built so that there is, quite literally, **nothing to leak**.

| Guarantee | How it is enforced |
|-----------|--------------------|
| Your password is never stored | It is used once to log into UCAM, then discarded. Only the short-lived UCAM session cookie is held in memory while you are active. |
| No database, no student records | The backend is stateless. There is no persistence layer of any kind for user data. |
| Everything is live | Each screen is fetched fresh from your own UCAM session and forgotten after it is returned. |
| You see only your own data | UCAM authorizes every request by your own session. The backend never trusts a client-supplied identity, it reads your ID from the authenticated page itself. |
| On-device cache, cleared on logout | The app keeps your last view on your own device only, so it launches instantly. Logging out wipes it. |
| Good-citizen behaviour toward UCAM | Humane request pacing and per-IP login rate limiting, so the proxy never floods the university's servers. |

A transparency endpoint (`GET /transparency`) states, in plain language, exactly
what the server does and does not keep, and the app surfaces it to you in the UI.

---

## Features

**Academics**

- Semester GPA and running CGPA, with an interactive trend chart
- Per-course attendance with an at-risk indicator and the exact UIU deduction rules
- Item-wise course marks (assessment breakdown per course)
- Full course history: every course, grade, credit and per-trimester GPA
- Weekly class routine with a live "next class" countdown and calendar (.ics) export
- Exam schedules, academic calendar, and paginated UIU notices

**Finance**

- Live balance and dues with a clear amount-owed hero
- Installment plan (the official UIU 40 / 70 / 100 threshold plan) with deadline countdown
- Full payment history, organized by trimester

**Tools**

- GPA calculator and target-CGPA planner (what you need next trimester to hit a goal)
- Tuition fee estimator with waivers, scholarships and retake rules

**Experience**

- Material 3 Expressive design, light / dark / AMOLED themes, custom accent colors
- Instant launch via on-device caching, smooth 120Hz-friendly rendering
- Responsive layouts for phone and desktop web
- On-device reminders for calendar events and installment deadlines

---

## How It Works

```
  You open the app
        |
        v
  Instantly renders your last view from the on-device cache
  (so launch is never a blank screen)
        |
        v
  In the background, calls the Open Campus backend
        |
        v
  Backend uses your live UCAM session to fetch data
  (or replies "session expired" so the app can prompt a gentle re-login)
        |
        v
  UCAM pages and JSON endpoints are normalized into clean JSON
        |
        v
  App updates the UI and refreshes the on-device cache
        |
        v
  Server forgets everything. Nothing is persisted.
```

The brittle coupling to UCAM's markup lives entirely in one backend module, so if
the university changes its portal, it is a single backend redeploy and installed
apps keep working off cache in the meantime.

---

## Architecture

```
  Flutter app  --- HTTPS / JSON --->  Open Campus backend  --- live fetch --->  UCAM
 (Android / web)                     (FastAPI, stateless,                     (UIU portal)
   |                                  logs in, normalizes,
   |                                  returns JSON, stores nothing)
   +-- caches the last view on YOUR device only (cleared on logout)
```

- **Stateless proxy.** The backend logs into UCAM on your behalf, holds only the
  in-memory session cookie while you are active, and returns clean JSON. It keeps
  no database and no copy of your data.
- **Own-credentials, own-data.** Your trusted identity (roll) is read from the
  authenticated UCAM landing page, never from client input, so you can only ever
  see your own records.
- **Session model.** The app holds a short-lived signed token; if the upstream
  UCAM session expires, data routes return `409` so the app shows a soft
  "tap to re-login" prompt instead of a hard logout.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter, Dart, Riverpod, dio, fl_chart |
| Design | Material 3 Expressive, custom design system, spring physics |
| Backend | Python, FastAPI, httpx, selectolax |
| Auth | Signed app token (JWT), in-memory UCAM session, no password storage |
| Storage | None server side. On-device cache via shared_preferences; token in secure storage |
| Web renderer | WebAssembly (skwasm) with a dart2js / CanvasKit fallback |
| Hosting | GitHub Pages (web), Docker-portable backend (free tier or a small VPS) |
| CI/CD | GitHub Actions (test gate, web deploy, backend keep-alive) |

---

## Repository Layout

```
Open-Campus/
├── app/          Flutter client (Android + responsive web)
│   ├── lib/
│   │   ├── core/         API client, auth, cache, theme, notifications, domain math
│   │   ├── features/     dashboard, academics, finance, services, profile, ...
│   │   └── shared/       design-system widgets (cards, charts, avatar, ...)
│   └── test/     unit and model tests
├── backend/      FastAPI proxy (stateless, no database)
│   ├── app/
│   │   ├── api/          auth, student, calendar, transparency routes
│   │   ├── auth/         session store, rate limiting, dependencies
│   │   ├── ucam/         UCAM login + page/endpoint parsers (the brittle coupling)
│   │   └── schemas/      Pydantic response models
│   └── tests/    offline parsing, security-guard, and status-mapping tests
├── tools/        beta_check.py (pre-release scan for personal data / secrets)
└── .github/      CI workflows (test, deploy-web, keepalive)
```

---

## Getting Started

### Backend

```bash
cd backend
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements-dev.txt   # Windows
# source .venv/bin/activate && pip install -r requirements-dev.txt   # macOS / Linux

cp .env.example .env        # then set OC_SESSION_SECRET (see Configuration)
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000/docs` for the interactive API. The backend is
Docker-ready and honors `$PORT`, so it deploys to Render, Fly, or any container
host unchanged. See [backend/README.md](backend/README.md) for the Render blueprint.

### App

```bash
cd app
flutter pub get

# Run against the hosted backend (default), or add --dart-define=OC_LOCAL=true
# to point at a local uvicorn instance.
flutter run

# Build the web app
flutter build web --release --dart-define=OC_API_BASE=https://<your-host>

# Build an Android APK
flutter build apk --release --dart-define=OC_API_BASE=https://<your-host>
```

Run `python tools/beta_check.py` before any distributable build. It fails if any
personal data, `.env`, or capture directory is present in the tree.

---

## Configuration

Backend settings are environment driven (prefix `OC_`). Copy `.env.example` to
`.env` and never commit the real file.

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `OC_SESSION_SECRET` | Yes (prod) | dev placeholder | Signs the app token. Generate with `python -c "import secrets; print(secrets.token_urlsafe(48))"`. The server refuses to start in non-debug mode with the placeholder. |
| `OC_SESSION_TTL_MINUTES` | No | `60` | App token lifetime. |
| `OC_PER_USER_MIN_INTERVAL_SECONDS` | No | `1.0` | Minimum spacing between a session's UCAM requests. |
| `OC_TRUST_FORWARDED_FOR` | No | `false` | Trust `X-Forwarded-For` only behind a proxy that overwrites it. |
| `OC_CORS_ORIGINS` | Web only | `[]` | JSON list of allowed web origins. Never `"*"`. |
| `OC_DEBUG` | No | `false` | Local dev only. Bypasses the production-safety gate. |

The app resolves its backend URL in this order: `--dart-define=OC_API_BASE`, then
`--dart-define=OC_LOCAL=true` (local dev), then the hosted default.

---

## Testing

```bash
# Backend (offline, no live UCAM needed)
cd backend && python -m pytest

# App (static analysis + unit/model tests)
cd app && flutter analyze && flutter test
```

Parsing tests use the exact JSON and HTML shapes captured from UCAM, so they
double as a regression guard if the portal's format ever changes. Security-guard
tests lock down the SSRF host-pinning, injection guards, session-expiry mapping,
and rate limiting. Both suites run in CI on every push and pull request, and the
web deploy is gated on them passing.

---

## Roadmap

- [x] Live results, attendance, CGPA, bills, notices, course history
- [x] Class routine with countdown and calendar export
- [x] GPA and tuition calculators with projections
- [x] Web build on GitHub Pages, Android APK
- [x] Stateless backend with on-device caching
- [ ] iOS build (App Store)
- [ ] Opt-in push notifications (v2)
- [ ] Item-wise marks fixtures and broader widget/integration test coverage

---

## Contributing

Contributions are welcome. The recommended flow:

1. Open an issue describing the change or bug.
2. Fork the repo and create a feature branch.
3. Keep the backend stateless and the privacy guarantees intact.
4. Ensure `flutter analyze`, `flutter test`, and `pytest` all pass.
5. Open a pull request.

The UCAM coupling is intentionally isolated in `backend/app/ucam/`, so most portal
changes are a localized fix there.

---

## Disclaimer

Open Campus is an independent, unofficial, open-source project. It is **not
affiliated with, endorsed by, or connected to** United International University
(UIU) or Edusoft Consultants Ltd., the vendor of UCAM. All related marks belong to
their respective owners.

The app accesses only the data a student can already see in their own UCAM
account, using that student's own credentials. It uses no UIU or Edusoft branding
or assets.

---

## License

Released under the [MIT License](LICENSE). The disclaimer above applies
regardless of license.

<div align="center">
<br />
Built for students, by students. If Open Campus helps you, consider giving it a star.
</div>

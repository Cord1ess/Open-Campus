# Open Campus — Beta Build & Release Checklist

This is the procedure for producing a build to hand to **other testers**. The
goal: **zero of your personal data**, no secrets, and a build that can actually
reach a hosted backend (not your localhost).

> Run `python tools/beta_check.py` before every build. It fails the build if any
> personal data, `.env`, or capture directory is present.

---

## 0. One-time: host the backend

Testers' devices cannot reach your `localhost`. You need the backend running on a
reachable host over **HTTPS**.

- Deploy `backend/` (it's Dockerfile-ready) to any host (free tier is fine).
- Set production env (NOT a committed `.env`):
  - `OC_SESSION_SECRET` = a fresh 48-byte secret
    (`python -c "import secrets; print(secrets.token_urlsafe(48))"`)
  - `OC_DEBUG=false`  ← keeps the `/test` dev dashboard OFF and enables the
    production-safety gate
  - `OC_CORS_ORIGINS=["https://<where-the-web-app-is-served>"]` (web build only)
- Confirm `GET https://<host>/health` returns `{"status":"ok"}` over HTTPS.

The server is stateless — no database, nothing stored. The UCAM password is used
once per login and discarded.

---

## 1. Scrub personal data (must pass)

```
python tools/beta_check.py
```

If it fails, remove what it lists. Expected items on a dev machine:

- `backend/.env`           → delete (move it aside; it holds your real secret)
- `backend/captures/`      → delete (your real academic data: grades, bill, advisor)
- `docs/captures/`         → delete if present
- any `*.har`              → delete (captured traffic = cookies + PII)

The source tree, tests, and docs are already clear of real IDs. The checker also
verifies `backend/.env.example` ships with `OC_DEBUG=false`.

---

## 2. Build the WEB app (the shippable beta target)

Only the `web` platform is currently scaffolded, so web is the beta target.

```
cd app
flutter build web --release --dart-define=OC_API_BASE=https://<your-host>
```

- The `--dart-define` is **required**. A release build with no backend URL shows
  a clear "this build has no backend configured" message on the login screen
  instead of failing silently.
- Output: `app/build/web/` → serve from any static host (Cloudflare Pages,
  GitHub Pages, Netlify). Make sure that origin is in `OC_CORS_ORIGINS`.

Smoke test before sharing:
- Open the served URL, log in with a **test account** (not your own),
- confirm dashboard, academics, finance, services load,
- confirm logout returns to the login screen.

---

## 3. (Optional) Build an ANDROID APK

The Android platform isn't generated yet. One-time:

```
cd app
flutter create --platforms=android .
```

Then review the generated `android/app/src/main/AndroidManifest.xml`:
- App label → "Open Campus"
- `applicationId` → a real package id (e.g. `com.yourname.opencampus`)
- INTERNET permission is added automatically; nothing else is needed.
- Since the backend is **HTTPS**, you do NOT need `usesCleartextTraffic`.

Build:

```
flutter build apk --release --dart-define=OC_API_BASE=https://<your-host>
```

Output: `app/build/app/outputs/flutter-apk/app-release.apk` → share directly.

---

## 4. Final pre-share checklist

- [ ] `python tools/beta_check.py` passes
- [ ] Backend is live on HTTPS; `/health` OK; `OC_DEBUG=false`
- [ ] `OC_SESSION_SECRET` is a fresh value (rotate if it was ever printed/shared)
- [ ] App built with `--dart-define=OC_API_BASE=https://<host>`
- [ ] Logged in with a **test** account, not your own, and verified each tab
- [ ] Disclaimer ("unofficial, not affiliated with UIU/Edusoft") visible on login
- [ ] No `backend/.env`, no `captures/`, no `*.har` in the tree you built from

---

## Notes / known beta scope
- Faculty schedules + academic calendar show **placeholder demo data** (clearly
  fake) until live feeds are wired — by design.
- Login rate limiting: 8 attempts / 5 min per IP (brute-force guard).
- Single-process backend only (sessions are in-memory). For multiple workers,
  move `session_store` + `rate_limit` to Redis.

# Open Campus

An open-source, unofficial companion app for United International University's
(UIU) student portal, **UCAM**. It gives students a modern, fast way to view
**their own** university data — results, CGPA, attendance, bills, notices, course
history, and more — using **their own** UCAM credentials.

> **Disclaimer.** Open Campus is an independent, community project. It is **not
> affiliated with, endorsed by, or connected to** UIU or Edusoft Consultants Ltd.
> (the vendor of UCAM). All related marks belong to their respective owners. The
> app accesses only the data a student can already see in their own UCAM account,
> using that student's own credentials. We comply promptly with any takedown
> request from UIU or Edusoft.

## How it works

UCAM is a server-driven ASP.NET Web Forms portal with no public API. Open Campus
puts a thin, **stateless** backend in front of it that turns UCAM's pages into
clean JSON for the app.

```
  Flutter app  ──HTTPS/JSON──▶  Open Campus backend  ──live fetch──▶  UCAM
 (Android / web)               (stateless: log in, normalize,
   │                            return JSON, store nothing)
   └─ caches the last view on YOUR device only (cleared on logout)
```

- You log in with **your own** UCAM ID and password.
- The backend logs into UCAM on your behalf and holds only the short-lived UCAM
  session cookie **in memory** while you use the app. **Your password is never
  stored.**
- **The server stores nothing.** No database, no student records. Every screen is
  fetched live and forgotten.
- The app keeps your last view on your **own device** so it loads instantly; that
  copy is cleared on logout.

## Repository layout

```
backend/   FastAPI proxy: UCAM login + live JSON API (stateless, no DB)
app/       Flutter client (web today; Android next)
docs/      Technical notes (UCAM recon, endpoint map, information architecture)
tools/     beta_check.py — pre-release scan for personal data / secrets
```

## Privacy & security

- You can only ever see your own data — UCAM authorizes by your own session.
- The password is discarded immediately after login; only the session cookie is
  held in memory, only for the lifetime of your session.
- The server stores no student data, so there is nothing to leak.
- Per-user request pacing toward UCAM; per-IP login rate limiting.

## Running it

- **Backend:** see [backend/README.md](backend/README.md) (local run + Render deploy).
- **App:** see [BETA.md](BETA.md) for building the web app / Android APK against a
  hosted backend.

## License

MIT (see `LICENSE`). The disclaimer above applies regardless of license.

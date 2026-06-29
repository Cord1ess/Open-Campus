# UCAM Recon — Independently Verified Findings

> Source: direct HTTP inspection of https://ucam.uiu.ac.bd on 2026-06-27.
> Every fact below was observed from the live server, not assumed.

## Server stack (confirmed via response headers)
- `Server: Microsoft-IIS/10.0`
- `X-AspNet-Version: 4.0.30319`
- `X-Powered-By: ASP.NET`
- ASP.NET **Web Forms** (not MVC, not Web API). Confirmed by `.aspx` pages,
  `__VIEWSTATE`, `__VIEWSTATEGENERATOR`, `WebForm_DoPostBackWithOptions`,
  `ScriptResource.axd`, and `Sys.Application` (MicrosoftAjax / ASP.NET AJAX).
- Uses the **ASP.NET AJAX UpdatePanel** model (`Sys.Extended.UI`,
  `UpdatePanelAnimationBehavior`). So "AJAX" requests are WebForms async
  postbacks (`__ASYNCPOST`), returning the pipe-delimited UpdatePanel format —
  OR custom `[WebMethod]` / PageMethods returning HTML fragments. To be
  confirmed once we see authenticated traffic.

## Cookies (confirmed)
- `ASP.NET_SessionId` — `HttpOnly; SameSite=Lax`, set on first GET. Session id.
- `browserFingerprint=deviceBrowserId=<GUID>` — set on the login page GET,
  expires in ~10 years (2036). NOT HttpOnly (JS-readable). Server assigns the
  GUID; client just stores/echoes it. So it is a **device-tracking cookie**,
  not a challenge we must compute. We persist and replay it per device.
- `.ASPXAUTH` — Forms Authentication ticket. NOT yet observed (only appears
  after a successful login). Expected based on the stack.

## Login form (confirmed — exact field names)
- Page: `https://ucam.uiu.ac.bd/Security/LogIn.aspx`
- `<form name="frmLogIn" method="post" action="./LogIn.aspx" id="frmLogIn">`
- Fields to POST:
  - `logMain$UserName`  (text)  — student ID
  - `logMain$Password`  (password)
  - `logMain$Button1`   = `LOG IN` (submit button name/value)
  - `__VIEWSTATE`       (hidden, required, changes every GET)
  - `__VIEWSTATEGENERATOR` (hidden, e.g. `A0A15FC2`)
  - `__VIEWSTATEENCRYPTED` (hidden, empty)
  - `__PREVIOUSPAGE`    (hidden)
  - `__EVENTTARGET` / `__EVENTVALIDATION` — not present on this page snapshot;
    `__EVENTVALIDATION` may appear (EnableEventValidation). Capture dynamically.
- There is a "remember me" checkbox `checkbox-fill-1` (not wired to a server name
  in the obvious way — verify whether it matters).
- **No CSRF token beyond ViewState.** ViewState is the de-facto anti-tamper /
  request-validation mechanism here. `__VIEWSTATEENCRYPTED` is empty, so
  ViewState is signed (MAC) but not encrypted.

## Login mechanics (the critical insight)
Because this is WebForms, **you cannot just POST username+password to a clean
endpoint.** The correct flow is:
1. `GET /Security/LogIn.aspx` — receive `ASP.NET_SessionId`, `browserFingerprint`,
   and scrape `__VIEWSTATE` / `__VIEWSTATEGENERATOR` / `__PREVIOUSPAGE`
   (and `__EVENTVALIDATION` if present) from the returned HTML.
2. `POST /Security/LogIn.aspx` with those hidden fields **plus** the credentials,
   carrying the same cookies.
3. On success: server sets `.ASPXAUTH` and 302-redirects to the dashboard
   (e.g. `StudentHome.aspx`). On failure: re-renders the login page with an
   error label.
This is exactly how a real browser does it; we replicate it server-side.

## Other observed facts
- Google Analytics (UA-62803724-1) on the login page. Irrelevant to us; do not load.
- Static assets under `/Content/assets/` (bootstrap, vendor-all.min.js).
- The root `/` is a meta-refresh + JS redirect to `Security/LogIn.aspx`.
- A Parental Portal exists: `/ParentalPortal/GuardianLogIn.aspx`.
- Cloud variant: `ucamcloud.uiu.ac.bd`. eLMS: `elms.uiu.ac.bd`. Separate systems.

---

# UPDATE — Verified from authenticated HAR (2026-06-28)

A sanitized dashboard HAR (`ucam-dashboard.har`, 29 requests) confirmed the
authenticated flow. Findings (structure only; no personal data recorded here):

## Login is an ASP.NET AJAX ASYNC postback (refinement)
The login POST to `/Security/Login.aspx` is a **partial (UpdatePanel) postback**,
not a plain full-page POST. Observed request fields:
- `scMgtMas` (the ScriptManager field; value = `<panel>|<button>` target)
- `__EVENTTARGET`, `__EVENTARGUMENT`
- `__VIEWSTATE`, `__VIEWSTATEGENERATOR`, `__VIEWSTATEENCRYPTED`, `__PREVIOUSPAGE`
- `logMain$UserName`, `logMain$Password`, `logMain$Button1`
- `__ASYNCPOST` = `true`
- Header `Content-Type: application/x-www-form-urlencoded; charset=UTF-8`
- Response `Content-Type: text/plain` (the pipe-delimited async-postback format).
  On success the async response instructs a client-side redirect to
  `StudentHome.aspx`; `StudentHome.aspx` is then fetched via GET
  (referer = Login.aspx). **No captcha, no encrypted ViewState, no extra challenge.**
- So our client must include the async fields (`scMgtMas`, `__ASYNCPOST`,
  `__EVENTTARGET`/`__EVENTARGUMENT`) — a small addition to the drafted flow.

## Dashboard data = CLEAN JSON via ASP.NET PageMethods (major win)
No HTML scraping needed for dashboard data. Endpoints are PageMethods on the page
URL, called with `POST`, `Content-Type: application/json`, `X-Requested-With:
XMLHttpRequest`, and an ASP.NET `{"d": ...}` response envelope:

| Endpoint (POST) | Request body | Response shape |
|---|---|---|
| `/Security/StudentHome.aspx/GetStudentResultSummary` | `{roll:'<id>'}` | `{"d":[{AcademicCalenderID,Year,TypeName,GPA,TranscriptCGPA}, ...]}` — per-semester GPA + running CGPA |
| `/Security/StudentHome.aspx/GetStudentAttendanceSummary` | `{roll:'<id>'}` | `{"d":[{StudentID,FormalCode,Title,SectionName,AbsentCount,PresentCount,TotalClassHeld,RemainClass}, ...]}` |
| `/Security/StudentHome.aspx/GetNotice` | `{program:'<n>',roll:'<id>'}` | `{"d": "<html-or-empty>"}` — notices (was empty in capture) |

Notes:
- The `roll` parameter = the student ID. We get it from the logged-in session
  (e.g. from StudentHome.aspx) — do NOT trust a client-supplied roll.
- The `__type` values are `ParentalPortal.ViewModels.*` — these summary methods are
  shared with the Parental/Guardian portal. Stable and simple.
- Page URL carried an `?mmi=<hex>` token in the Referer; check whether deeper
  endpoints require it.
- Auth to these endpoints is via the session cookies (`.ASPXAUTH`,
  `ASP.NET_SessionId`); the sanitized HAR stripped cookie values but they are sent.

## Still to capture (other sections)
Profile, full transcript / detailed results, course history, current registration,
advising, financials/payments. These may be JSON PageMethods or HTML pages — TBD
per capture. See `docs/CAPTURE.md`.

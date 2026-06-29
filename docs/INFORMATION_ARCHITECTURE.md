# Open Campus — Information Architecture

Goal: take UCAM's 34 scattered, deeply-nested features and reorganize them into a
flat, modern app. Principle: **surface what students check daily; group the rest
logically; bury nothing more than 2 taps deep.**

## Navigation: 4 floating-nav tabs

```
┌─────────┬───────────┬──────────┬──────────┐
│  Home   │ Academics │ Finance  │ Services │
└─────────┴───────────┴──────────┴──────────┘
```

(Profile/settings move to a top-right avatar on every tab, not a nav slot — frees
the 4th slot for Services. Logout lives under the avatar.)

---

### 🏠 Home — the daily glance (mostly wired already)
The at-a-glance dashboard. No navigation needed for the 90% case.
- Greeting + quick stats (CGPA · Attendance % · current Semester) ✅
- **This-week routine** snippet (next classes) — *needs Class Routine data*
- Results summary card (CGPA trend) ✅
- Attendance card (at-risk courses first) ✅
- **Dues/balance** chip if money is owed — *needs Bill data*
- Latest notice ✅
- Tapping any card → its full Academics/Finance page (shared-axis transition)

### 🎓 Academics — everything about studying
- **Results** (per-semester + transcript) ✅ wired / *transcript needs data*
- **Attendance** (per course) ✅ wired
- **Course History** — all courses, grades, credits — *needs data*
- **Class Routine** — weekly timetable + exam schedule — *needs data*
- **Degree Progress** — credits done/remaining, CGPA toward graduation — *needs data*
- **Registration** (grouped sub-page):
  - Pre-Advising (+ retake), Self-Registration
  - Course Open / Withdraw / Credit-Limit requests
  - FYP Group Submission

### 💳 Finance — money in one place
- **Balance & Dues** — outstanding, due dates — *needs Bill data*
- **Payment History** — ledger of transactions — *needs Bill data*
- **Pay Now** — link out to UCAM's payment flow (we don't handle payments)
- **Invoices / Fee structure** — *needs data*

### 🛠️ Services — requests, forms, the occasional stuff
- **Exam Office (COE)** — apply for Transcript / Duplicate Transcript / Certificates,
  + Application Status — *needs data*
- **Support Tickets** — view/raise tickets — *needs GetTickets data*
- **Surveys & Evaluations** — course evaluation, transport survey, IQAC/OBE forms
- **Other** — Gym enrollment, Change password (links to UCAM where we shouldn't
  reimplement sensitive flows)

---

## Profile (avatar menu, top-right)
- Student profile (name, ID, program, photo) — *needs Profile data*
- Privacy statement (we store nothing) ✅
- Theme (light/dark later)
- Log out ✅

---

## Status legend used in the app
Each feature shows one of:
- **Live** — wired to UCAM, real data ✅
- **Coming soon** — designed, needs a response-body capture to wire (tap shows a
  friendly "capture this section to enable" note for now)
- **Opens in UCAM** — sensitive/rare flows we intentionally link out rather than
  reimplement (payments, password change).

## Motion principles (applies everywhere)
- Every tappable surface: ripple + spring press-scale.
- List rows: staggered spring entrance.
- Card → detail: **shared-axis / container transform** transition.
- Tab switch: shared-axis horizontal.
- Numbers (CGPA, %, balance): count-up animation.
- Loading: shimmer skeletons, never bare spinners.
- Pull-to-refresh, swipe-back, FAB where an action exists.

## Build order
1. Restructure nav to Home/Academics/Finance/Services + avatar menu.
2. Motion layer (animated button, list item, transitions) — reusable.
3. Academics & Services & Finance hub pages with feature rows (Live vs Coming-soon).
4. Wire real data per section as captures arrive.

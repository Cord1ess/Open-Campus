# UCAM Endpoint Map (from ucam-dashboard 2.har, 1249 requests, 2026-06-29)

> ⚠️ This HAR was exported **without response bodies** (sanitized export strips
> them). The URL/param map below is complete and usable; but to build PARSERS we
> need the response shapes — see "Re-capture" at the bottom.

## Feature pages discovered (34 distinct .aspx)

### Core student data (high priority)
| Page | How data loads | What it holds |
|---|---|---|
| `/Security/StudentHome.aspx` | JSON PageMethods | dashboard: results/attendance/notices (already wired) |
| `/Student/StudentCourseHistory.aspx` | async postback → HTML | full course history, grades, credits |
| `/Student/Report/RptStudentClassRoutine.aspx` | async postback → HTML | class routine / timetable |
| `/Student/RptDegreeVerification.aspx` | async postback → HTML | degree progress / verification |
| `/Registration/RegistrationHome.aspx` | (page) | registration hub |
| `/Registration/PreAdvising.aspx`, `PreAdvisingRetake.aspx` | (page) | advising |
| `/Registration/SelfRegistrationByStudent.aspx` | (page) | self registration |
| `/Registration/CourseWithdrawRequestStudent.aspx` | (page) | course withdraw |
| `/Registration/CourseOpenRequestStudent.aspx` | (page) | course open request |
| `/Registration/CreditLimitIncreaseRequest.aspx` | (page) | credit limit request |

### Financials
| `/Bill/BillHome.aspx`, `/Bill/StudentGeneralBillV2.aspx` | async postback + PageMethod | bills, payment, gateway status |

### COE (Controller of Exams) — applications
| `/COE/COEHome.aspx`, `StudentApplicationStatus.aspx`, `TranscriptApply.aspx`,
`DuplicateTranscriptApply.aspx`, `CertificatesApply.aspx` | apply for transcripts/certs |

### Services / other
| `/Communication/SupportTicket.aspx` | PageMethod `GetTickets` | support tickets |
| `/Student/FYPGroupSubmission.aspx` | PageMethod `ValidateStudent` | final-year project group |
| `/Student/TransportSurvey.aspx`, `/SurveyForm/SFStudent.aspx` | surveys |
| `/Employee/EvaluationForm.aspx` | course/teacher evaluation |
| `/IQAC/IQACHome.aspx`, `/OBE/OBEHome.aspx` | IQAC / OBE |
| `/Admin/PasswordChangeByUser.aspx` | change password |
| `/Admin/GymEnrollmentAdmin.aspx` | gym enrollment |

## Confirmed request shapes (params known; responses NOT captured)
- `StudentHome.aspx/GetStudentResultSummary`  body `{roll:'<id>'}`  ✅ wired
- `StudentHome.aspx/GetStudentAttendanceSummary` body `{roll:'<id>'}` ✅ wired
- `StudentHome.aspx/GetNotice` body `{program:'<n>',roll:'<id>'}`     ✅ wired
- `Communication/SupportTicket.aspx/GetTickets` body `{}`
- `Bill/StudentGeneralBillV2.aspx/GetPaymentGatewayStatus` body `{}`
- `Student/FYPGroupSubmission.aspx/ValidateStudent` body `{studentId, slotIndex, selectedCourseId}`

## Navigation token: `mmi=<hex>`
Every feature page is reached with a `?mmi=<hex>` token in the URL (e.g.
`StudentHome.aspx?mmi=41485d2c6c554d494e63`). This is a per-page nav token UCAM
generates in the menu links. To fetch a deeper page server-side we must **scrape
the menu** from a logged-in page to get that page's current `mmi`, not hardcode it
(tokens look session/encoded). PageMethods on a page also want the page's
`?mmi=...` URL as Referer.

## Buildable-now vs needs-response-bodies
- **Buildable now (params known, shape known from 1st HAR):** results, attendance,
  notices — already wired.
- **Params known, response shape UNKNOWN (need bodies):** SupportTicket/GetTickets,
  Bill/GetPaymentGatewayStatus, everything HTML (course history, routine, degree
  verification, registration, COE, bills).
- **Plan:** map the nav + mmi-token mechanism, design the IA, stub the screens;
  fill parsers as response-body captures arrive.

## Re-capture needed (to get response shapes for parsers)
The next HAR must include **response bodies**. In Chrome:
1. DevTools → Settings (gear) → **Network** → check **"Allow to generate HAR with
   sensitive data"** (this enables full bodies).
2. Then export via right-click → **"Save all as HAR (with sensitive data)"**
   (NOT the "sanitized" option — that strips bodies).
3. We can re-sanitize locally with `tools/sanitize_har.py` (keeps bodies, masks ID).

Priority pages to re-capture with bodies: Course History, Class Routine, Degree
Verification, Bill/BillHome, Registration pages.

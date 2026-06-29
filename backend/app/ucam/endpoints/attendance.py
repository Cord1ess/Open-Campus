"""GetStudentAttendanceSummary — per-course attendance (clean JSON).

Verified PageMethod: POST /Security/StudentHome.aspx/GetStudentAttendanceSummary
Body: {"roll": "<id>"}  →  {"d": [ {FormalCode, Title, SectionName, AbsentCount,
PresentCount, TotalClassHeld, RemainClass}, ... ]}
"""
from __future__ import annotations

from app.schemas.student import CourseAttendance
from app.ucam.client import UcamSession, call_page_method

METHOD = "GetStudentAttendanceSummary"


async def fetch_attendance(session: UcamSession) -> list[dict]:
    """Return the raw `d` array (JSON-serializable) for caching; parse at route."""
    rows = await call_page_method(session, METHOD, {"roll": session.roll})
    return rows if isinstance(rows, list) else []


def parse_attendance(rows: object) -> list[CourseAttendance]:
    if not isinstance(rows, list):
        return []
    return [CourseAttendance.model_validate(r) for r in rows]

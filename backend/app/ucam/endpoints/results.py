"""GetStudentResultSummary — per-semester GPA + running CGPA (clean JSON).

Verified PageMethod: POST /Security/StudentHome.aspx/GetStudentResultSummary
Body: {"roll": "<id>"}  →  {"d": [ {AcademicCalenderID, Year, TypeName, GPA,
TranscriptCGPA}, ... ]}
"""
from __future__ import annotations

from app.schemas.student import SemesterResult
from app.ucam.client import UcamSession, call_page_method

METHOD = "GetStudentResultSummary"


async def fetch_results(session: UcamSession) -> list[dict]:
    """Return the raw `d` array. Parse into models at the route layer with
    parse_results() (split out so it's unit-testable offline)."""
    rows = await call_page_method(session, METHOD, {"roll": session.roll})
    return rows if isinstance(rows, list) else []


def parse_results(rows: object) -> list[SemesterResult]:
    """Parse a `d` array (raw dicts) into SemesterResult models (offline-testable)."""
    if not isinstance(rows, list):
        return []
    return [SemesterResult.model_validate(r) for r in rows]

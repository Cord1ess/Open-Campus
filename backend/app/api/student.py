"""Student data routes: results, attendance, notices.

STATELESS: every response is fetched live from the student's own UCAM session.
The backend stores nothing. (The Flutter app may cache the last view on the
user's own device for instant launch — that's client-side only.)

If the UCAM session has expired, we return 409 (Conflict) so the app shows the
gentle "tap to re-login for latest" prompt rather than a hard 401 logout.
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Response, status

from app.auth.deps import CurrentSession
from app.schemas.student import (
    AdvisingResponse,
    AttendanceResponse,
    BillResponse,
    CourseHistoryResponse,
    ExamRoutineResponse,
    HomeSummary,
    MarksResponse,
    NoticesResponse,
    ResultsResponse,
)
from app.ucam.client import UcamError, UcamSessionExpired
from app.ucam.endpoints import advising as advising_ep
from app.ucam.endpoints import attendance as attendance_ep
from app.ucam.endpoints import bill as bill_ep
from app.ucam.endpoints import course_history as history_ep
from app.ucam.endpoints import exam_routine as exam_ep
from app.ucam.endpoints import home as home_ep
from app.ucam.endpoints import marks as marks_ep
from app.ucam.endpoints import notices as notices_ep
from app.ucam.endpoints import results as results_ep

import httpx

router = APIRouter(prefix="/student", tags=["student"])
log = logging.getLogger("open_campus.student")


def _handle_failure(exc: Exception) -> HTTPException:
    if isinstance(exc, UcamSessionExpired):
        return HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="UCAM session expired. Please re-login.",
        )
    # Log internal detail server-side; return a generic message to the client.
    log.warning("UCAM data fetch error: %s", exc)
    return HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail="Couldn't reach the university portal. Please try again.",
    )


@router.get("/avatar")
async def get_avatar(session: CurrentSession) -> Response:
    """Proxy the student's UCAM profile photo through the backend.

    The image lives behind the UCAM session (cookies) and on a different origin,
    so the app/browser can't fetch it directly (auth + CORS). We fetch it with
    the live session and stream the bytes back. Nothing is stored.
    """
    # The photo path is discovered from the home page; re-derive it live.
    try:
        html = await home_ep.fetch_home_html(session)
        summary = home_ep.parse_home(html, fallback_roll=session.roll)
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)

    if not summary.photo_url:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="No profile photo.")
    try:
        async with session.pacing():
            img = await session.client.get(summary.photo_url)
        img.raise_for_status()
    except httpx.HTTPError as exc:
        raise _handle_failure(exc)

    ctype = img.headers.get("content-type", "image/jpeg")
    # Let the app cache the avatar briefly; it rarely changes.
    return Response(
        content=img.content,
        media_type=ctype,
        headers={"Cache-Control": "private, max-age=3600"},
    )


@router.get("/home", response_model=HomeSummary, response_model_by_alias=False)
async def get_home(session: CurrentSession) -> HomeSummary:
    """Identity + current/next term + quick stats + advisor + class routine,
    parsed from the server-rendered StudentHome.aspx page in one fetch."""
    try:
        html = await home_ep.fetch_home_html(session)
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)
    return home_ep.parse_home(html, fallback_roll=session.roll)


@router.get("/course-history", response_model=CourseHistoryResponse,
            response_model_by_alias=False)
async def get_course_history(session: CurrentSession) -> CourseHistoryResponse:
    """Full course history + per-trimester GPA, parsed from
    StudentCourseHistory.aspx."""
    try:
        html = await history_ep.fetch_history_html(session)
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)
    return history_ep.parse_course_history(html)


@router.get("/bill", response_model=BillResponse, response_model_by_alias=False)
async def get_bill(session: CurrentSession) -> BillResponse:
    """Itemized bill, parsed from StudentGeneralBillV2.aspx. The authoritative
    current balance comes from the home page (the bill grid's running sums don't
    reconcile to the live balance), so we fill it from there."""
    try:
        bill_html = await bill_ep.fetch_bill_html(session)
        home_html = await home_ep.fetch_home_html(session)
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)
    bill = bill_ep.parse_bill(bill_html)
    home = home_ep.parse_home(home_html, fallback_roll=session.roll)
    bill.balance = home.current_balance
    return bill


@router.get("/advising", response_model=AdvisingResponse,
            response_model_by_alias=False)
async def get_advising(session: CurrentSession) -> AdvisingResponse:
    """Courses offered for next-term registration + courses already taken,
    parsed from PreAdvising.aspx."""
    try:
        html = await advising_ep.fetch_advising_html(session)
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)
    return advising_ep.parse_advising(html)


@router.get("/marks/trimesters", response_model_by_alias=False)
async def get_mark_trimesters(session: CurrentSession) -> list[dict]:
    """List the trimesters that have an item-wise marks view, for the app to
    offer as a picker. Returns [{value, label}]."""
    try:
        opts = await marks_ep.fetch_trimester_options(session)
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)
    return [{"value": v, "label": label} for v, label in opts]


@router.get("/marks", response_model=MarksResponse, response_model_by_alias=False)
async def get_marks(session: CurrentSession, trimester: str) -> MarksResponse:
    """Item-wise marks for ONE trimester (its value from /marks/trimesters).
    Drives the cascading course dropdown, reading each course's mark panel."""
    try:
        courses = await marks_ep.fetch_marks_for_trimester(session, trimester)
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)
    return MarksResponse(courses=courses)


@router.get("/exam-routine", response_model=ExamRoutineResponse,
            response_model_by_alias=False)
async def get_exam_routine(session: CurrentSession) -> ExamRoutineResponse:
    """Published exam-routine links (Google Sheets) by program."""
    try:
        html = await exam_ep.fetch_exam_html(session)
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)
    return exam_ep.parse_exam_routine(html)


@router.get("/results", response_model=ResultsResponse, response_model_by_alias=False)
async def get_results(session: CurrentSession) -> ResultsResponse:
    try:
        rows = await results_ep.fetch_results(session)
    except (UcamSessionExpired, UcamError) as exc:
        raise _handle_failure(exc)
    semesters = results_ep.parse_results(rows)
    latest_cgpa = semesters[0].cgpa if semesters else None
    return ResultsResponse(semesters=semesters, latest_cgpa=latest_cgpa)


@router.get("/attendance", response_model=AttendanceResponse, response_model_by_alias=False)
async def get_attendance(session: CurrentSession) -> AttendanceResponse:
    try:
        rows = await attendance_ep.fetch_attendance(session)
    except (UcamSessionExpired, UcamError) as exc:
        raise _handle_failure(exc)
    return AttendanceResponse(courses=attendance_ep.parse_attendance(rows))


@router.get("/notices", response_model=NoticesResponse,
            response_model_by_alias=False)
async def get_notices(session: CurrentSession) -> NoticesResponse:
    # The notice PageMethod needs the student's program id (from the home page).
    try:
        home_html = await home_ep.fetch_home_html(session)
        program = home_ep.parse_home(home_html, fallback_roll=session.roll).program_id
        notices = await notices_ep.fetch_notices(
            session, program=str(program) if program is not None else "1"
        )
    except (UcamSessionExpired, UcamError, httpx.HTTPError) as exc:
        raise _handle_failure(exc)
    return NoticesResponse(notices=notices)

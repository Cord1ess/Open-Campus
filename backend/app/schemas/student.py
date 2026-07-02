"""Pydantic response models for student data.

Field shapes mirror exactly what UCAM's PageMethods return (verified from HAR),
but renamed to clean, app-friendly names. The raw UCAM keys are mapped via alias.

The backend is stateless — every response is live, so there's no freshness/sync
metadata here. The Flutter app handles its own on-device last-view cache.
"""
from __future__ import annotations

from pydantic import BaseModel, Field


class SemesterResult(BaseModel):
    """One row of GetStudentResultSummary."""

    academic_calendar_id: int = Field(alias="AcademicCalenderID")
    year: int = Field(alias="Year")
    semester: str = Field(alias="TypeName")          # e.g. "Fall", "Spring"
    gpa: float = Field(alias="GPA")
    cgpa: float = Field(alias="TranscriptCGPA")      # running cumulative CGPA

    model_config = {"populate_by_name": True}


class CourseAttendance(BaseModel):
    """One row of GetStudentAttendanceSummary."""

    course_code: str = Field(alias="FormalCode")     # e.g. "CSE 3411"
    title: str = Field(alias="Title")
    section: str = Field(alias="SectionName")
    absent: int = Field(alias="AbsentCount")
    present: int = Field(alias="PresentCount")
    total_held: int = Field(alias="TotalClassHeld")
    remaining: int = Field(alias="RemainClass")

    @property
    def attendance_pct(self) -> float:
        return round(100 * self.present / self.total_held, 1) if self.total_held else 0.0

    model_config = {"populate_by_name": True}


# --- Envelopes returned to the app (all data is live) ---

class ResultsResponse(BaseModel):
    semesters: list[SemesterResult]
    latest_cgpa: float | None = None


class AttendanceResponse(BaseModel):
    courses: list[CourseAttendance]


class Notice(BaseModel):
    """One notice from GetNotice (d is a JSON string of these)."""

    notice_id: str | None = Field(default=None, alias="NoticeId")
    title: str | None = Field(default=None, alias="NoticeTitle")
    description: str | None = Field(default=None, alias="NoticeDescription")
    type: str | None = Field(default=None, alias="Type")
    program: str | None = Field(default=None, alias="Program")
    posted_by: str | None = Field(default=None, alias="PostedBy")
    posted_date: str | None = Field(default=None, alias="PostedDate")
    file_path: str | None = Field(default=None, alias="FilePath")

    model_config = {"populate_by_name": True, "extra": "ignore"}


class NoticesResponse(BaseModel):
    notices: list[Notice] = []


# --- Home summary (parsed from StudentHome.aspx HTML, server-rendered) ---

class Term(BaseModel):
    """A semester/trimester reference, e.g. code=261, name='Spring 2026'."""

    code: str | None = None
    name: str | None = None


class Advisor(BaseModel):
    name: str | None = None
    initial: str | None = None
    room: str | None = None
    email: str | None = None
    phone: str | None = None


class ClassSession(BaseModel):
    """One entry from the server-rendered weekly class routine table."""

    day: str
    course_code: str
    section: str | None = None
    start: str | None = None      # e.g. "08:30 AM"
    end: str | None = None        # e.g. "09:50 AM"


class HomeSummary(BaseModel):
    """Everything the home page needs, parsed from StudentHome.aspx in one shot:
    identity, current/next term, quick academic + financial stats, advisor, and
    today's/this-week's class routine."""

    name: str | None = None
    roll: str | None = None
    photo_url: str | None = None
    program_id: int | None = None
    # Personal bio (server-rendered on StudentHome).
    dob: str | None = None
    blood_group: str | None = None
    phone: str | None = None
    father_name: str | None = None
    mother_name: str | None = None
    current_term: Term | None = None
    next_terms: list[Term] = []
    cgpa: float | None = None
    completed_credits: float | None = None
    current_balance: float | None = None     # negative => advance (no due)
    total_billed: float | None = None
    total_paid: float | None = None
    total_waived: float | None = None
    advisor: Advisor | None = None
    routine: list[ClassSession] = []


# --- Course history (parsed from StudentCourseHistory.aspx) ---

class HistoryCourse(BaseModel):
    trimester: str | None = None      # e.g. "233"
    course_code: str | None = None    # e.g. "CSE 2213"
    course_name: str | None = None
    credit: float | None = None
    grade: str | None = None          # None while running
    point: float | None = None
    is_running: bool = False


class TrimesterGpa(BaseModel):
    trimester: str | None = None
    credit: float | None = None
    gpa: float | None = None
    cgpa: float | None = None


class CourseHistoryResponse(BaseModel):
    program: str | None = None
    batch: str | None = None
    cgpa: float | None = None
    degree_requirement: float | None = None
    completed_credits: float | None = None
    attempted_credits: float | None = None
    waived_credits: float | None = None
    probation: str | None = None
    courses: list[HistoryCourse] = []
    trimester_gpas: list[TrimesterGpa] = []


# --- Bill (parsed from StudentGeneralBillV2.aspx) ---

class BillItem(BaseModel):
    fee_type: str | None = None       # "Tuition Fee", "Student Payment", ...
    course_code: str | None = None
    credit: float | None = None
    amount: float | None = None       # charged
    discount: float | None = None
    payment: float | None = None      # received
    trimester: str | None = None
    date: str | None = None           # raw "25-Feb-26"
    remark: str | None = None


class PaymentMethod(BaseModel):
    """An online-payment method UCAM accepts (display only; the app deep-links to
    UCAM's own payment page rather than handling money)."""

    code: str                          # "bk", "vs", "ms", "nx", "mx"
    name: str                          # "bKash", "Visa", ...


class BillResponse(BaseModel):
    total_billed: float | None = None
    total_discount: float | None = None
    total_paid: float | None = None
    balance: float | None = None      # >0 due, <0 advance
    items: list[BillItem] = []
    payment_methods: list[PaymentMethod] = []


# --- Pre-advising (parsed from PreAdvising.aspx) ---

class OfferedCourse(BaseModel):
    code: str | None = None
    title: str | None = None
    credit: float | None = None
    group: str | None = None
    offered_trimester: str | None = None   # e.g. "7th"
    mandatory: bool = False


class AdvisingResponse(BaseModel):
    # Courses available to register for next term, and courses already taken.
    offered: list[OfferedCourse] = []
    taken: list[OfferedCourse] = []


# --- Item-wise marks (parsed from ItemWiseDetailsMarksForStudent.aspx) ---

class MarkComponent(BaseModel):
    name: str                       # e.g. "Attendance", "Class Tests", "Mid-term Exam"
    obtained: float | None = None
    max: float | None = None


class CourseMarks(BaseModel):
    course: str | None = None       # e.g. "CSE 2217: Data Structure..."
    trimester: str | None = None
    total_class: int | None = None
    present: int | None = None
    components: list[MarkComponent] = []
    total_obtained: float | None = None
    total_max: float | None = None

    @property
    def has_marks(self) -> bool:
        return bool(self.components) or self.total_obtained is not None


class MarksResponse(BaseModel):
    courses: list[CourseMarks] = []


# --- Exam routine (links to published Google-Sheet routines, by program) ---

class ExamRoutineLink(BaseModel):
    label: str                      # e.g. "Exam Routine BSCSE, BSDS Summer 2026"
    url: str                        # the published Google-Sheet URL


class ExamRoutineResponse(BaseModel):
    routines: list[ExamRoutineLink] = []


# --- Academic calendar (public UIU page; shared, cached, not per-student) ---

class CalendarEvent(BaseModel):
    date_text: str                  # raw, e.g. "Jul 4 - 6, 2026"
    day: str                        # e.g. "Sat-Mon"
    event: str
    start_date: str | None = None   # ISO yyyy-mm-dd
    end_date: str | None = None     # ISO


class AcademicCalendar(BaseModel):
    title: str
    term: str                       # e.g. "Spring 2026"
    program: str                    # e.g. "Undergraduate"
    revised: bool = False
    events: list[CalendarEvent] = []


class AcademicCalendarResponse(BaseModel):
    calendars: list[AcademicCalendar] = []
    fetched_at: str | None = None   # ISO timestamp of the server-side fetch


class NoticeItem(BaseModel):
    title: str
    url: str
    date_text: str | None = None


class NoticesResponse(BaseModel):
    notices: list[NoticeItem] = []
    page: int = 1
    total_pages: int = 1
    fetched_at: str | None = None

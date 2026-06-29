"""Offline parsing tests using the exact JSON shapes captured from UCAM (HAR,
2026-06-28). No live network — these guard against parser regressions and act as
documentation of the upstream format.
"""
from __future__ import annotations

from app.ucam.endpoints.attendance import parse_attendance
from app.ucam.endpoints.results import parse_results

# Real shapes from GetStudentResultSummary (values anonymized but structure exact).
RESULTS_D = [
    {"__type": "ParentalPortal.ViewModels.StudentResultSummary",
     "AcademicCalenderID": 113, "Year": 2025, "TypeName": "Fall",
     "GPA": 3.85, "TranscriptCGPA": 3.29},
    {"__type": "ParentalPortal.ViewModels.StudentResultSummary",
     "AcademicCalenderID": 112, "Year": 2025, "TypeName": "Summer",
     "GPA": 2.54, "TranscriptCGPA": 3.18},
]

ATTENDANCE_D = [
    {"__type": "ParentalPortal.ViewModels.StudentAttendanceSummary",
     "StudentID": 50000, "FormalCode": "CSE 3411",
     "Title": "System Analysis and Design", "SectionName": "A",
     "AbsentCount": 3, "PresentCount": 21, "TotalClassHeld": 24, "RemainClass": 0},
    {"__type": "ParentalPortal.ViewModels.StudentAttendanceSummary",
     "StudentID": 50000, "FormalCode": "MATH 2205",
     "Title": "Probability and Statistics", "SectionName": "O",
     "AbsentCount": 0, "PresentCount": 24, "TotalClassHeld": 24, "RemainClass": 0},
]


def test_parse_results_maps_fields():
    out = parse_results(RESULTS_D)
    assert len(out) == 2
    fall = out[0]
    assert fall.year == 2025
    assert fall.semester == "Fall"
    assert fall.gpa == 3.85
    assert fall.cgpa == 3.29  # TranscriptCGPA -> cgpa


def test_parse_results_handles_empty():
    assert parse_results([]) == []
    assert parse_results(None) == []  # defensive


def test_parse_attendance_maps_and_computes_pct():
    out = parse_attendance(ATTENDANCE_D)
    assert len(out) == 2
    cse = out[0]
    assert cse.course_code == "CSE 3411"
    assert cse.present == 21 and cse.total_held == 24
    assert cse.attendance_pct == 87.5  # 21/24
    perfect = out[1]
    assert perfect.attendance_pct == 100.0


def test_parse_attendance_zero_classes_no_divzero():
    rows = [{"FormalCode": "X 100", "Title": "T", "SectionName": "A",
             "AbsentCount": 0, "PresentCount": 0, "TotalClassHeld": 0, "RemainClass": 0}]
    assert parse_attendance(rows)[0].attendance_pct == 0.0

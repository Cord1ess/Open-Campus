"""StudentCourseHistory.aspx — full course history + per-trimester GPA.

Server-rendered tables (verified element ids):
  Summary spans: ctl00_MainContainer_lblStudentProgram / lblStudentBatch / lblCGPA
    / lblDegreeReq / lblCompletedCr / lblAttemptedCr / lblWaivedTransferCr / lblProbation
  Courses: table ctl00_MainContainer_gvRegisteredCourse — 7 positional columns:
    Trimester | Course ID | Course Name | Credit | Grade | Point | Course Status
  Per-trimester GPA: table ctl00_MainContainer_gvResult — 7 columns:
    Trimester | Credit(Prob) | TermGPA(Prob) | CGPA(Prob) | Credit(Tx) | GPA(Tx) | CGPA(Tx)
"""
from __future__ import annotations

import re

from selectolax.parser import HTMLParser

from app.schemas.student import (
    CourseHistoryResponse,
    HistoryCourse,
    TrimesterGpa,
)
from app.ucam.client import UcamSession
from app.ucam.navigator import fetch_page

_MC = "ctl00_MainContainer_"
_PATH = "/Student/StudentCourseHistory.aspx"


async def fetch_history_html(session: UcamSession) -> str:
    # Must use the live mmi-tokenized URL; a bare GET returns an empty shell.
    return await fetch_page(session, _PATH)


def _text(tree: HTMLParser, node_id: str) -> str | None:
    node = tree.css_first(f"#{node_id}")
    if node is None:
        return None
    return node.text(strip=True) or None


def _f(s: str | None) -> float | None:
    if not s:
        return None
    m = re.search(r"-?\d[\d,]*(?:\.\d+)?", s)
    return float(m.group(0).replace(",", "")) if m else None


def _rows(tree: HTMLParser, table_id: str) -> list[list[str]]:
    """Return each data row of a GridView as a list of cell texts (header skipped)."""
    table = tree.css_first(f"#{table_id}")
    if table is None:
        return []
    out: list[list[str]] = []
    for tr in table.css("tr"):
        cells = tr.css("td")
        if not cells:  # header row uses <th>
            continue
        out.append([c.text(strip=True) for c in cells])
    return out


def parse_course_history(html: str) -> CourseHistoryResponse:
    tree = HTMLParser(html)

    courses: list[HistoryCourse] = []
    for r in _rows(tree, f"{_MC}gvRegisteredCourse"):
        if len(r) < 7:
            continue
        status = r[6].strip()
        running = "running" in status.lower()
        courses.append(
            HistoryCourse(
                trimester=r[0] or None,
                course_code=r[1] or None,
                course_name=r[2] or None,
                credit=_f(r[3]),
                grade=(r[4] or None) if not running else None,
                point=_f(r[5]) if not running else None,
                is_running=running,
            )
        )

    gpas: list[TrimesterGpa] = []
    for r in _rows(tree, f"{_MC}gvResult"):
        if len(r) < 7:
            continue
        # Use the transcript columns (4,5,6) — the official GPA/CGPA.
        gpas.append(
            TrimesterGpa(
                trimester=r[0] or None,
                credit=_f(r[4]),
                gpa=_f(r[5]),
                cgpa=_f(r[6]),
            )
        )

    return CourseHistoryResponse(
        program=_text(tree, f"{_MC}lblStudentProgram"),
        batch=_text(tree, f"{_MC}lblStudentBatch"),
        cgpa=_f(_text(tree, f"{_MC}lblCGPA")),
        degree_requirement=_f(_text(tree, f"{_MC}lblDegreeReq")),
        completed_credits=_f(_text(tree, f"{_MC}lblCompletedCr")),
        attempted_credits=_f(_text(tree, f"{_MC}lblAttemptedCr")),
        waived_credits=_f(_text(tree, f"{_MC}lblWaivedTransferCr")),
        probation=_text(tree, f"{_MC}lblProbation"),
        courses=courses,
        trimester_gpas=gpas,
    )

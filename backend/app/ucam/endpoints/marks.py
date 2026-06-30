"""ItemWiseDetailsMarksForStudent.aspx — per-course assessment breakdown.

This page is CASCADING: pick a trimester (ddlAcaCalBatch) which repopulates the
course list (ddlCourse); selecting a course renders the marks into a panel via
postback. So the live endpoint walks: for each trimester -> for each course ->
read the marks panel.

The panel is a HEADER-DRIVEN table that varies per course:
  row 0 (header): Total Class | Present | Attendance(5.00) | Class Tests(20.00) |
                  Assignment(5.00) | Mid-term Exam(30.00) | Out of (60.00)
  row 1 (optional header): Class Tests-1(20.00) | ... | Best 2 (Two)
  last row (values): aligns to the headers, with the class-test breakdown values
                     inserted where "Class Tests" sits.

We parse it defensively: read each main component's label + max from the header,
then map obtained values positionally. Component names/counts differ per course,
so nothing is hard-coded beyond "Total Class"/"Present"/"Out of".
"""
from __future__ import annotations

import logging
import re

import httpx
from selectolax.parser import HTMLParser

from app.schemas.student import CourseMarks, MarkComponent
from app.ucam.client import UcamError, UcamSession, UcamSessionExpired
from app.ucam.navigator import fetch_page, resolve_page_url
from app.ucam.postback import postback, select_options

log = logging.getLogger("open_campus.marks")

_PANEL = "ctl00_MainContainer_pnStudentMarkDisEntryView"
_PATH = "/Result/ItemWiseDetailsMarksForStudent.aspx"
_DDL_TRIMESTER = "ctl00$MainContainer$ddlAcaCalBatch"
_DDL_COURSE = "ctl00$MainContainer$ddlCourse"

# Precompiled (these run once per mark component per course — hundreds per load).
_NUM_RE = re.compile(r"-?\d+(?:\.\d+)?")
_LABEL_MAX_RE = re.compile(r"\s*(.*?)\s*\(\s*([\d.]+)\s*\)\s*$")


async def fetch_trimester_options(session: UcamSession) -> list[tuple[str, str]]:
    """Load the marks page and return [(value, label)] of available trimesters."""
    html = await fetch_page(session, _PATH)
    return select_options(html, _DDL_TRIMESTER)


async def fetch_marks_for_trimester(
    session: UcamSession, trimester_value: str
) -> list[CourseMarks]:
    """Drive the cascade for ONE trimester: select it (postback) to populate the
    course list, then select each course (postback) to read its marks panel.

    This is N+1 UCAM postbacks, so the result is cached on the session for its
    lifetime — re-opening the same trimester returns instantly."""
    cached = session._marks_cache.get(trimester_value)
    if cached is not None:
        return cached  # type: ignore[return-value]

    page_url = (await resolve_page_url(session, _PATH)) or _PATH
    base_html = await fetch_page(session, _PATH)

    # Select the trimester -> repopulates the course dropdown.
    after_term = await postback(
        session, page_url, base_html,
        event_target=_DDL_TRIMESTER, control_name=_DDL_TRIMESTER,
        value=trimester_value,
    )
    courses = select_options(after_term, _DDL_COURSE)

    results: list[CourseMarks] = []
    html = after_term
    for value, label in courses:
        try:
            html = await postback(
                session, page_url, html,
                event_target=_DDL_COURSE, control_name=_DDL_COURSE,
                value=value,
            )
        except (UcamError, UcamSessionExpired, httpx.HTTPError) as exc:
            # One course failing shouldn't sink the whole trimester — skip it,
            # but log so a systemic break is visible rather than silent.
            log.warning("marks: course %r postback failed: %s", label, exc)
            continue
        cm = parse_course_marks(html, course_label=label)
        if cm.has_marks:
            results.append(cm)

    session._marks_cache[trimester_value] = results
    return results


def _num(s: str | None) -> float | None:
    if not s:
        return None
    m = _NUM_RE.search(s)
    return float(m.group(0)) if m else None


def _split_label_max(text: str) -> tuple[str, float | None]:
    """'Attendance(5.00)' -> ('Attendance', 5.0). 'Best 2 (Two)' -> ('Best 2', None)."""
    m = _LABEL_MAX_RE.match(text)
    if m:
        return m.group(1).strip(), float(m.group(2))
    return text.strip(), None


def parse_course_marks(html: str, *, course_label: str | None = None,
                       trimester: str | None = None) -> CourseMarks:
    """Parse one rendered marks panel into a CourseMarks. Returns an empty
    CourseMarks (no components) if the course has no marks entered yet."""
    tree = HTMLParser(html)

    # Course name: prefer the selected option text of the course dropdown.
    course_name = course_label
    sel = tree.css_first("#ctl00_MainContainer_ddlCourse")
    if sel is not None:
        for opt in sel.css("option"):
            if opt.attributes.get("selected") is not None:
                course_name = opt.text(strip=True) or course_name
                break

    panel = tree.css_first(f"#{_PANEL}")
    if panel is None:
        return CourseMarks(course=course_name, trimester=trimester, components=[])

    rows: list[list[str]] = []
    for tr in panel.css("tr"):
        cells = [c.text(strip=True) for c in tr.css("td, th")]
        cells = [c for c in cells if c != ""]
        if cells:
            rows.append(cells)
    if len(rows) < 2:
        return CourseMarks(course=course_name, trimester=trimester, components=[])

    header = rows[0]
    values = rows[-1]  # values are the last row

    total_class = present = None
    final_obtained = final_max = None
    components: list[MarkComponent] = []

    # Walk the header; the values row has the SAME leading layout for the simple
    # columns (Total Class, Present, each component, Out of). The class-test
    # breakdown values (when a 2nd header row exists) are appended after the main
    # values — we read main components by index from the header, which is reliable.
    for i, htext in enumerate(header):
        label, mx = _split_label_max(htext)
        val = _num(values[i]) if i < len(values) else None
        low = label.lower()
        if low.startswith("total class"):
            total_class = int(val) if val is not None else None
        elif low == "present":
            present = int(val) if val is not None else None
        elif low.startswith("out of"):
            final_obtained = _num(values[-1])  # final total is the LAST value
            final_max = mx
        else:
            components.append(
                MarkComponent(name=label, obtained=val, max=mx)
            )

    return CourseMarks(
        course=course_name,
        trimester=trimester,
        total_class=total_class,
        present=present,
        components=components,
        total_obtained=final_obtained,
        total_max=final_max,
    )

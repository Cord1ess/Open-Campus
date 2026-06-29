"""StudentHome.aspx — the authenticated dashboard, parsed from server-rendered HTML.

Unlike results/attendance (JSON PageMethods), the home page renders the student's
identity, current/next term, quick stats, advisor, and weekly class routine
directly into the page HTML. We fetch that page and parse it with selectolax.

Element ids were verified against a real capture (see memory: ucam-data-map):
  ctl00_MainContainer_SI_Name / Label1 / SI_Image / Status_CGPA / Status_CompletedCr
  ctl00_MainContainer_FI_CurrentBalance / FI_TotalBilled / FI_TotalPaid / FI_TotalWaved
  ctl00_MainContainer_lblAdvisor{Name,Initial,Room,Email,Phone}
  ctl00_lblCurrent / ctl00_lblRegistration   (term labels)
  ctl00_MainContainer_Class_Schedule         (routine table)
"""
from __future__ import annotations

import re
from urllib.parse import urljoin

from selectolax.parser import HTMLParser

from app.config import settings
from app.schemas.student import (
    Advisor,
    ClassSession,
    HomeSummary,
    Term,
)
from app.ucam.client import UcamSession

_MC = "ctl00_MainContainer_"  # MainContainer id prefix


async def fetch_home_html(session: UcamSession) -> str:
    """Fetch the authenticated StudentHome page HTML (live)."""
    url = session.landing_url or urljoin(
        settings.ucam_base_url, settings.ucam_home_path
    )
    async with session.pacing():
        resp = await session.client.get(url)
    resp.raise_for_status()
    return resp.text


# --- parsing helpers (pure; offline-testable) ---

def _text(tree: HTMLParser, node_id: str) -> str | None:
    node = tree.css_first(f"#{node_id}")
    if node is None:
        return None
    txt = node.text(strip=True)
    return txt or None


def _money(tree: HTMLParser, node_id: str) -> float | None:
    """Parse a '455653 Tk.' / '-25 Tk.' style figure into a float."""
    raw = _text(tree, node_id)
    if not raw:
        return None
    m = re.search(r"-?\d[\d,]*(?:\.\d+)?", raw)
    return float(m.group(0).replace(",", "")) if m else None


def _float(tree: HTMLParser, node_id: str) -> float | None:
    raw = _text(tree, node_id)
    if not raw:
        return None
    m = re.search(r"-?\d[\d,]*(?:\.\d+)?", raw)
    return float(m.group(0).replace(",", "")) if m else None


def _parse_terms(label: str | None) -> list[Term]:
    """Parse a 'semesterStatus' label like
        '261 - Spring 2026 (Semester), 261 - Spring 2026 (Trimester)'
        '262 - Summer 2026 (Trimester), 263 - Fall 2026 (Semester)'
    into a de-duplicated list of Term(code, name). Pieces share a code+name pair;
    we collapse the (Semester)/(Trimester) duplicates into one term per code."""
    if not label:
        return []
    terms: dict[str, Term] = {}
    for piece in label.split(","):
        piece = piece.strip()
        if not piece:
            continue
        # Preferred shape: "<code> - <name> (<kind>)".
        m = re.match(r"(\d+)\s*-\s*(.+?)\s*(?:\(([^)]*)\))?$", piece)
        if m:
            code, name = m.group(1), m.group(2).strip()
            terms.setdefault(code, Term(code=code, name=name))
            continue
        # Fallback: a label with no numeric code (other departments may format
        # differently). Strip any trailing "(kind)" and key by the name so the
        # term still shows up rather than being dropped.
        name = re.sub(r"\s*\([^)]*\)\s*$", "", piece).strip()
        if name and name not in terms:
            terms[name] = Term(code=None, name=name)
    return list(terms.values())


# Day names that head each section of the routine table.
_DAYS = {"Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"}


def _parse_routine(tree: HTMLParser) -> list[ClassSession]:
    """Parse the server-rendered Class_Schedule table.

    Structure (verified): rows are either a day header (a single cell naming a
    weekday) or a class row whose cells read like 'CSE 3411 (A)' and
    '08:30 AM-09:50 AM'. We track the current day as we walk the rows.
    """
    table = tree.css_first(f"#{_MC}Class_Schedule")
    if table is None:
        return []
    sessions: list[ClassSession] = []
    current_day: str | None = None
    for row in table.css("tr"):
        cells = [c.text(strip=True) for c in row.css("td")]
        cells = [c for c in cells if c]
        if not cells:
            continue
        # A day-header row is just the weekday name.
        if len(cells) == 1 and cells[0] in _DAYS:
            current_day = cells[0]
            continue
        # Otherwise look for a "CODE (SECTION)" + "start-end" pair anywhere in row.
        course = section = start = end = None
        for c in cells:
            cm = re.match(r"^([A-Z]{2,4}\s*\d{3,4})\s*\(([^)]*)\)$", c)
            if cm:
                course, section = cm.group(1).strip(), cm.group(2).strip()
                continue
            tm = re.match(r"^(\d{1,2}:\d{2}\s*[AP]M)\s*-\s*(\d{1,2}:\d{2}\s*[AP]M)$", c)
            if tm:
                start, end = tm.group(1), tm.group(2)
        if course and current_day:
            sessions.append(
                ClassSession(
                    day=current_day,
                    course_code=course,
                    section=section,
                    start=start,
                    end=end,
                )
            )
    return sessions


def parse_home(html: str, *, fallback_roll: str | None = None) -> HomeSummary:
    """Parse StudentHome.aspx HTML into a HomeSummary (pure / offline-testable)."""
    tree = HTMLParser(html)

    # Photo is a relative path on the page; make it absolute for the app.
    photo_url = None
    img = tree.css_first(f"#{_MC}SI_Image")
    if img is not None:
        src = img.attributes.get("src")
        if src:
            photo_url = urljoin(settings.ucam_base_url, src)

    program_id = None
    hdn = tree.css_first(f"#{_MC}hdnProgramId")
    if hdn is not None:
        val = hdn.attributes.get("value")
        if val and val.isdigit():
            program_id = int(val)

    next_terms = _parse_terms(_text(tree, "ctl00_lblRegistration"))
    current_terms = _parse_terms(_text(tree, "ctl00_lblCurrent"))

    advisor = Advisor(
        name=_text(tree, f"{_MC}lblAdvisorName"),
        initial=_text(tree, f"{_MC}lblAdvisorInitial"),
        room=_text(tree, f"{_MC}lblAdvisorRoom"),
        email=_text(tree, f"{_MC}lblAdvisorEmail"),
        phone=_text(tree, f"{_MC}lblAdvisorPhone"),
    )
    # Only attach advisor if at least the name resolved.
    advisor_out = advisor if advisor.name else None

    return HomeSummary(
        name=_text(tree, f"{_MC}SI_Name"),
        roll=_text(tree, f"{_MC}Label1") or fallback_roll,
        photo_url=photo_url,
        program_id=program_id,
        dob=_text(tree, f"{_MC}SI_DOB"),
        blood_group=_text(tree, f"{_MC}SI_BloodGroup"),
        phone=_text(tree, f"{_MC}SI_Phone"),
        father_name=_text(tree, f"{_MC}SI_FatherName"),
        mother_name=_text(tree, f"{_MC}SI_MotherName"),
        current_term=current_terms[0] if current_terms else None,
        next_terms=next_terms,
        cgpa=_float(tree, f"{_MC}Status_CGPA"),
        completed_credits=_float(tree, f"{_MC}Status_CompletedCr"),
        current_balance=_money(tree, f"{_MC}FI_CurrentBalance"),
        total_billed=_money(tree, f"{_MC}FI_TotalBilled"),
        total_paid=_money(tree, f"{_MC}FI_TotalPaid"),
        total_waived=_money(tree, f"{_MC}FI_TotalWaved"),
        advisor=advisor_out,
        routine=_parse_routine(tree),
    )

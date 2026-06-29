"""PreAdvising.aspx — courses offered for next-term registration + taken courses.

Two server-rendered grids:
  ctl00_MainContainer_gvCoursePreRegistration — columns:
    SL | Code | Title | Credits | Group | Offered trimester | Mandatory | Action
  ctl00_MainContainer_gvTakenCourse — columns:
    SL | Code | Title | Credits | Grade | Group | Offered trimester
"""
from __future__ import annotations

import re

from selectolax.parser import HTMLParser

from app.schemas.student import AdvisingResponse, OfferedCourse
from app.ucam.client import UcamSession
from app.ucam.navigator import fetch_page

_MC = "ctl00_MainContainer_"
_PATH = "/Registration/PreAdvising.aspx"


async def fetch_advising_html(session: UcamSession) -> str:
    return await fetch_page(session, _PATH)


def _f(s: str | None) -> float | None:
    if not s:
        return None
    m = re.search(r"-?\d[\d,]*(?:\.\d+)?", s)
    return float(m.group(0).replace(",", "")) if m else None


def _grid_rows(tree: HTMLParser, table_id: str) -> list[list[str]]:
    table = tree.css_first(f"#{table_id}")
    if table is None:
        return []
    out = []
    for tr in table.css("tr"):
        cells = tr.css("td")
        if cells:
            out.append([c.text(strip=True) for c in cells])
    return out


def parse_advising(html: str) -> AdvisingResponse:
    tree = HTMLParser(html)

    offered = []
    for r in _grid_rows(tree, f"{_MC}gvCoursePreRegistration"):
        if len(r) < 7:
            continue
        offered.append(
            OfferedCourse(
                code=r[1] or None,
                title=r[2] or None,
                credit=_f(r[3]),
                group=(r[4] or None) if r[4] not in ("--", "") else None,
                offered_trimester=r[5] or None,
                mandatory=bool(r[6] and r[6].strip()),
            )
        )

    taken = []
    for r in _grid_rows(tree, f"{_MC}gvTakenCourse"):
        if len(r) < 7:
            continue
        taken.append(
            OfferedCourse(
                code=r[1] or None,
                title=r[2] or None,
                credit=_f(r[3]),
                group=(r[5] or None) if r[5] not in ("--", "") else None,
                offered_trimester=r[6] or None,
            )
        )

    return AdvisingResponse(offered=offered, taken=taken)

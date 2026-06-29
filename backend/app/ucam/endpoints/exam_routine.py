"""ExamRoutineViewer.aspx — links to published exam routines.

UIU publishes exam routines as public Google Sheets (one per program/department),
embedded as iframes on this page with a heading label each. This is NOT
per-student data; we just surface the {label, url} pairs so the app can let the
student open their program's routine.
"""
from __future__ import annotations

import re
from urllib.parse import urljoin

from selectolax.parser import HTMLParser

from app.config import settings
from app.schemas.student import ExamRoutineLink, ExamRoutineResponse
from app.ucam.client import UcamSession

_PATH = "/Student/ExamRoutineViewer.aspx"
# Published Google-Sheet embed URL.
_SHEET_RE = re.compile(r"docs\.google\.com/spreadsheets/", re.IGNORECASE)


async def fetch_exam_html(session: UcamSession) -> str:
    # This page is linked without an mmi token; a direct GET works.
    url = urljoin(settings.ucam_base_url, _PATH)
    async with session.pacing():
        resp = await session.client.get(
            url, headers={"Referer": session.landing_url or settings.ucam_base_url}
        )
    resp.raise_for_status()
    return resp.text


def parse_exam_routine(html: str) -> ExamRoutineResponse:
    """Each routine is a label (text/heading) immediately followed by an iframe to
    a published Google Sheet. We split the raw HTML on iframes and take the text
    just before each as its label — this matches UIU's actual markup, where the
    program label sits right before its embed."""
    routines: list[ExamRoutineLink] = []
    seen: set[str] = set()

    # Drop <script>/<style> blocks so their JS text can't leak into labels.
    html = re.sub(r"<script\b.*?</script>", " ", html, flags=re.IGNORECASE | re.S)
    html = re.sub(r"<style\b.*?</style>", " ", html, flags=re.IGNORECASE | re.S)

    # Find each iframe's start, its src, and the text since the PREVIOUS iframe —
    # that text contains this routine's label (UIU lists label then its embed).
    iframes = list(re.finditer(r"<iframe\b[^>]*>", html, re.IGNORECASE))
    prev_end = 0
    for it in iframes:
        tag = it.group(0)
        src_m = re.search(r'\bsrc="([^"]+)"', tag)
        if not src_m:
            prev_end = it.end()
            continue
        src = src_m.group(1)
        if not _SHEET_RE.search(src) or src in seen:
            prev_end = it.end()
            continue
        seen.add(src)
        between = html[prev_end:it.start()]
        between = re.sub(r"<[^>]+>", " ", between)
        between = between.replace("&amp;", "&")
        between = re.sub(r"\s+", " ", between).strip()
        # Take the meaningful tail (drop any trailing JS/analytics noise).
        # Keep from the last occurrence of a routine keyword onward if present.
        m2 = re.search(r"(Tentative|Revised|Exam[_ ]?Routine|Exam Template)",
                       between, re.IGNORECASE)
        label = between[m2.start():] if m2 else between
        label = label[:120].strip()
        routines.append(
            ExamRoutineLink(label=label or "Exam Routine", url=src)
        )
        prev_end = it.end()

    return ExamRoutineResponse(routines=routines)

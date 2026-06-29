"""Academic calendar scraper.

UIU publishes its academic calendars as plain HTML tables on a PUBLIC page
(no login): https://www.uiu.ac.bd/academics/calendar/. Each calendar is a
``<table>`` of Date | Day | Event rows, preceded by a title like
"Spring 2026 Trimester Undergraduate Programs [Revised]". The downloadable PDF
is a scanned image (would need OCR), so we parse the HTML table instead — it's
clean, structured, and always current.

This data is public and identical for everyone, so — unlike student data — it's
safe to fetch once and cache server-side with a TTL (see the router). When UIU
posts a new calendar after a trimester, the next refresh picks it up
automatically.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

import httpx
from selectolax.parser import HTMLParser

CALENDAR_URL = "https://www.uiu.ac.bd/academics/calendar/"

# A calendar title: term + year + program. Tolerant of an optional "[Revised]"
# suffix and whatever program word UIU uses (Undergraduate/Graduate/Pharmacy…).
_TITLE_RE = re.compile(
    r"((?:Spring|Summer|Fall|Autumn|Winter)\s*20\d\d\s*Trimester\s+"
    r"[A-Za-z][A-Za-z &/]*?Programs?(?:\s*\[[^\]]+\])?)",
    re.IGNORECASE,
)

_MONTHS = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}

# Date patterns, precompiled (run per event row).
_DIGIT_RE = re.compile(r"\d")
_RE_CROSS_MONTH = re.compile(
    r"([A-Za-z]{3,})\s+(\d{1,2}),?\s*(\d{4})?\s*[-–]\s*"
    r"([A-Za-z]{3,})\s+(\d{1,2}),?\s*(\d{4})"
)
_RE_SAME_MONTH = re.compile(
    r"([A-Za-z]{3,})\s+(\d{1,2})\s*[-–]\s*(\d{1,2}),?\s*(\d{4})"
)
_RE_SINGLE = re.compile(r"([A-Za-z]{3,})\s+(\d{1,2}),?\s*(\d{4})")
_RE_WS = re.compile(r"\s+")


@dataclass
class CalEvent:
    date_text: str            # raw, e.g. "Jul 4 - 6, 2026"
    day: str                  # e.g. "Sat-Mon"
    event: str
    start_date: str | None = None   # ISO yyyy-mm-dd (best effort)
    end_date: str | None = None     # ISO; equals start for single-day


@dataclass
class Calendar:
    title: str
    term: str                 # e.g. "Spring 2026"
    program: str              # e.g. "Undergraduate"
    revised: bool = False
    events: list[CalEvent] = field(default_factory=list)


def _iso(year: int, month: int, day: int) -> str | None:
    try:
        return f"{year:04d}-{month:02d}-{day:02d}"
    except Exception:
        return None


def _parse_dates(text: str) -> tuple[str | None, str | None]:
    """Parse UIU date strings into ISO start/end. Handles:
      "Jul 6, 2026"            -> single day
      "Jul 4 - 6, 2026"        -> range within a month
      "Feb 23 - 25, 2026"      -> range within a month
      "Dec 29, 2025 - Jan 2, 2026" -> cross-month range (best effort)
    Returns (start, end); end == start for a single day. (None, None) on failure.
    """
    t = _RE_WS.sub(" ", text).strip()
    # Cross-month: "Mon DD, YYYY - Mon DD, YYYY"
    m = _RE_CROSS_MONTH.match(t)
    if m:
        m1 = _MONTHS.get(m.group(1)[:3].lower())
        m2 = _MONTHS.get(m.group(4)[:3].lower())
        y2 = int(m.group(6))
        y1 = int(m.group(3)) if m.group(3) else y2
        if m1 and m2:
            return _iso(y1, m1, int(m.group(2))), _iso(y2, m2, int(m.group(5)))
    # Same-month range: "Mon DD - DD, YYYY"
    m = _RE_SAME_MONTH.match(t)
    if m:
        mo = _MONTHS.get(m.group(1)[:3].lower())
        y = int(m.group(4))
        if mo:
            return _iso(y, mo, int(m.group(2))), _iso(y, mo, int(m.group(3)))
    # Single day: "Mon DD, YYYY"
    m = _RE_SINGLE.match(t)
    if m:
        mo = _MONTHS.get(m.group(1)[:3].lower())
        y = int(m.group(3))
        if mo:
            iso = _iso(y, mo, int(m.group(2)))
            return iso, iso
    return None, None


def _title_for_table(html: str, table_start: int) -> str | None:
    """Find the calendar title by scanning the de-tagged text just before the
    table. Titles aren't in heading elements, so we anchor to the table."""
    window = html[max(0, table_start - 900):table_start]
    window = re.sub(r"<[^>]+>", " ", window)
    window = re.sub(r"\s+", " ", window)
    matches = _TITLE_RE.findall(window)
    return matches[-1].strip() if matches else None


def _split_title(title: str) -> tuple[str, str, bool]:
    """('Spring 2026 Trimester Undergraduate Programs [Revised]')
       -> ('Spring 2026', 'Undergraduate', True)"""
    revised = "[" in title  # any bracketed suffix, usually [Revised]
    term_m = re.search(r"(Spring|Summer|Fall|Autumn|Winter)\s*20\d\d", title, re.I)
    term = term_m.group(0).strip() if term_m else title
    prog_m = re.search(r"Trimester\s+(.*?)\s+Programs?", title, re.I)
    program = prog_m.group(1).strip() if prog_m else "General"
    return term, program, revised


def parse_calendars(html: str) -> list[Calendar]:
    doc = HTMLParser(html)
    tables = doc.css("table")
    # Map each parsed table to its raw position so we can find its title.
    table_starts = [m.start() for m in re.finditer(r"<table", html, re.I)]
    calendars: list[Calendar] = []

    for idx, tbl in enumerate(tables):
        start = table_starts[idx] if idx < len(table_starts) else 0
        raw_title = _title_for_table(html, start)
        if not raw_title:
            continue  # not a calendar table (e.g. a layout table)

        term, program, revised = _split_title(raw_title)
        events: list[CalEvent] = []
        for row in tbl.css("tr"):
            cells = [c.text(separator=" ", strip=True) for c in row.css("td,th")]
            cells = [_RE_WS.sub(" ", c).strip() for c in cells if c.strip()]
            if len(cells) < 3:
                continue
            date_text, day, event = cells[0], cells[1], " ".join(cells[2:])
            start_iso, end_iso = _parse_dates(date_text)
            # Skip header rows ("Date | Day | Event") and any row without a real
            # date — a header has no parseable date and no digits.
            if start_iso is None and not _DIGIT_RE.search(date_text):
                continue
            events.append(CalEvent(
                date_text=date_text, day=day, event=event,
                start_date=start_iso, end_date=end_iso,
            ))

        if events:
            calendars.append(Calendar(
                title=raw_title, term=term, program=program,
                revised=revised, events=events,
            ))

    return _dedupe(calendars)


def _dedupe(cals: list[Calendar]) -> list[Calendar]:
    """Prefer a [Revised] calendar over its non-revised twin for the same
    term+program."""
    best: dict[tuple[str, str], Calendar] = {}
    for c in cals:
        key = (c.term.lower(), c.program.lower())
        cur = best.get(key)
        if cur is None or (c.revised and not cur.revised):
            best[key] = c
    return list(best.values())


async def fetch_calendars() -> list[Calendar]:
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        )
    }
    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        r = await client.get(CALENDAR_URL, headers=headers)
        r.raise_for_status()
        return parse_calendars(r.text)

"""Tests for academic-calendar date parsing and table extraction."""
from __future__ import annotations

from app.ucam.endpoints.academic_calendar import (
    _parse_dates,
    _split_title,
    parse_calendars,
)


def test_single_day():
    assert _parse_dates("Jul 6, 2026") == ("2026-07-06", "2026-07-06")


def test_same_month_range():
    assert _parse_dates("Feb 23 - 25, 2026") == ("2026-02-23", "2026-02-25")


def test_cross_month_range():
    assert _parse_dates("Dec 29, 2025 - Jan 2, 2026") == (
        "2025-12-29",
        "2026-01-02",
    )


def test_unparseable_returns_none():
    assert _parse_dates("Whenever") == (None, None)


def test_split_title():
    term, program, revised = _split_title(
        "Spring 2026 Trimester Undergraduate Programs [Revised]"
    )
    assert term == "Spring 2026"
    assert program == "Undergraduate"
    assert revised is True


def test_parse_calendars_from_html():
    html = """
    <div>Academic Calendar Summer 2026 Trimester Undergraduate Programs
      <table>
        <tr><td>Date</td><td>Day</td><td>Event</td></tr>
        <tr><td>Jul 4 - 6, 2026</td><td>Sat-Mon</td><td>Course Advising</td></tr>
        <tr><td>Jul 6, 2026</td><td>Mon</td><td>Classes Begin</td></tr>
      </table>
    </div>
    """
    cals = parse_calendars(html)
    assert len(cals) == 1
    c = cals[0]
    assert c.term == "Summer 2026"
    assert c.program == "Undergraduate"
    # Header row ("Date|Day|Event") has no parseable date and is dropped.
    assert len(c.events) == 2
    assert c.events[0].start_date == "2026-07-04"
    assert c.events[0].end_date == "2026-07-06"


def test_revised_calendar_preferred():
    html = """
    <div>Fall 2025 Trimester Undergraduate Programs
      <table><tr><td>Nov 1, 2025</td><td>Sat</td><td>Old plan</td></tr></table>
    </div>
    <div>Fall 2025 Trimester Undergraduate Programs [Revised]
      <table><tr><td>Nov 2, 2025</td><td>Sun</td><td>New plan</td></tr></table>
    </div>
    """
    cals = parse_calendars(html)
    assert len(cals) == 1
    assert cals[0].revised is True
    assert cals[0].events[0].event == "New plan"

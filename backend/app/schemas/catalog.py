"""Section-catalog schemas (the committed, shared course/section catalog).

Mirrors backend/data/section_catalog.json, produced by tools/build_catalog.py
from a per-trimester capture of the ucamcloud console. This is PUBLIC,
structural data (which sections exist, who teaches, when, and how big) — no
per-student state and no live seat occupancy. See app/api/catalog.py.
"""
from __future__ import annotations

from pydantic import BaseModel


class ScheduleSlot(BaseModel):
    day: str            # e.g. "Saturday"
    start: str          # "HH:MM"
    end: str            # "HH:MM"


class CatalogSection(BaseModel):
    section: str | None = None
    faculty_name: str | None = None
    faculty_code: str | None = None
    room: str | None = None
    credits: float | None = None
    capacity: int | None = None            # structural size, NOT live occupancy
    schedule: list[ScheduleSlot] = []
    kind: str = "other"                     # theory | lab | unscheduled | other


class CatalogCourse(BaseModel):
    formal_code: str
    name: str | None = None
    credits: float | None = None
    sections: list[CatalogSection] = []


class SectionCatalog(BaseModel):
    trimester: str | None = None
    captured_at: str | None = None          # when the source data was captured
    generated_at: str | None = None         # when the catalog file was built
    departments: list[str] = []
    courses: list[CatalogCourse] = []

"""Public academic-calendar route.

The UIU academic calendar is a PUBLIC page (no login) and identical for every
user, so — unlike per-student data — it's safe and sensible to fetch once and
cache server-side with a TTL. This keeps us off UIU's site on every request and
makes the app feel instant. When UIU posts a new calendar, the next refresh
after the TTL picks it up automatically.

No auth is required for this route.
"""
from __future__ import annotations

import asyncio
import logging
import time
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request, status

from app.auth.rate_limit import SlidingWindowLimiter
from app.config import settings
from app.schemas.student import (
    AcademicCalendar,
    AcademicCalendarResponse,
    CalendarEvent,
    NoticeItem,
    NoticesResponse,
)
from app.ucam.endpoints import academic_calendar as cal
from app.ucam.endpoints import notices_uiu

router = APIRouter(prefix="/calendar", tags=["calendar"])
log = logging.getLogger("open_campus.calendar")

# Public (no auth) and cached, but cap per-IP rate so one client can't hammer it.
# Generous: 60/min is far above real usage (the app fetches it once per launch).
_rate = SlidingWindowLimiter(max_events=60, window_seconds=60)


def _client_ip(request: Request) -> str:
    # Only trust XFF behind a proxy that overwrites it (see config); else spoofable.
    if settings.trust_forwarded_for:
        xff = request.headers.get("x-forwarded-for")
        if xff:
            return xff.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


_CACHE_TTL_SECONDS = 6 * 60 * 60  # 6 hours
_lock = asyncio.Lock()
_cache: AcademicCalendarResponse | None = None
_cached_at_monotonic: float = 0.0


def _to_schema(calendars: list[cal.Calendar]) -> AcademicCalendarResponse:
    return AcademicCalendarResponse(
        calendars=[
            AcademicCalendar(
                title=c.title,
                term=c.term,
                program=c.program,
                revised=c.revised,
                events=[
                    CalendarEvent(
                        date_text=e.date_text,
                        day=e.day,
                        event=e.event,
                        start_date=e.start_date,
                        end_date=e.end_date,
                    )
                    for e in c.events
                ],
            )
            for c in calendars
        ],
        fetched_at=datetime.now(timezone.utc).isoformat(),
    )


@router.get("/academic", response_model=AcademicCalendarResponse)
async def academic_calendar(request: Request) -> AcademicCalendarResponse:
    global _cache, _cached_at_monotonic
    if not _rate.check(_client_ip(request)):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please slow down.",
        )
    now = time.monotonic()
    if _cache is not None and (now - _cached_at_monotonic) < _CACHE_TTL_SECONDS:
        return _cache

    async with _lock:
        # Re-check inside the lock in case another request just refreshed it.
        now = time.monotonic()
        if _cache is not None and (now - _cached_at_monotonic) < _CACHE_TTL_SECONDS:
            return _cache
        try:
            calendars = await cal.fetch_calendars()
        except Exception as exc:  # noqa: BLE001 — never let calendar errors 500
            log.warning("academic calendar fetch failed: %s", exc)
            if _cache is not None:
                return _cache  # serve stale rather than fail
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Couldn't load the academic calendar right now.",
            )
        _cache = _to_schema(calendars)
        _cached_at_monotonic = time.monotonic()
        return _cache


# --- Public UIU notices (paginated) -----------------------------------------
# Same public-data model as the calendar: cache per page with a short TTL so we
# don't hit UIU on every scroll, but new notices still appear promptly.
_NOTICES_TTL_SECONDS = 15 * 60  # 15 minutes
_notices_lock = asyncio.Lock()
_notices_cache: dict[int, tuple[float, NoticesResponse]] = {}


@router.get("/notices/uiu", response_model=NoticesResponse)
async def uiu_notices(request: Request, page: int = 1) -> NoticesResponse:
    if not _rate.check(_client_ip(request)):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please slow down.",
        )
    page = max(1, page)
    cached = _notices_cache.get(page)
    if cached is not None and (time.monotonic() - cached[0]) < _NOTICES_TTL_SECONDS:
        return cached[1]

    async with _notices_lock:
        cached = _notices_cache.get(page)
        if cached is not None and (time.monotonic() - cached[0]) < _NOTICES_TTL_SECONDS:
            return cached[1]
        try:
            result = await notices_uiu.fetch_notices(page)
        except Exception as exc:  # noqa: BLE001 — never 500 on a scrape hiccup
            log.warning("uiu notices fetch failed (page %s): %s", page, exc)
            if cached is not None:
                return cached[1]  # serve stale rather than fail
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Couldn't load notices right now.",
            )
        resp = NoticesResponse(
            notices=[
                NoticeItem(title=n.title, url=n.url, date_text=n.date_text)
                for n in result.notices
            ],
            page=result.page,
            total_pages=result.total_pages,
            fetched_at=datetime.now(timezone.utc).isoformat(),
        )
        _notices_cache[page] = (time.monotonic(), resp)
        return resp

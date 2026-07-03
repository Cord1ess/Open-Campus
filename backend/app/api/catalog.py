"""Section catalog route — the shared, committed course/section catalog.

Unlike per-student routes, this serves a STATIC file (backend/data/
section_catalog.json) that is the same for every student and changes only when
the maintainer rebuilds it (once per trimester via tools/build_catalog.py). So:
no UCAM/ucamcloud call, no auth, no live data — just the public catalog of which
sections exist, who teaches them, when, and how big they are.

The file is loaded once and cached in memory; a small mtime check picks up a
rebuilt file without a server restart (handy in local dev). If the file is
missing (e.g. a fresh clone before the first capture), the route returns an
empty catalog rather than erroring, so the app degrades gracefully.

No auth is required for this route.
"""
from __future__ import annotations

import json
import logging
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request, status

from app.auth.rate_limit import SlidingWindowLimiter
from app.config import settings
from app.schemas.catalog import SectionCatalog

router = APIRouter(prefix="/catalog", tags=["catalog"])
log = logging.getLogger("open_campus.catalog")

# backend/app/api/catalog.py -> backend/data/section_catalog.json
_CATALOG_PATH = Path(__file__).resolve().parents[2] / "data" / "section_catalog.json"

# Public + static, but cap per-IP so a client can't hammer the process.
_rate = SlidingWindowLimiter(max_events=60, window_seconds=60)

# In-memory cache keyed by the file's mtime, so a rebuilt file is picked up
# without a restart but we don't re-read/parse on every request.
_cache: SectionCatalog | None = None
_cache_mtime: float | None = None


def _client_ip(request: Request) -> str:
    if settings.trust_forwarded_for:
        xff = request.headers.get("x-forwarded-for")
        if xff:
            return xff.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _load_catalog() -> SectionCatalog:
    """Load (and memoize) the catalog, reloading only when the file changes."""
    global _cache, _cache_mtime
    try:
        mtime = _CATALOG_PATH.stat().st_mtime
    except OSError:
        # No catalog file yet (fresh clone / not captured) — serve empty.
        if _cache is None:
            _cache = SectionCatalog()
        return _cache

    if _cache is not None and _cache_mtime == mtime:
        return _cache

    try:
        raw = json.loads(_CATALOG_PATH.read_text(encoding="utf-8"))
        _cache = SectionCatalog.model_validate(raw)
        _cache_mtime = mtime
    except (json.JSONDecodeError, ValueError) as exc:
        log.error("section_catalog.json is present but unreadable: %s", exc)
        # Keep any previously good cache; otherwise fail loudly (bad deploy).
        if _cache is not None:
            return _cache
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Section catalog is misconfigured.",
        )
    return _cache


@router.get("/sections", response_model=SectionCatalog)
async def sections(request: Request) -> SectionCatalog:
    if not _rate.check(_client_ip(request)):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please slow down.",
        )
    return _load_catalog()

"""
Maps Open Campus tokens <-> live UCAM sessions.

The app never sees UCAM cookies. Flow:
  - login() -> we hold the UcamSession (httpx client + cookie jar) under a random
    session id, and hand the app a signed JWT whose subject is that id.
  - each app request -> verify JWT -> look up the live UcamSession -> fetch live.

Sessions are evicted when their TTL passes (their httpx client is closed, freeing
sockets + the in-memory UCAM cookies) — lazily on access and via a periodic sweep
started at app startup. This bounds memory and avoids leaking authenticated UCAM
sessions for users who never explicitly log out.

In-memory store: single-process only. A multi-worker deployment would keep cookie
*values* in Redis and rebuild the httpx client per worker (the live client object
can't be shared across processes).
"""
from __future__ import annotations

import asyncio
import secrets
import time
from dataclasses import dataclass

import jwt

from app.config import settings
from app.ucam.client import UcamSession

_ALGORITHM = "HS256"


@dataclass
class _Entry:
    session: UcamSession
    expires_at: float  # monotonic seconds


# session_id -> entry
_sessions: dict[str, _Entry] = {}
_lock = asyncio.Lock()


def _ttl_seconds() -> float:
    return settings.session_ttl_minutes * 60


async def create_session(ucam_session: UcamSession) -> str:
    """Store the UCAM session; return a signed Open Campus JWT for the app."""
    session_id = secrets.token_urlsafe(24)
    expires_at = time.monotonic() + _ttl_seconds()
    async with _lock:
        _sessions[session_id] = _Entry(ucam_session, expires_at)

    # JWT exp uses wall-clock; the store uses monotonic — both ~= ttl from now.
    now = int(time.time())
    payload = {
        "sub": session_id,
        "roll": ucam_session.roll,  # convenience only; not security-bearing
        "exp": now + int(_ttl_seconds()),
        "iat": now,
    }
    return jwt.encode(payload, settings.session_secret, algorithm=_ALGORITHM)


def _decode(token: str, *, verify_exp: bool = True) -> dict | None:
    try:
        return jwt.decode(
            token, settings.session_secret, algorithms=[_ALGORITHM],
            options={"verify_exp": verify_exp},
        )
    except jwt.PyJWTError:
        return None


def resolve(token: str) -> UcamSession | None:
    """Verify a token and return the live UCAM session, or None if invalid/expired.

    Note: a past-TTL entry is treated as absent here (returns None). Its actual
    eviction + client close happens in the async sweep / on logout, because we
    can't await aclose() from this sync path.
    """
    payload = _decode(token)
    if not payload:
        return None
    entry = _sessions.get(payload.get("sub", ""))
    if entry is None:
        return None
    if entry.expires_at <= time.monotonic():
        return None  # expired; sweeper will close + remove it
    return entry.session


def roll_for(token: str) -> str | None:
    session = resolve(token)
    return session.roll if session else None


async def destroy(token: str) -> None:
    """Log out: drop the UCAM session and close its client."""
    payload = _decode(token, verify_exp=False)  # allow logout of an expired token
    if not payload:
        return
    session_id = payload.get("sub", "")
    async with _lock:
        entry = _sessions.pop(session_id, None)
    if entry is not None:
        await entry.session.aclose()


async def sweep_expired() -> int:
    """Evict and close all past-TTL sessions. Returns count evicted."""
    now = time.monotonic()
    async with _lock:
        expired = [sid for sid, e in _sessions.items() if e.expires_at <= now]
        entries = [_sessions.pop(sid) for sid in expired]
    for e in entries:
        await e.session.aclose()
    return len(entries)


async def close_all() -> None:
    """Close every session (app shutdown)."""
    async with _lock:
        entries = list(_sessions.values())
        _sessions.clear()
    for e in entries:
        await e.session.aclose()


async def run_sweeper(interval_seconds: float = 300.0) -> None:
    """Background loop: periodically evict expired sessions. Started at startup."""
    while True:
        await asyncio.sleep(interval_seconds)
        try:
            await sweep_expired()
        except Exception:  # never let the sweeper die silently-and-permanently
            import logging
            logging.getLogger("open_campus.session").exception("sweep failed")

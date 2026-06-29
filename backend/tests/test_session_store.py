"""Tests for the in-memory session store: token round-trip, TTL eviction, and
client cleanup. Uses a fake UcamSession (no real network)."""
from __future__ import annotations

import time

import pytest

from app.auth import session_store


class _FakeUcamSession:
    def __init__(self, roll="0112330000"):
        self.roll = roll
        self.closed = False

    async def aclose(self):
        self.closed = True


@pytest.fixture(autouse=True)
def _clear_store():
    session_store._sessions.clear()
    yield
    session_store._sessions.clear()


@pytest.mark.asyncio
async def test_create_and_resolve():
    sess = _FakeUcamSession()
    token = await session_store.create_session(sess)
    assert session_store.resolve(token) is sess
    assert session_store.roll_for(token) == "0112330000"


@pytest.mark.asyncio
async def test_resolve_rejects_garbage_token():
    assert session_store.resolve("not-a-jwt") is None


@pytest.mark.asyncio
async def test_destroy_closes_client():
    sess = _FakeUcamSession()
    token = await session_store.create_session(sess)
    await session_store.destroy(token)
    assert sess.closed is True
    assert session_store.resolve(token) is None


@pytest.mark.asyncio
async def test_expired_entry_not_resolved_and_swept():
    sess = _FakeUcamSession()
    token = await session_store.create_session(sess)
    # Force expiry by rewriting the entry's deadline into the past.
    sid = next(iter(session_store._sessions))
    session_store._sessions[sid].expires_at = time.monotonic() - 1
    # resolve() treats it as absent...
    assert session_store.resolve(token) is None
    # ...and sweep_expired() closes + removes it.
    evicted = await session_store.sweep_expired()
    assert evicted == 1
    assert sess.closed is True
    assert sid not in session_store._sessions


@pytest.mark.asyncio
async def test_close_all_closes_every_session():
    s1, s2 = _FakeUcamSession("a"), _FakeUcamSession("b")
    await session_store.create_session(s1)
    await session_store.create_session(s2)
    await session_store.close_all()
    assert s1.closed and s2.closed
    assert not session_store._sessions

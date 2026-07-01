"""Security-guard tests: SSRF host-pinning, PageMethod name/path injection
guards, session-token tamper rejection, and rate-limiter bucket cleanup.

All offline — no live UCAM. These lock down the guardrails that are easy to
weaken accidentally.
"""
from __future__ import annotations

import time

import pytest

from app.api.student import _is_ucam_url
from app.auth import session_store
from app.auth.rate_limit import SlidingWindowLimiter
from app.ucam.client import UcamError


# --- SSRF guard on the avatar proxy -----------------------------------------

def test_is_ucam_url_accepts_only_ucam_host():
    assert _is_ucam_url("https://ucam.uiu.ac.bd/Images/photo.jpg")
    assert _is_ucam_url("http://ucam.uiu.ac.bd/x")


@pytest.mark.parametrize(
    "url",
    [
        "https://attacker.com/x",
        "http://169.254.169.254/latest/meta-data/",   # cloud metadata SSRF
        "https://ucam.uiu.ac.bd.attacker.com/x",       # suffix spoof
        "https://evil.ucam.uiu.ac.bd@attacker.com/x",  # userinfo trick
        "file:///etc/passwd",
        "/relative/path",
        "ucam.uiu.ac.bd/no-scheme",
    ],
)
def test_is_ucam_url_rejects_non_ucam(url):
    assert not _is_ucam_url(url)


# --- PageMethod name/path injection guards ----------------------------------

@pytest.mark.asyncio
@pytest.mark.parametrize("method", ["Get Student", "../secret", "Get;drop", "1Bad"])
async def test_call_page_method_rejects_bad_method(method):
    # No session needed — the guard runs before any network use.
    with pytest.raises(UcamError):
        from app.ucam.client import call_page_method

        await call_page_method(object(), method)  # type: ignore[arg-type]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "page", ["/etc/passwd", "/Security/Login.php", "no-leading-slash.aspx", "/a b.aspx"]
)
async def test_call_page_method_rejects_bad_page(page):
    with pytest.raises(UcamError):
        from app.ucam.client import call_page_method

        await call_page_method(object(), "GetX", page_path=page)  # type: ignore[arg-type]


# --- Session-token tamper rejection -----------------------------------------

class _FakeSession:
    def __init__(self, roll="0112330000"):
        self.roll = roll

    async def aclose(self):
        pass


@pytest.mark.asyncio
async def test_resolve_rejects_token_signed_with_wrong_secret(monkeypatch):
    import jwt

    token = await session_store.create_session(_FakeSession())  # valid token
    # A structurally-valid JWT signed with a DIFFERENT secret must not resolve.
    payload = {"sub": "someone", "roll": "0112330000"}
    forged = jwt.encode(payload, "not-the-real-secret", algorithm="HS256")
    assert session_store.resolve(forged) is None
    # The genuine token still resolves.
    assert session_store.resolve(token) is not None
    await session_store.destroy(token)


@pytest.mark.asyncio
async def test_resolve_rejects_garbage():
    assert session_store.resolve("not.a.jwt") is None
    assert session_store.resolve("") is None


# --- Rate-limiter bucket cleanup (no unbounded growth) ----------------------

def test_limiter_sweeps_stale_buckets(monkeypatch):
    import app.auth.rate_limit as rl

    now = {"t": 1000.0}
    monkeypatch.setattr(rl.time, "monotonic", lambda: now["t"])

    limiter = SlidingWindowLimiter(max_events=3, window_seconds=10)
    limiter._sweep_every = 1  # sweep on every check for the test
    limiter.check("one-off-ip")
    assert "one-off-ip" in limiter._hits
    # Advance well past the window; the next check should prune the stale bucket.
    now["t"] += 100
    limiter.check("another-ip")
    assert "one-off-ip" not in limiter._hits  # swept

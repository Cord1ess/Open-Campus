"""Tests for the in-memory login rate limiter."""
from __future__ import annotations

from app.auth.rate_limit import SlidingWindowLimiter


def test_allows_up_to_limit_then_blocks():
    limiter = SlidingWindowLimiter(max_events=3, window_seconds=100)
    assert limiter.check("ip-a") is True
    assert limiter.check("ip-a") is True
    assert limiter.check("ip-a") is True
    # 4th within the window is blocked.
    assert limiter.check("ip-a") is False


def test_keys_are_isolated():
    limiter = SlidingWindowLimiter(max_events=1, window_seconds=100)
    assert limiter.check("ip-a") is True
    assert limiter.check("ip-a") is False
    # A different key has its own budget.
    assert limiter.check("ip-b") is True


def test_window_expiry_allows_again(monkeypatch):
    import app.auth.rate_limit as rl

    now = {"t": 1000.0}
    monkeypatch.setattr(rl.time, "monotonic", lambda: now["t"])

    limiter = SlidingWindowLimiter(max_events=1, window_seconds=10)
    assert limiter.check("ip-a") is True
    assert limiter.check("ip-a") is False
    # Advance past the window — the old hit expires.
    now["t"] += 11
    assert limiter.check("ip-a") is True


def test_retry_after_is_positive_when_blocked():
    limiter = SlidingWindowLimiter(max_events=1, window_seconds=60)
    limiter.check("ip-a")
    assert limiter.retry_after("ip-a") > 0
    assert limiter.retry_after("unseen") == 0

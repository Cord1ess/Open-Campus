"""A tiny in-memory, per-key sliding-window rate limiter.

Used to blunt brute-force / credential-stuffing against /auth/login. It is
intentionally dependency-free and process-local (matching the rest of the
stateless, single-process design): good enough to stop a casual attacker
hammering the login endpoint from one host. A multi-instance deployment would
move this to Redis, the same way session_store would.

Not a substitute for UCAM's own lockout — it's a courtesy guard so our proxy
doesn't relay a flood of login attempts upstream.
"""
from __future__ import annotations

import time
from collections import deque
from threading import Lock


class SlidingWindowLimiter:
    def __init__(self, max_events: int, window_seconds: float) -> None:
        self._max = max_events
        self._window = window_seconds
        # A plain dict (not defaultdict): we insert a bucket only when we actually
        # record a hit, and prune buckets once their newest hit ages out, so the
        # map doesn't grow unbounded with one-off IPs that never come back.
        self._hits: dict[str, deque[float]] = {}
        self._lock = Lock()
        # Sweep stale buckets every N checks (cheap, amortized) rather than on a
        # timer — keeps this dependency-free and process-local.
        self._checks_since_sweep = 0
        self._sweep_every = 256

    def check(self, key: str) -> bool:
        """Record an attempt for [key]. Returns True if allowed, False if the
        key has exceeded max_events within the window."""
        now = time.monotonic()
        cutoff = now - self._window
        with self._lock:
            self._checks_since_sweep += 1
            if self._checks_since_sweep >= self._sweep_every:
                self._sweep(now)
                self._checks_since_sweep = 0

            q = self._hits.get(key)
            if q is None:
                self._hits[key] = deque([now])
                return True
            while q and q[0] < cutoff:
                q.popleft()
            if len(q) >= self._max:
                return False
            q.append(now)
            return True

    def _sweep(self, now: float) -> None:
        """Drop buckets whose newest hit has fully aged out of the window, so the
        dict doesn't accumulate stale one-off IPs. Caller holds the lock."""
        cutoff = now - self._window
        stale = [k for k, q in self._hits.items() if not q or q[-1] < cutoff]
        for k in stale:
            self._hits.pop(k, None)

    def retry_after(self, key: str) -> int:
        """Seconds until the oldest in-window hit for [key] expires."""
        now = time.monotonic()
        with self._lock:
            q = self._hits.get(key)
            if not q:
                return 0
            return max(0, int(self._window - (now - q[0])) + 1)


# Default policy: at most 8 login attempts per IP per 5 minutes. Generous enough
# for a fumbling human (typos, password manager), tight enough to stop a flood.
login_limiter = SlidingWindowLimiter(max_events=8, window_seconds=300)

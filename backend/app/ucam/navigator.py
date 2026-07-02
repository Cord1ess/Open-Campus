"""UCAM page navigator — resolves a target .aspx page to its live, mmi-tokenized URL.

UCAM pages are reached with a per-navigation `mmi=<hex>` token in the query
string. A bare GET of e.g. /Student/StudentCourseHistory.aspx WITHOUT the token
returns an empty/non-data shell — which is why directly-fetched data pages came
back blank. The token is handed out via the menu links: StudentHome links to the
section *hubs* (BillHome, RegistrationHome…), and each hub links to its leaf
pages. So we discover a page's URL by crawling those links breadth-first from the
landing page, following at most a couple of hops.

We cache the discovered map on the session so repeated fetches are cheap.
"""
from __future__ import annotations

import re
from urllib.parse import urljoin, urlparse

from app.config import settings
from app.ucam.client import (
    UcamSession,
    UcamSessionExpired,
    _is_login_url,
    _looks_like_login_page,
)

# href="...SomePage.aspx?mmi=abc123" — internal links carrying a nav token.
_LINK_RE = re.compile(r'href="([^"]*\.aspx\?mmi=[0-9a-fA-F]+)"', re.IGNORECASE)

# How many link-hops to follow from the landing page when searching.
_MAX_HOPS = 3


def _abs(base: str, href: str) -> str:
    return urljoin(base, href.replace("&amp;", "&"))


def _links(html: str, base_url: str) -> list[str]:
    host = urlparse(settings.ucam_base_url).netloc
    out = []
    for href in _LINK_RE.findall(html):
        u = _abs(base_url, href)
        if urlparse(u).netloc == host:
            out.append(u)
    return out


async def resolve_page_url(session: UcamSession, page_path: str) -> str | None:
    """Return the live URL (with mmi) for `page_path` (e.g.
    "/Student/StudentCourseHistory.aspx"), discovered by crawling the menu from
    the landing page. Returns None if not reachable. Cached on the session."""
    page_path = page_path.lower()
    cache = session._nav_cache
    if page_path in cache:
        return cache[page_path]

    start = session.landing_url or urljoin(
        settings.ucam_base_url, settings.ucam_home_path
    )
    seen: set[str] = set()
    # BFS over link-bearing pages, recording every mmi URL we encounter.
    frontier = [start]
    for _hop in range(_MAX_HOPS):
        next_frontier: list[str] = []
        for url in frontier:
            path = urlparse(url).path.lower()
            if path in seen:
                continue
            seen.add(path)
            try:
                async with session.pacing():
                    resp = await session.client.get(url)
            except Exception:
                continue
            if "html" not in resp.headers.get("content-type", ""):
                continue
            for link in _links(resp.text, str(resp.url)):
                lpath = urlparse(link).path.lower()
                # Record the first mmi URL seen for each path.
                cache.setdefault(lpath, link)
                if lpath not in seen:
                    next_frontier.append(link)
            # Early exit once we've found the target (cache is the session's own
            # dict, so it persists automatically).
            if page_path in cache:
                return cache[page_path]
        frontier = next_frontier

    return cache.get(page_path)


async def fetch_page(session: UcamSession, page_path: str) -> str:
    """Fetch a UCAM data page's HTML using its live mmi-tokenized URL.

    Falls back to a bare GET if the token can't be discovered (better to try than
    to fail outright). Sets the Referer to the landing page, as the browser does.

    Raises UcamSessionExpired ONLY on positive evidence the session died (401/403
    or the page is actually the UCAM login form / a redirect back to it) — the
    same tight rule as call_page_method, so HTML pages (bill, course history,
    marks, advising) surface expiry the same way the JSON PageMethods do, instead
    of silently returning a login page that parses to an empty screen. A merely
    odd response is left to the parser rather than being called an expiry.
    """
    url = await resolve_page_url(session, page_path)
    if url is None:
        url = urljoin(settings.ucam_base_url, page_path)
    async with session.pacing():
        resp = await session.client.get(
            url,
            headers={"Referer": session.landing_url or settings.ucam_base_url},
        )
    if resp.status_code in (401, 403) or _is_login_url(str(resp.url)) or \
            _looks_like_login_page(resp.text):
        raise UcamSessionExpired(
            f"{page_path}: session expired (bounced to login)."
        )
    resp.raise_for_status()
    return resp.text

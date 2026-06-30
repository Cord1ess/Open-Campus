"""Public UIU notices scraper.

UIU publishes all notices as plain HTML on a PUBLIC page (no login):
https://www.uiu.ac.bd/notice/  with pagination at /notice/page/N/. Newest first.

Each notice on the LIST page is:
    <div class="notice">
      <div class="details">
        <div class="date-container"><span class="date">June 30, 2026</span></div>
        <div class="title"><a href="...">Notice title</a></div>
      </div>
    </div>

The list page carries only title + date + link (the body/attachments live on each
notice's own page). So this scraper returns those three fields per notice plus the
total page count parsed from the pagination links — enough for a paginated list
that deep-links out to the original notice.

Public, identical for everyone → safe to cache server-side with a TTL (see route).
"""
from __future__ import annotations

import re
from dataclasses import dataclass

import httpx
from selectolax.parser import HTMLParser

NOTICE_URL = "https://www.uiu.ac.bd/notice/"
_PAGE_RE = re.compile(r"/notice/page/(\d+)")
_WS_RE = re.compile(r"\s+")

# A browser-like UA so the public site serves us the normal page.
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml",
}


@dataclass
class Notice:
    title: str
    url: str
    date_text: str | None = None


@dataclass
class NoticePage:
    notices: list[Notice]
    page: int
    total_pages: int


def _clean(text: str) -> str:
    return _WS_RE.sub(" ", text).strip()


def parse_notices(html: str, *, page: int) -> NoticePage:
    """Parse one notice list page into [Notice] + the total page count."""
    tree = HTMLParser(html)
    notices: list[Notice] = []
    for node in tree.css("div.notice"):
        link = node.css_first("div.title a")
        if link is None:
            continue
        href = (link.attributes.get("href") or "").strip()
        title = _clean(link.text())
        if not href or not title:
            continue
        date_el = node.css_first(".date-container .date") or node.css_first(".date")
        date_text = _clean(date_el.text()) if date_el is not None else None
        notices.append(Notice(title=title, url=href, date_text=date_text))

    # Total pages = the highest /notice/page/N link on the page (default 1).
    total = page
    for a in tree.css("a"):
        href = a.attributes.get("href") or ""
        m = _PAGE_RE.search(href)
        if m:
            total = max(total, int(m.group(1)))
    return NoticePage(notices=notices, page=page, total_pages=max(total, 1))


async def fetch_notices(page: int = 1) -> NoticePage:
    """Fetch one page of notices. page 1 = /notice/, page N = /notice/page/N/."""
    page = max(1, page)
    url = NOTICE_URL if page == 1 else f"{NOTICE_URL}page/{page}/"
    async with httpx.AsyncClient(
        timeout=httpx.Timeout(20.0), follow_redirects=True, headers=_HEADERS
    ) as client:
        resp = await client.get(url)
        resp.raise_for_status()
    return parse_notices(resp.text, page=page)

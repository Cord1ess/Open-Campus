"""
UCAM client — reproduces a real browser's interaction with the ASP.NET Web Forms
portal at ucam.uiu.ac.bd. All behavior here was verified against captured live
traffic (see docs/RECON.md).

Login is an ASP.NET AJAX **async (UpdatePanel) postback**, not a plain form POST:

  1. GET  /Security/Login.aspx
       -> receive ASP.NET_SessionId + browserFingerprint cookies
       -> scrape the hidden ViewState fields from the returned HTML
  2. POST /Security/Login.aspx  (async partial postback)
       -> send the hidden fields + credentials + the async markers
          (scMgtMas, __ASYNCPOST=true, __EVENTTARGET/__EVENTARGUMENT)
       -> response is text/plain in the pipe-delimited async format; on success
          it carries a pageRedirect to StudentHome.aspx and .ASPXAUTH is set
  3. GET  /Security/StudentHome.aspx
       -> the authenticated landing page; we read the student's roll/ID from it

Data is then read from ASP.NET **PageMethods** that return JSON ({"d": ...}).

We keep one httpx.AsyncClient per user session so the cookie jar
(ASP.NET_SessionId, .ASPXAUTH, browserFingerprint) persists across requests.
The UCAM password is used only during login() and never stored.
"""
from __future__ import annotations

import asyncio
import json
import logging
import random
import re
from contextlib import asynccontextmanager
from contextvars import ContextVar
from dataclasses import dataclass, field
from urllib.parse import unquote, urljoin, urlparse

import httpx
from selectolax.parser import HTMLParser

from app.config import settings

log = logging.getLogger("open_campus.ucam")


class LoginDebug:
    """Optional capture of raw login internals, for the live test harness only.

    Never enabled in normal request handling. When set via the `_debug` context
    var, login() records non-credential diagnostics (panel id, response status,
    body, redirect, roll strategy) so a failing live test shows exactly what UCAM
    returned. The password is never recorded.
    """

    def __init__(self) -> None:
        self.data: dict = {}

    def record(self, **kw) -> None:
        self.data.update(kw)


# Set by the live-test harness to capture diagnostics; None in production.
_debug_var: ContextVar[LoginDebug | None] = ContextVar("login_debug", default=None)

# Verified login field names (docs/RECON.md).
_FIELD_USERNAME = "logMain$UserName"
_FIELD_PASSWORD = "logMain$Password"
_FIELD_BUTTON = "logMain$Button1"
_LOGIN_BUTTON_VALUE = "LOG IN"
# The ScriptManager field's VALUE is "<UpdatePanelClientId>|<postback target>".
# Verified from the HAR: scMgtMas = "upMain|logMain$Button1".
# The left side is the UpdatePanel id (upMain), NOT the ScriptManager name.
_ASYNC_TARGET = "logMain$Button1"
_DEFAULT_UPDATE_PANEL = "upMain"


class UcamError(Exception):
    """Base class for UCAM interaction failures (network, layout change, etc.)."""


class UcamLoginError(UcamError):
    """Login failed (bad credentials, or UCAM returned the login page again)."""


class UcamSessionExpired(UcamError):
    """A previously-authenticated session is no longer valid; re-login needed."""


@dataclass
class UcamSession:
    """A live, authenticated UCAM session for a single user.

    Holds the httpx client (with its cookie jar). The password is NOT stored;
    once login succeeds only the cookies matter. `roll` is the student ID read
    from the authenticated landing page — it is the trusted identity used for
    all data calls (never a client-supplied value).
    """

    client: httpx.AsyncClient
    roll: str
    fingerprint: str | None = None
    landing_url: str | None = None
    _hidden: dict[str, str] = field(default_factory=dict)
    # Humane-pacing state: serialize UCAM-bound calls and space them out so the
    # traffic looks like a person clicking, not an automated burst. See memory:
    # ucam-indistinguishability.
    _lock: asyncio.Lock = field(default_factory=asyncio.Lock, repr=False)
    _last_request_at: float = field(default=0.0, repr=False)
    _nav_cache: dict[str, str] = field(default_factory=dict, repr=False)

    async def throttle(self) -> None:
        """Acquire a turn and wait until enough time has passed since the last
        UCAM request (with a little jitter), so requests are paced like a human.

        Callers do:  async with session.pacing(): await session.client.get(...)
        """
        min_gap = settings.per_user_min_interval_seconds
        # Add up to ~40% jitter so the spacing isn't robotically uniform.
        jitter = min_gap * 0.4 * random.random()
        target = min_gap + jitter
        now = asyncio.get_event_loop().time()
        elapsed = now - self._last_request_at
        if self._last_request_at and elapsed < target:
            await asyncio.sleep(target - elapsed)
        self._last_request_at = asyncio.get_event_loop().time()

    @asynccontextmanager
    async def pacing(self):
        """Serialize + space a single UCAM request. Use around every client call
        that hits UCAM so concurrent app requests don't burst the portal."""
        async with self._lock:
            await self.throttle()
            yield

    async def aclose(self) -> None:
        await self.client.aclose()


def _new_client() -> httpx.AsyncClient:
    # Present as a real Chrome session. The header set is kept consistent with the
    # Chrome/126 User-Agent (client hints + fetch metadata) so UCAM sees an
    # ordinary browser, not an automated client. See memory: ucam-indistinguishability.
    # Generous read timeout: UCAM's login postback can be slow under load. Use a
    # short connect timeout (fail fast if unreachable) but a long read timeout so
    # a slow-but-alive UCAM isn't cut off mid-login.
    timeout = httpx.Timeout(
        connect=10.0,
        read=settings.ucam_timeout_seconds,
        write=15.0,
        pool=10.0,
    )
    return httpx.AsyncClient(
        base_url=settings.ucam_base_url,
        timeout=timeout,
        follow_redirects=True,
        headers={
            "User-Agent": settings.user_agent,
            "Accept": (
                "text/html,application/xhtml+xml,application/xml;q=0.9,"
                "image/avif,image/webp,*/*;q=0.8"
            ),
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            # Chrome client hints (match the UA above).
            "sec-ch-ua": '"Not/A)Brand";v="8", "Chromium";v="126", '
            '"Google Chrome";v="126"',
            "sec-ch-ua-mobile": "?0",
            "sec-ch-ua-platform": '"Windows"',
            # Fetch metadata for a top-level document navigation.
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-User": "?1",
            "Upgrade-Insecure-Requests": "1",
        },
    )


def _scrape_hidden_fields(html: str) -> dict[str, str]:
    """Extract all <input type=hidden> name/value pairs (ViewState et al.)."""
    tree = HTMLParser(html)
    fields: dict[str, str] = {}
    for node in tree.css("input[type=hidden]"):
        name = node.attributes.get("name")
        if name:
            fields[name] = node.attributes.get("value") or ""
    return fields


def _find_scriptmanager_field(html: str) -> str | None:
    """The async postback uses a ScriptManager field whose NAME is the form's
    ScriptManager id (e.g. 'scMgtMas'). It appears as the first arg to
    Sys.WebForms.PageRequestManager._initialize('scMgtMas', ...)."""
    m = re.search(r"PageRequestManager\._initialize\(\s*'([^']+)'", html)
    return m.group(1) if m else None


def _find_update_panel(html: str) -> str:
    """Discover the UpdatePanel id that owns the login postback. The ScriptManager
    field's value is "<panelId>|<target>"; the panel id is the LEFT side.

    The PageRequestManager init lists the update-panel client ids as an array, e.g.
    _initialize('scMgtMas', 'frmLogIn', ['tupMain','upMain'], ...). The login panel
    is the one containing the login button. We prefer 'upMain' (verified in HAR),
    then any id in that array, then the first <div id="up...">. Falls back to the
    verified default."""
    # 1) Verified default appears literally as a div on the page.
    if f'id="{_DEFAULT_UPDATE_PANEL}"' in html:
        return _DEFAULT_UPDATE_PANEL
    # 2) Panel-id array from the PageRequestManager init.
    m = re.search(
        r"PageRequestManager\._initialize\([^)]*?\[([^\]]*)\]", html
    )
    if m:
        ids = re.findall(r"'([^']+)'", m.group(1))
        if _DEFAULT_UPDATE_PANEL in ids:
            return _DEFAULT_UPDATE_PANEL
        if ids:
            return ids[-1]  # innermost panel is typically last
    # 3) Any <div id="up...">.
    m = re.search(r'id="(up[A-Za-z0-9]+)"', html)
    if m:
        return m.group(1)
    return _DEFAULT_UPDATE_PANEL


def _looks_like_login_page(text: str) -> bool:
    """True if the response still contains the login form (login not succeeded
    / session expired and we were bounced back)."""
    return ('name="frmLogIn"' in text or f'name="{_FIELD_USERNAME}"' in text)


def _is_login_url(url: str) -> bool:
    """True if a redirect target points back at the login page (precise — matches
    the path ending in Login.aspx, not just any 'login' substring)."""
    path = urlparse(url).path.lower()
    return path.endswith("login.aspx")


def _parse_async_redirect(text: str) -> str | None:
    """ASP.NET async-postback responses are pipe-delimited records of the form
        len|type|id|content|len|type|id|content|...
    A successful login emits a 'pageRedirect' record whose content is the URL,
    e.g.  '123|pageRedirect||/Security/StudentHome.aspx?mmi=...|'.

    The URL is percent-ENCODED in the response (e.g. '%2fSecurity%2f...%3fmmi%3d..'),
    so we unquote it before returning. Returns None if absent (the bad-credentials
    case re-renders the panel with no pageRedirect record)."""
    m = re.search(r"\|pageRedirect\|\|([^|]+)\|", text)
    if not m:
        # Tolerate a leading-pipe-less variant.
        m = re.search(r"pageRedirect\|\|?([^|]+)\|", text)
    if not m:
        return None
    candidate = unquote(m.group(1).strip())
    if candidate.startswith(("/", "http")):
        return candidate
    return None


def _extract_roll(home_html: str) -> tuple[str | None, str]:
    """Read the student's ID/roll from the authenticated StudentHome page.

    Returns (roll, how) where `how` describes which strategy matched, so callers
    can warn when only the brittle fallback succeeded. The roll is the TRUSTED
    identity for all data calls — never a client-supplied value.

    Verified locations on the real page (HAR 2026-06-28):
      <span id="ctl00_MainContainer_Label1">0112330000</span>
      <a href="javascript:__doPostBack('ctl00$lbtnUserName','')">0112330000</a>
    """
    # 1) Precise: the user-name label span.
    m = re.search(
        r'id="ctl00_MainContainer_Label1"[^>]*>\s*(\d{6,})\s*<', home_html
    )
    if m:
        return m.group(1), "label_span"
    # 2) Precise: the lbtnUserName postback link text.
    m = re.search(
        r"lbtnUserName[^>]*>\s*(\d{6,})\s*</a>", home_html, re.IGNORECASE
    )
    if m:
        return m.group(1), "username_link"
    # 3) Generic hidden field / JS var holding a roll.
    for pat, how in (
        (r"var\s+roll\s*=\s*['\"](\d{6,})['\"]", "js_var"),
        (r"roll\s*:\s*['\"](\d{6,})['\"]", "js_obj"),
    ):
        m = re.search(pat, home_html, re.IGNORECASE)
        if m:
            return m.group(1), how
    # 4) Last resort: a UIU-style 10-digit id anywhere in the page.
    m = re.search(r"\b(0\d{9})\b", home_html)
    if m:
        return m.group(1), "digit_fallback"
    return None, "none"


async def login(student_id: str, password: str) -> UcamSession:
    """Perform the async-postback login. Returns a live UcamSession on success.

    The password is used here and then forgotten — never stored.
    Raises UcamLoginError on bad credentials, UcamError on transport/layout issues.
    """
    client = _new_client()

    # --- Step 1: GET the login page (seed cookies + ViewState) ---
    try:
        get_resp = await client.get(settings.ucam_login_path)
        get_resp.raise_for_status()
    except httpx.HTTPError as exc:
        await client.aclose()
        raise UcamError(f"Could not reach UCAM login page: {exc}") from exc

    hidden = _scrape_hidden_fields(get_resp.text)
    if "__VIEWSTATE" not in hidden:
        await client.aclose()
        raise UcamError("Login page missing __VIEWSTATE; UCAM layout may have changed.")

    sm_field = _find_scriptmanager_field(get_resp.text) or "scMgtMas"
    panel_id = _find_update_panel(get_resp.text)
    fingerprint = client.cookies.get("browserFingerprint")

    # --- Step 2: POST the async partial postback ---
    form: dict[str, str] = dict(hidden)
    form[_FIELD_USERNAME] = student_id
    form[_FIELD_PASSWORD] = password
    form[_FIELD_BUTTON] = _LOGIN_BUTTON_VALUE
    # Async markers (verified in HAR). The ScriptManager field value is
    # "<UpdatePanelId>|<target>" — panel id on the LEFT (e.g. "upMain|logMain$Button1").
    form[sm_field] = f"{panel_id}|{_ASYNC_TARGET}"
    form["__EVENTTARGET"] = form.get("__EVENTTARGET", "")
    form["__EVENTARGUMENT"] = form.get("__EVENTARGUMENT", "")
    form["__ASYNCPOST"] = "true"

    try:
        post_resp = await client.post(
            settings.ucam_login_path,
            data=form,
            headers={
                "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                "X-Requested-With": "XMLHttpRequest",
                "X-MicrosoftAjax": "Delta=true",
                "Referer": str(get_resp.url),
                "Origin": settings.ucam_base_url,
            },
        )
        post_resp.raise_for_status()
    except httpx.HTTPError as exc:
        await client.aclose()
        raise UcamError(f"Login request failed: {exc}") from exc

    # --- Step 3: decide success ---
    # PRIMARY signal: the async response emitted a pageRedirect to a non-login page.
    # On bad credentials UCAM re-renders the panel with NO pageRedirect (so
    # redirect is None). The .ASPXAUTH cookie may be set on this response OR on the
    # subsequent redirect GET, so it's advisory here, checked again after we land.
    redirect = _parse_async_redirect(post_resp.text)
    bounced_to_login = redirect is not None and _is_login_url(redirect)

    dbg = _debug_var.get()
    if dbg is not None:
        dbg.record(
            panel_id=panel_id, sm_field=sm_field,
            post_status=post_resp.status_code,
            post_ctype=post_resp.headers.get("content-type", ""),
            post_body=post_resp.text,
            redirect=redirect,
            aspxauth_after_post=client.cookies.get(".ASPXAUTH") is not None,
        )

    if redirect is None or bounced_to_login:
        await client.aclose()
        raise UcamLoginError(
            "Login failed — UCAM did not authenticate. Check the ID and password."
        )

    # --- Step 4: follow the redirect to the landing page; read the roll ---
    home_path = redirect
    if urlparse(home_path).scheme:
        home_path = urljoin(settings.ucam_base_url, home_path)
    try:
        home_resp = await client.get(home_path)
        home_resp.raise_for_status()
    except httpx.HTTPError as exc:
        await client.aclose()
        raise UcamError(f"Could not load landing page after login: {exc}") from exc

    if _looks_like_login_page(home_resp.text):
        await client.aclose()
        raise UcamLoginError("Login appeared to succeed but landed back on login.")

    # Confirm we actually have an auth ticket now (set by post or redirect).
    if client.cookies.get(".ASPXAUTH") is None:
        log.warning("login: no .ASPXAUTH cookie after landing on %s", home_resp.url)

    landing_url = str(home_resp.url)
    if "mmi=" not in landing_url:
        # The PageMethods' Referer carries this token; warn if it's missing.
        log.warning("login: landing URL missing mmi token (%s); PageMethods may fail", landing_url)

    roll, how = _extract_roll(home_resp.text)
    if roll is None:
        roll = student_id
        log.warning("login: could not scrape roll from landing page; using typed id")
    elif how in ("digit_fallback",):
        log.warning("login: roll matched only via brittle fallback (%s)", how)

    if dbg is not None:
        dbg.record(landing_url=landing_url, roll=roll, roll_how=how)

    return UcamSession(
        client=client,
        roll=roll,
        fingerprint=fingerprint,
        landing_url=landing_url,
        _hidden=hidden,
    )


async def call_page_method(
    session: UcamSession,
    method: str,
    payload: dict | None = None,
    *,
    page_path: str | None = None,
) -> object:
    """Call an ASP.NET PageMethod (JSON endpoint) on an authenticated session.

    e.g. call_page_method(session, "GetStudentResultSummary", {"roll": session.roll})
    POSTs application/json to <page>/<method> and returns the unwrapped value of
    the ASP.NET {"d": ...} envelope.

    Raises UcamSessionExpired if UCAM bounces us to login, UcamError otherwise.
    """
    # Guard the latent path-injection surface: method must be a bare identifier and
    # page_path (if ever passed) a known .aspx page. Current callers pass constants.
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", method):
        raise UcamError(f"Refusing to call invalid PageMethod name: {method!r}")
    page = page_path or settings.ucam_home_path
    if not re.fullmatch(r"/[A-Za-z0-9/_-]+\.aspx", page):
        raise UcamError(f"Refusing to call invalid page path: {page!r}")

    url = f"{page}/{method}"
    body = json.dumps(payload or {})
    try:
        async with session.pacing():
            resp = await session.client.post(
                url,
                content=body,
                headers={
                    "Content-Type": "application/json; charset=UTF-8",
                    "X-Requested-With": "XMLHttpRequest",
                    "Accept": "application/json, text/javascript, */*; q=0.01",
                    "Referer": session.landing_url
                    or f"{settings.ucam_base_url}{page}",
                },
            )
    except httpx.HTTPError as exc:
        raise UcamError(f"PageMethod {method} request failed: {exc}") from exc

    # Check HTTP status FIRST so a real 5xx isn't misreported as session-expiry.
    if resp.status_code >= 500:
        raise UcamError(f"PageMethod {method} returned HTTP {resp.status_code}.")
    # An expired session yields an HTML login page (often 200/302→login) or 401/403.
    ctype = resp.headers.get("content-type", "")
    if resp.status_code in (401, 403) or "json" not in ctype or _looks_like_login_page(resp.text):
        raise UcamSessionExpired(
            f"PageMethod {method} did not return JSON; session likely expired."
        )
    if resp.status_code >= 400:
        raise UcamError(f"PageMethod {method} returned HTTP {resp.status_code}.")

    data = resp.json()
    # ASP.NET wraps the real payload in {"d": ...}.
    return data.get("d") if isinstance(data, dict) and "d" in data else data

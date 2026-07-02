"""call_page_method status-mapping tests: the contract that a dead UCAM session
surfaces as UcamSessionExpired (→ 409 at the route), a real 5xx as UcamError
(→ 502), and a valid {"d": ...} unwraps correctly.

Uses a fake session/client so no network is touched.
"""
from __future__ import annotations

import contextlib

import pytest

from app.ucam.client import (
    UcamError,
    UcamSessionExpired,
    call_page_method,
)


class _FakeResponse:
    def __init__(self, status_code, *, headers=None, text="", json_body=None,
                 url="https://ucam.uiu.ac.bd/Security/StudentHome.aspx/GetX"):
        self.status_code = status_code
        self.headers = headers or {}
        self.text = text
        self._json = json_body
        # A data URL by default (NOT the login page) so status/body decide expiry.
        self.url = url

    def json(self):
        return self._json


class _FakeClient:
    def __init__(self, response):
        self._response = response

    async def post(self, url, content=None, headers=None):
        return self._response


class _FakeSession:
    """Minimal stand-in for UcamSession: a pacing() context + a client + roll."""

    def __init__(self, response):
        self.client = _FakeClient(response)
        self.roll = "0112330000"
        self.landing_url = "https://ucam.uiu.ac.bd/Security/StudentHome.aspx"

    @contextlib.asynccontextmanager
    async def pacing(self):
        yield


@pytest.mark.asyncio
async def test_valid_json_envelope_unwraps_d():
    resp = _FakeResponse(
        200,
        headers={"content-type": "application/json"},
        json_body={"d": [{"x": 1}]},
    )
    out = await call_page_method(_FakeSession(resp), "GetX")
    assert out == [{"x": 1}]


@pytest.mark.asyncio
async def test_login_html_body_is_session_expired():
    # A 200 that returns the login page (session died upstream) → expired.
    resp = _FakeResponse(
        200,
        headers={"content-type": "text/html"},
        text='<form name="frmLogIn">...</form>',
    )
    with pytest.raises(UcamSessionExpired):
        await call_page_method(_FakeSession(resp), "GetX")


@pytest.mark.asyncio
@pytest.mark.parametrize("code", [401, 403])
async def test_401_403_is_session_expired(code):
    resp = _FakeResponse(code, headers={"content-type": "text/html"}, text="nope")
    with pytest.raises(UcamSessionExpired):
        await call_page_method(_FakeSession(resp), "GetX")


@pytest.mark.asyncio
async def test_500_is_ucam_error_not_expired():
    # A real server error must NOT be misreported as a session expiry (which would
    # wrongly prompt a re-login instead of "try again").
    resp = _FakeResponse(500, headers={"content-type": "text/html"}, text="oops")
    with pytest.raises(UcamError) as ei:
        await call_page_method(_FakeSession(resp), "GetX")
    assert not isinstance(ei.value, UcamSessionExpired)


@pytest.mark.asyncio
async def test_non_json_200_is_TRANSIENT_not_expiry():
    # 200 but not JSON and NOT the login page → transient blip, NOT expiry.
    # (Calling this "expired" caused false re-login prompts during active use.)
    resp = _FakeResponse(200, headers={"content-type": "text/plain"}, text="x")
    with pytest.raises(UcamError) as ei:
        await call_page_method(_FakeSession(resp), "GetX")
    assert not isinstance(ei.value, UcamSessionExpired)


@pytest.mark.asyncio
async def test_non_json_200_login_page_IS_expiry():
    # 200, non-JSON, but the body IS the login form → genuine expiry.
    resp = _FakeResponse(
        200,
        headers={"content-type": "text/html"},
        text='<form name="frmLogIn">...</form>',
    )
    with pytest.raises(UcamSessionExpired):
        await call_page_method(_FakeSession(resp), "GetX")

"""fetch_page expiry detection: HTML data pages (bill, course history, marks,
advising) must surface a dead session as UcamSessionExpired — the same tight
rule as the JSON PageMethods — instead of silently returning a login page that
parses to an empty screen. And a transient/odd response must NOT be called an
expiry.
"""
from __future__ import annotations

import contextlib

import pytest

from app.ucam import navigator
from app.ucam.client import UcamError, UcamSessionExpired


class _Resp:
    def __init__(self, status_code=200, text="", url="https://ucam.uiu.ac.bd/Bill/x.aspx"):
        self.status_code = status_code
        self.text = text
        self.url = url

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(f"HTTP {self.status_code}")


class _Client:
    def __init__(self, resp):
        self._resp = resp

    async def get(self, url, headers=None):
        return self._resp


class _Session:
    def __init__(self, resp):
        self.client = _Client(resp)
        self.landing_url = "https://ucam.uiu.ac.bd/Security/StudentHome.aspx"
        self._nav_cache = {}

    @contextlib.asynccontextmanager
    async def pacing(self):
        yield


@pytest.fixture(autouse=True)
def _stub_resolve(monkeypatch):
    # Skip the live menu crawl; return a plausible mmi URL.
    async def fake_resolve(session, page_path):
        return "https://ucam.uiu.ac.bd" + page_path + "?mmi=abc"
    monkeypatch.setattr(navigator, "resolve_page_url", fake_resolve)


@pytest.mark.asyncio
async def test_fetch_page_login_body_is_expiry():
    resp = _Resp(text='<form name="frmLogIn">...</form>')
    with pytest.raises(UcamSessionExpired):
        await navigator.fetch_page(_Session(resp), "/Bill/StudentGeneralBillV2.aspx")


@pytest.mark.asyncio
async def test_fetch_page_redirected_to_login_is_expiry():
    resp = _Resp(text="ok", url="https://ucam.uiu.ac.bd/Security/Login.aspx")
    with pytest.raises(UcamSessionExpired):
        await navigator.fetch_page(_Session(resp), "/Bill/StudentGeneralBillV2.aspx")


@pytest.mark.asyncio
@pytest.mark.parametrize("code", [401, 403])
async def test_fetch_page_401_403_is_expiry(code):
    resp = _Resp(status_code=code, text="nope")
    with pytest.raises(UcamSessionExpired):
        await navigator.fetch_page(_Session(resp), "/Bill/StudentGeneralBillV2.aspx")


@pytest.mark.asyncio
async def test_fetch_page_real_html_returns_normally():
    # A genuine data page (not login) is returned as-is, no expiry.
    resp = _Resp(text='<table id="ctl00_MainContainer_gvStudentBillView"></table>')
    out = await navigator.fetch_page(_Session(resp), "/Bill/StudentGeneralBillV2.aspx")
    assert "gvStudentBillView" in out


@pytest.mark.asyncio
async def test_fetch_page_5xx_is_transient_not_expiry():
    # A server error is raised by raise_for_status (transient), NOT called expiry.
    resp = _Resp(status_code=500, text="boom")
    with pytest.raises(Exception) as ei:
        await navigator.fetch_page(_Session(resp), "/Bill/StudentGeneralBillV2.aspx")
    assert not isinstance(ei.value, UcamSessionExpired)

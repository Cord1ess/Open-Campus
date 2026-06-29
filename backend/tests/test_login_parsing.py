"""Offline tests for the UCAM login helpers: hidden-field scraping, ScriptManager
discovery, async-redirect parsing, and roll extraction. No live network.
"""
from __future__ import annotations

from app.ucam.client import (
    _extract_roll,
    _find_scriptmanager_field,
    _find_update_panel,
    _is_login_url,
    _looks_like_login_page,
    _parse_async_redirect,
    _scrape_hidden_fields,
)

LOGIN_HTML = """
<form name="frmLogIn" method="post" action="./Login.aspx" id="frmLogIn">
  <input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="ABC123" />
  <input type="hidden" name="__VIEWSTATEGENERATOR" value="A0A15FC2" />
  <input type="hidden" name="__PREVIOUSPAGE" value="PP" />
  <input name="logMain$UserName" type="text" />
  <input name="logMain$Password" type="password" />
  <script>
    Sys.WebForms.PageRequestManager._initialize('scMgtMas', 'frmLogIn', ...);
  </script>
</form>
"""

# A successful async postback response asks the client to redirect.
ASYNC_SUCCESS = (
    "123|pageRedirect||/Security/StudentHome.aspx?mmi=41485d2c6c554d494e63|"
)


def test_scrape_hidden_fields():
    fields = _scrape_hidden_fields(LOGIN_HTML)
    assert fields["__VIEWSTATE"] == "ABC123"
    assert fields["__VIEWSTATEGENERATOR"] == "A0A15FC2"
    assert "__PREVIOUSPAGE" in fields


def test_find_scriptmanager_field():
    assert _find_scriptmanager_field(LOGIN_HTML) == "scMgtMas"


def test_find_scriptmanager_missing_returns_none():
    assert _find_scriptmanager_field("<html></html>") is None


def test_find_update_panel_prefers_upMain_div():
    assert _find_update_panel('<div id="upMain">...</div>') == "upMain"


def test_find_update_panel_falls_back_to_default():
    # No panel markers at all -> verified default.
    assert _find_update_panel("<html></html>") == "upMain"


def test_is_login_url_precise():
    assert _is_login_url("/Security/Login.aspx") is True
    assert _is_login_url("https://ucam.uiu.ac.bd/Security/Login.aspx?x=1") is True
    # A legit post-login URL containing 'login' as a query value must NOT match.
    assert _is_login_url("/Security/StudentHome.aspx?ReturnUrl=/Login") is False
    assert _is_login_url("/Security/StudentHome.aspx") is False


def test_looks_like_login_page():
    assert _looks_like_login_page(LOGIN_HTML) is True
    assert _looks_like_login_page("<html>welcome home</html>") is False


def test_parse_async_redirect_success():
    url = _parse_async_redirect(ASYNC_SUCCESS)
    assert url == "/Security/StudentHome.aspx?mmi=41485d2c6c554d494e63"


def test_parse_async_redirect_url_encoded():
    # The live response gives the redirect percent-ENCODED; it must be decoded.
    enc = "123|pageRedirect||%2fSecurity%2fStudentHome.aspx%3fmmi%3dabc123|"
    assert _parse_async_redirect(enc) == "/Security/StudentHome.aspx?mmi=abc123"


def test_parse_async_redirect_none_when_absent():
    assert _parse_async_redirect("123|updatePanel|up1|<div>err</div>|") is None


def test_extract_roll_from_label_span():
    # The precise, verified location on the real StudentHome page.
    html = '<span id="ctl00_MainContainer_Label1">0112330000</span>'
    roll, how = _extract_roll(html)
    assert roll == "0112330000"
    assert how == "label_span"


def test_extract_roll_from_username_link():
    html = (
        "<a href=\"javascript:__doPostBack('ctl00$lbtnUserName','')\">"
        "0112330000</a>"
    )
    roll, how = _extract_roll(html)
    assert roll == "0112330000"
    assert how == "username_link"


def test_extract_roll_from_js_var():
    roll, how = _extract_roll("<script>var roll = '0112330000';</script>")
    assert roll == "0112330000"
    assert how == "js_var"


def test_extract_roll_fallback_pattern():
    roll, how = _extract_roll("<span>Student: 0112330000 - Fall 2025</span>")
    assert roll == "0112330000"
    assert how == "digit_fallback"


def test_extract_roll_none_when_absent():
    roll, how = _extract_roll("<html>no id here</html>")
    assert roll is None
    assert how == "none"

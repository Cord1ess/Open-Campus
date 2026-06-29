"""Generic ASP.NET WebForms postback driver.

Some UCAM pages (e.g. item-wise marks) reveal data only after a __doPostBack:
selecting a dropdown posts the whole form back to the same page, which re-renders
with new content. This helper reproduces that exactly:

  1. scrape all hidden fields (__VIEWSTATE, __VIEWSTATEGENERATOR, …) from the page
  2. set __EVENTTARGET to the control being changed + that control's new value
  3. POST the form back to the same URL
  4. return the new HTML (carry its fresh hidden fields forward for chained posts)

This is a normal full-page postback (not the AJAX async login flow), so the
response is the complete re-rendered HTML. Read-only: we only ever change view
filters (dropdowns), never submit a state-changing control.
"""
from __future__ import annotations

from selectolax.parser import HTMLParser

from app.ucam.client import UcamSession


def scrape_form_fields(html: str) -> dict[str, str]:
    """All <input type=hidden> name/value pairs + any <select> current values.
    This is the form state we echo back on a postback."""
    tree = HTMLParser(html)
    fields: dict[str, str] = {}
    for node in tree.css("input[type=hidden]"):
        name = node.attributes.get("name")
        if name:
            fields[name] = node.attributes.get("value") or ""
    # Include current select values so unrelated dropdowns keep their state.
    for sel in tree.css("select"):
        name = sel.attributes.get("name")
        if not name:
            continue
        chosen = ""
        for opt in sel.css("option"):
            if opt.attributes.get("selected") is not None:
                chosen = opt.attributes.get("value") or ""
                break
        fields[name] = chosen
    return fields


async def postback(
    session: UcamSession,
    page_url: str,
    html: str,
    *,
    event_target: str,
    control_name: str,
    value: str,
) -> str:
    """Perform one __doPostBack on `page_url`, changing `control_name` to `value`
    and triggering `event_target`. Returns the re-rendered HTML.

    `event_target` and `control_name` are usually the same (the dropdown's
    name, e.g. "ctl00$MainContainer$ddlAcaCalBatch")."""
    form = scrape_form_fields(html)
    form[control_name] = value
    form["__EVENTTARGET"] = event_target
    form["__EVENTARGUMENT"] = ""
    form["__LASTFOCUS"] = ""

    async with session.pacing():
        resp = await session.client.post(
            page_url,
            data=form,
            headers={
                "Content-Type": "application/x-www-form-urlencoded",
                "Referer": page_url,
                "Origin": session.client.base_url.scheme
                + "://"
                + session.client.base_url.host,
            },
        )
    resp.raise_for_status()
    return resp.text


def select_options(html: str, select_name: str) -> list[tuple[str, str]]:
    """Return [(value, label)] of a <select>, skipping placeholder options
    (value empty / '0' / '-1')."""
    tree = HTMLParser(html)
    sel = tree.css_first(f'select[name="{select_name}"]')
    if sel is None:
        return []
    out: list[tuple[str, str]] = []
    for opt in sel.css("option"):
        v = opt.attributes.get("value") or ""
        if v in ("", "0", "-1"):
            continue
        out.append((v, opt.text(strip=True)))
    return out

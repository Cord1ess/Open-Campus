#!/usr/bin/env python3
"""Deep, interactive capture of a single UCAM page (default: the bill page).

Unlike the httpx-based backend client, this drives a REAL browser (Playwright) so
JavaScript, AJAX, and modal/popup content all render — which is exactly what we
need to discover every data point, button, and modal that only appears after a
click.

What it does, one page at a time:
  1. Log in with YOUR OWN credentials (from env, never stored, never committed).
  2. Navigate to the target page via UCAM's own menu (so it carries the live
     mmi= nav token, same as the backend navigator).
  3. Capture a BASELINE: full rendered HTML, a screenshot, and a complete
     inventory of every interactive element (buttons, links, inputs, selects,
     grids, hidden fields, and the underlying data grid rows).
  4. Classify each clickable. Anything that looks like it launches a payment /
     gateway / submits money is RECORDED ONLY (its text + target), never clicked.
     Everything else (view / details / invoice / print-preview / expand /
     dropdown) is clicked one at a time, and the resulting modal / AJAX HTML +
     screenshot is captured, then the page is reset.
  5. Also records every network request/response the page makes (URLs + methods
     + status + content-type), so we learn which PageMethods / .aspx the page
     calls under the hood — the real map of "what data is available here".

Everything lands in backend/captures/<page>-<timestamp>/ which is gitignored and
blocked by tools/beta_check.py, because it contains your real financial data.

USAGE (from the repo root, with the backend venv active so Playwright is present):

    # credentials via env — NOT stored anywhere
    export OC_CAP_ID=<your student id>
    export OC_CAP_PW=<your password>
    python tools/deep_capture.py                 # captures the bill page
    python tools/deep_capture.py --page /Bill/StudentGeneralBillV2.aspx
    python tools/deep_capture.py --headed        # watch it run (default headless)
    python tools/deep_capture.py --list-only     # just inventory clickables, no clicks

Run `playwright install chromium` once if the browser binary is missing.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys
from pathlib import Path

try:
    from playwright.async_api import async_playwright, TimeoutError as PWTimeout
except ImportError:  # pragma: no cover
    print("Playwright is not installed. In the backend venv run:\n"
          "  pip install playwright && playwright install chromium")
    sys.exit(1)

# --- config (mirrors backend/app/config.py + client.py, kept standalone) ------
UCAM_BASE = "https://ucam.uiu.ac.bd"
LOGIN_PATH = "/Security/Login.aspx"
HOME_PATH = "/Security/StudentHome.aspx"
DEFAULT_PAGE = "/Bill/StudentGeneralBillV2.aspx"

# Login form fields (verified — see backend/app/ucam/client.py).
F_USER = "logMain$UserName"
F_PASS = "logMain$Password"
F_BUTTON = "logMain$Button1"

REPO_ROOT = Path(__file__).resolve().parent.parent
CAPTURE_ROOT = REPO_ROOT / "backend" / "captures"

# Text/patterns that mark a control as MONEY-MOVING → record only, never click.
_PAYMENT_RE = re.compile(
    r"\b(pay|payment|checkout|proceed|confirm|submit|gateway|sslcommerz|"
    r"bkash|nagad|rocket|card|online\s*pay|make\s*payment|pay\s*now)\b",
    re.IGNORECASE,
)
# Controls that are SAFE and informative to click (reveal data / modals).
_SAFE_HINT_RE = re.compile(
    r"\b(view|detail|details|invoice|receipt|print|preview|show|expand|"
    r"breakdown|history|info|more|open|statement|download)\b",
    re.IGNORECASE,
)


def _ts() -> str:
    # Playwright/OS time is fine here (this is a manual dev tool, not the app).
    import time
    return time.strftime("%Y%m%d-%H%M%S")


def _slug(page_path: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "-", page_path.strip("/")).strip("-").lower()


async def _login(page, student_id: str, password: str) -> None:
    """Perform the UCAM login in a real browser. The ASP.NET async postback and
    ViewState are handled by the page itself — we just fill and submit."""
    await page.goto(UCAM_BASE + LOGIN_PATH, wait_until="networkidle")
    # The fields' name attributes carry '$'; select by name.
    await page.fill(f'input[name="{F_USER}"]', student_id)
    await page.fill(f'input[name="{F_PASS}"]', password)
    # Click the login button and wait for the navigation to the landing page.
    async with page.expect_navigation(wait_until="networkidle", timeout=60000):
        await page.click(f'input[name="{F_BUTTON}"]')
    # Confirm we're authenticated (not bounced back to the login form).
    html = await page.content()
    if 'name="frmLogIn"' in html or f'name="{F_USER}"' in html:
        raise RuntimeError("Login failed — still on the login page. Check creds.")


async def _navigate_to_page(page, page_path: str) -> bool:
    """Find and follow the menu link to `page_path` so we land on it with the
    live mmi= token (a bare GET returns an empty shell). Falls back to a direct
    GET. Returns True if we appear to have reached a real (non-empty) page."""
    target_leaf = page_path.split("/")[-1].lower()  # e.g. studentgeneralbillv2.aspx
    # Look for any anchor whose href points at the target leaf (with or w/o mmi).
    # UCAM menus are nested; try up to a few hops by clicking hub links first.
    for _hop in range(4):
        links = await page.eval_on_selector_all(
            "a[href]",
            "els => els.map(e => ({href: e.href, text: (e.textContent||'').trim()}))",
        )
        # Direct hit?
        for lk in links:
            if target_leaf in lk["href"].lower():
                await page.goto(lk["href"], wait_until="networkidle")
                return await _looks_real(page, target_leaf)
        # Otherwise click a promising hub link (Bill/Finance/Account) and recurse.
        hub = next(
            (lk for lk in links
             if re.search(r"bill|finance|account|payment|fee",
                          lk["text"] + lk["href"], re.IGNORECASE)),
            None,
        )
        if hub is None:
            break
        try:
            await page.goto(hub["href"], wait_until="networkidle")
        except PWTimeout:
            break
    # Fallback: direct GET.
    await page.goto(UCAM_BASE + page_path, wait_until="networkidle")
    return await _looks_real(page, target_leaf)


async def _looks_real(page, target_leaf: str) -> bool:
    url = page.url.lower()
    html = (await page.content()).lower()
    return target_leaf in url and len(html) > 2000


async def _inventory(page) -> dict:
    """A complete inventory of everything on the page a human could see or click."""
    return await page.evaluate(
        r"""() => {
      const vis = el => {
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        return r.width>0 && r.height>0 && s.visibility!=='hidden' && s.display!=='none';
      };
      const txt = el => (el.innerText||el.value||el.textContent||'').trim().slice(0,200);
      const desc = el => ({
        tag: el.tagName.toLowerCase(),
        id: el.id||null,
        name: el.getAttribute('name')||null,
        type: el.getAttribute('type')||null,
        text: txt(el),
        href: el.getAttribute('href')||null,
        onclick: (el.getAttribute('onclick')||'').slice(0,300)||null,
        title: el.getAttribute('title')||null,
        visible: vis(el),
      });
      // Every clickable-ish control.
      const clickables = [...document.querySelectorAll(
        'a[href], button, input[type=button], input[type=submit], input[type=image], [onclick], [role=button]'
      )].map(desc);
      // All form inputs / selects (data entry + filters).
      const inputs = [...document.querySelectorAll('input, select, textarea')].map(el => ({
        ...desc(el),
        options: el.tagName==='SELECT'
          ? [...el.options].map(o=>({value:o.value,label:o.textContent.trim(),selected:o.selected}))
          : undefined,
        value: (el.type==='password') ? '***' : (el.value||null),
      }));
      // Every data table + its rows (the actual financial data points).
      const tables = [...document.querySelectorAll('table')].map(t => {
        const rows = [...t.querySelectorAll('tr')].map(tr =>
          [...tr.querySelectorAll('th,td')].map(c => (c.innerText||'').trim())
        ).filter(r => r.some(c=>c!==''));
        return { id: t.id||null, rowCount: rows.length, rows: rows.slice(0,200) };
      }).filter(t => t.rowCount>0);
      // Any element that reads like a labelled value (spans/labels with ids).
      const labelled = [...document.querySelectorAll('span[id],label[id],div[id]')]
        .filter(vis)
        .map(el => ({id: el.id, text: txt(el)}))
        .filter(x => x.text && x.text.length<120);
      // Modals/dialogs that may already be in the DOM (often hidden until shown).
      const dialogs = [...document.querySelectorAll(
        '[role=dialog], .modal, .ui-dialog, [id*=modal i], [id*=popup i], [id*=dialog i]'
      )].map(el => ({id: el.id||null, cls: el.className||null, visible: vis(el)}));
      return {
        url: location.href,
        title: document.title,
        clickables, inputs, tables, labelled, dialogs,
        counts: {clickables: clickables.length, inputs: inputs.length,
                 tables: tables.length, labelled: labelled.length, dialogs: dialogs.length},
      };
    }"""
    )


def _classify(el: dict) -> str:
    """'payment' (record-only), 'safe' (click + capture), or 'other' (skip click)."""
    blob = " ".join(str(el.get(k) or "") for k in ("text", "href", "onclick", "id", "name", "title"))
    if _PAYMENT_RE.search(blob):
        return "payment"
    if _SAFE_HINT_RE.search(blob):
        return "safe"
    # __doPostBack links that aren't payment are usually view/expand → safe-ish.
    if "__dopostback" in blob.lower():
        return "safe"
    return "other"


async def _capture_state(page, outdir: Path, name: str) -> dict:
    """Save the current rendered HTML + screenshot; return the inventory."""
    html = await page.content()
    (outdir / f"{name}.html").write_text(html, encoding="utf-8")
    try:
        await page.screenshot(path=str(outdir / f"{name}.png"), full_page=True)
    except Exception:
        pass
    inv = await _inventory(page)
    (outdir / f"{name}.inventory.json").write_text(
        json.dumps(inv, indent=2, ensure_ascii=False), encoding="utf-8")
    return inv


async def run(page_path: str, headed: bool, list_only: bool) -> int:
    student_id = os.environ.get("OC_CAP_ID")
    password = os.environ.get("OC_CAP_PW")
    if not student_id or not password:
        print("Set OC_CAP_ID and OC_CAP_PW in the environment (never stored).")
        return 2

    outdir = CAPTURE_ROOT / f"{_slug(page_path)}-{_ts()}"
    outdir.mkdir(parents=True, exist_ok=True)
    print(f"Capturing {page_path} -> {outdir.relative_to(REPO_ROOT)}")

    network: list[dict] = []

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=not headed)
        context = await browser.new_context(
            viewport={"width": 1440, "height": 2200},
            user_agent=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/126.0.0.0 Safari/537.36"),
        )
        page = await context.new_page()

        # Record every network call the page makes (the real endpoint map).
        page.on("response", lambda r: network.append({
            "url": r.url, "status": r.status,
            "type": r.headers.get("content-type", ""),
            "method": r.request.method,
        }))

        try:
            print("  logging in...")
            await _login(page, student_id, password)
            print("  navigating to target page...")
            ok = await _navigate_to_page(page, page_path)
            if not ok:
                print("  WARNING: page may be an empty shell (no mmi token found).")

            print("  capturing baseline state...")
            baseline = await _capture_state(page, outdir, "00-baseline")
            print(f"    found: {baseline['counts']}")

            # Classify every clickable.
            clickables = baseline["clickables"]
            classified = {"payment": [], "safe": [], "other": []}
            for el in clickables:
                classified[_classify(el)].append(el)
            print(f"    clickables: {len(classified['safe'])} safe, "
                  f"{len(classified['payment'])} PAYMENT (skipped), "
                  f"{len(classified['other'])} other")

            interactions = []
            if not list_only:
                # Click each SAFE, visible clickable one at a time; capture what
                # pops up (modal / AJAX re-render), then return to baseline.
                seen = set()
                idx = 0
                for el in classified["safe"]:
                    if not el.get("visible"):
                        continue
                    key = el.get("id") or el.get("onclick") or el.get("href") or el.get("text")
                    if not key or key in seen:
                        continue
                    seen.add(key)
                    idx += 1
                    label = (el.get("text") or el.get("id") or "el")[:40]
                    print(f"  [{idx}] clicking safe: {label!r}")
                    rec = {"element": el, "result": None}
                    try:
                        sel = _selector_for(el)
                        if sel is None:
                            rec["result"] = "no-selector"
                        else:
                            before = page.url
                            await page.click(sel, timeout=8000)
                            await page.wait_for_timeout(1200)  # let AJAX/modal render
                            snap = f"{idx:02d}-{_slug(label) or 'click'}"
                            await _capture_state(page, outdir, snap)
                            rec["result"] = "captured"
                            rec["snapshot"] = snap
                            # Reset: go back to the baseline page for the next click.
                            if page.url != before:
                                await page.go_back(wait_until="networkidle")
                            else:
                                # Modal opened in place — try to close it (Esc) or reload.
                                await page.keyboard.press("Escape")
                                await page.wait_for_timeout(300)
                    except Exception as exc:  # keep going; log the failure
                        rec["result"] = f"error: {exc}"
                    interactions.append(rec)

            # Write the master manifest.
            manifest = {
                "page_path": page_path,
                "captured_at": _ts(),
                "baseline_counts": baseline["counts"],
                "payment_buttons_recorded_not_clicked": classified["payment"],
                "safe_clickables": classified["safe"],
                "other_clickables": classified["other"],
                "interactions": interactions,
                "network": _dedupe_network(network),
                "data_tables": baseline["tables"],
                "labelled_values": baseline["labelled"],
                "form_inputs": baseline["inputs"],
            }
            (outdir / "manifest.json").write_text(
                json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
            print(f"\nDone. Manifest + captures in {outdir.relative_to(REPO_ROOT)}")
            print("Review manifest.json for every data point, button, modal, and "
                  "network call the page exposes.")
        finally:
            await context.close()
            await browser.close()
    return 0


def _selector_for(el: dict) -> str | None:
    """A Playwright selector that uniquely targets this element."""
    if el.get("id"):
        return f'#{_css_escape(el["id"])}'
    if el.get("name"):
        return f'[name="{el["name"]}"]'
    if el.get("href"):
        return f'a[href="{el["href"]}"]'
    return None


def _css_escape(s: str) -> str:
    # ASP.NET ids contain '_' only (safe); escape ':' etc. just in case.
    return re.sub(r'([:.\[\]$])', r'\\\1', s)


def _dedupe_network(network: list[dict]) -> list[dict]:
    seen, out = set(), []
    for n in network:
        # Drop static assets; keep the interesting app calls.
        if re.search(r"\.(png|jpg|jpeg|gif|svg|css|woff2?|ttf|ico)(\?|$)", n["url"], re.I):
            continue
        key = (n["method"], n["url"].split("?")[0], n["status"])
        if key in seen:
            continue
        seen.add(key)
        out.append(n)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Deep interactive capture of one UCAM page.")
    ap.add_argument("--page", default=DEFAULT_PAGE, help="UCAM .aspx path to capture.")
    ap.add_argument("--headed", action="store_true", help="Show the browser (default headless).")
    ap.add_argument("--list-only", action="store_true",
                    help="Only inventory clickables; don't click anything.")
    args = ap.parse_args()
    return asyncio.run(run(args.page, args.headed, args.list_only))


if __name__ == "__main__":
    sys.exit(main())

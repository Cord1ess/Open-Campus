"""StudentGeneralBillV2.aspx — itemized bill, authoritative totals, and the
online-payment gateways offered.

The summary input boxes carry UCAM's OWN computed totals as server-rendered
`value` attributes (verified via a real-browser capture):
  txtTotalFee, txtTotalDiscount, txtPaidAmount, txtBalance.
We read those when present (they're the authoritative figures UCAM shows), and
fall back to summing the grid rows if a field is missing. `balance` here comes
straight from txtBalance (negative = advance / credit).

Grid ctl00_MainContainer_gvStudentBillView — 10 positional columns:
  Sl | Fee Type | Course Code | Credit | Amount | Discount | Payment |
  Trimester Name | Date | Remark

The page also offers online payment via several gateways (bKash, Visa, Master,
DBBL Nexus, AmEx). We surface the list of accepted methods for display only —
the app deep-links to UCAM's own payment page rather than handling money itself.
"""
from __future__ import annotations

import re

from selectolax.parser import HTMLParser

from app.schemas.student import BillItem, BillResponse, PaymentMethod
from app.ucam.client import UcamSession
from app.ucam.navigator import fetch_page

_MC = "ctl00_MainContainer_"
_PATH = "/Bill/StudentGeneralBillV2.aspx"

# Gateway code (from the page's ShowGatewayModal(id,'code') calls) -> display name.
# Verified from the rendered payment panel. Display-only; the app never submits.
_GATEWAY_NAMES = {
    "bk": "bKash",
    "vs": "Visa",
    "ms": "Mastercard",
    "nx": "DBBL Nexus",
    "mx": "American Express",
}


async def fetch_bill_html(session: UcamSession) -> str:
    # Must use the live mmi-tokenized URL; a bare GET returns an empty shell.
    return await fetch_page(session, _PATH)


def _f(s: str | None) -> float | None:
    if not s:
        return None
    m = re.search(r"-?\d[\d,]*(?:\.\d+)?", s)
    return float(m.group(0).replace(",", "")) if m else None


def _input_value(tree: HTMLParser, node_id: str) -> float | None:
    """Read a numeric <input>'s server-rendered `value` (UCAM's own total)."""
    node = tree.css_first(f"#{node_id}")
    if node is None:
        return None
    return _f(node.attributes.get("value"))


def _parse_gateways(html: str) -> list[PaymentMethod]:
    """The accepted online-payment methods, from the ShowGatewayModal(id,'code')
    handlers on the gateway buttons. De-duplicated, in page order."""
    out: list[PaymentMethod] = []
    seen: set[str] = set()
    for m in re.finditer(r"ShowGatewayModal\(\s*\d+\s*,\s*'([a-z]{2})'\s*\)", html):
        code = m.group(1)
        if code in seen:
            continue
        seen.add(code)
        out.append(PaymentMethod(code=code, name=_GATEWAY_NAMES.get(code, code)))
    return out


def parse_bill(html: str) -> BillResponse:
    tree = HTMLParser(html)
    table = tree.css_first(f"#{_MC}gvStudentBillView")
    items: list[BillItem] = []
    if table is not None:
        for tr in table.css("tr"):
            cells = tr.css("td")
            # The header row uses <th> (no <td>), so it's skipped naturally. Data
            # rows have the 10 positional columns; tolerate EXTRA trailing columns
            # (some UCAM configs append a hidden/action cell) by reading the first
            # 10 rather than requiring exactly 10.
            if len(cells) < 10:
                continue
            c = [x.text(strip=True) for x in cells[:10]]

            def _clean(v: str) -> str | None:
                # Treat empty / non-breaking-space / lone-dash cells as absent.
                return v if v not in ("", "\xa0", "-", "--") else None

            items.append(
                BillItem(
                    fee_type=_clean(c[1]),
                    course_code=_clean(c[2]),
                    credit=_f(c[3]),
                    amount=_f(c[4]),
                    discount=_f(c[5]),
                    payment=_f(c[6]),
                    trimester=_clean(c[7]),
                    date=_clean(c[8]),
                    remark=_clean(c[9]),
                )
            )

    # Prefer UCAM's own computed totals (the txt* fields); fall back to summing
    # the grid when a field is absent. A legitimate zero stays 0.0, not None.
    grid_billed = sum((i.amount or 0) for i in items) if items else None
    grid_discount = sum((i.discount or 0) for i in items) if items else None
    grid_paid = sum((i.payment or 0) for i in items) if items else None

    total_billed = _input_value(tree, f"{_MC}txtTotalFee")
    if total_billed is None:
        total_billed = grid_billed
    total_discount = _input_value(tree, f"{_MC}txtTotalDiscount")
    if total_discount is None:
        total_discount = grid_discount
    total_paid = _input_value(tree, f"{_MC}txtPaidAmount")
    if total_paid is None:
        total_paid = grid_paid

    # txtBalance is UCAM's authoritative current balance (negative = advance).
    balance = _input_value(tree, f"{_MC}txtBalance")

    return BillResponse(
        total_billed=total_billed,
        total_discount=total_discount,
        total_paid=total_paid,
        balance=balance,
        items=items,
        payment_methods=_parse_gateways(html),
    )

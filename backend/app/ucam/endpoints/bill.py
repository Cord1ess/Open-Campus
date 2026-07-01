"""StudentGeneralBillV2.aspx — itemized bill + totals.

The summary input boxes (txtTotalFee etc.) are populated client-side via JS and
are EMPTY in the server HTML, so we compute totals from the line items instead.
The authoritative current balance also comes from the home summary
(FI_CurrentBalance); callers may prefer that.

Grid ctl00_MainContainer_gvStudentBillView — 10 positional columns:
  Sl | Fee Type | Course Code | Credit | Amount | Discount | Payment |
  Trimester Name | Date | Remark
"""
from __future__ import annotations

import re

from selectolax.parser import HTMLParser

from app.schemas.student import BillItem, BillResponse
from app.ucam.client import UcamSession
from app.ucam.navigator import fetch_page

_MC = "ctl00_MainContainer_"
_PATH = "/Bill/StudentGeneralBillV2.aspx"


async def fetch_bill_html(session: UcamSession) -> str:
    # Must use the live mmi-tokenized URL; a bare GET returns an empty shell.
    return await fetch_page(session, _PATH)


def _f(s: str | None) -> float | None:
    if not s:
        return None
    m = re.search(r"-?\d[\d,]*(?:\.\d+)?", s)
    return float(m.group(0).replace(",", "")) if m else None


def parse_bill(html: str) -> BillResponse:
    tree = HTMLParser(html)
    table = tree.css_first(f"#{_MC}gvStudentBillView")
    items: list[BillItem] = []
    if table is not None:
        for tr in table.css("tr"):
            cells = tr.css("td")
            if not cells or len(cells) < 10:
                continue
            c = [x.text(strip=True) for x in cells]
            items.append(
                BillItem(
                    fee_type=c[1] or None,
                    course_code=c[2] or None,
                    credit=_f(c[3]),
                    amount=_f(c[4]),
                    discount=_f(c[5]),
                    payment=_f(c[6]),
                    trimester=c[7] or None,
                    date=c[8] or None,
                    remark=(c[9] or None) if c[9] not in ("", "\xa0") else None,
                )
            )

    # Totals from the line items, for display. NOTE: these are sums over the
    # whole bill history and don't always reconcile to the live balance (the
    # authoritative current balance is the home page's FI_CurrentBalance), so
    # `balance` is intentionally left None here — the route fills it from home.
    # Use None only when there are NO items at all; a legitimate zero total (e.g.
    # a student with no discounts) must stay 0.0, not collapse to "—" in the app.
    total_billed = sum((i.amount or 0) for i in items) if items else None
    total_discount = sum((i.discount or 0) for i in items) if items else None
    total_paid = sum((i.payment or 0) for i in items) if items else None

    return BillResponse(
        total_billed=total_billed,
        total_discount=total_discount,
        total_paid=total_paid,
        balance=None,
        items=items,
    )

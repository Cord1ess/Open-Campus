"""Bill-parsing tests: money parsing (commas, signs), the 10-column grid, the
\\xa0 remark handling, and the zero-vs-None totals policy.
"""
from __future__ import annotations

from app.ucam.endpoints.bill import _f, parse_bill


def test_money_parse_handles_commas_and_signs():
    assert _f("1,234.50") == 1234.5
    assert _f("-25") == -25.0
    assert _f("0") == 0.0
    assert _f("") is None
    assert _f(None) is None
    assert _f("\xa0") is None


def _grid(rows: str) -> str:
    return (
        '<table id="ctl00_MainContainer_gvStudentBillView">'
        + rows
        + "</table>"
    )


def _row(cells: list[str]) -> str:
    return "<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>"


def test_parse_bill_reads_ten_columns():
    html = _grid(
        _row(["1", "Tuition Fee", "CSE 2217", "3", "19,500", "0", "0",
              "[261] Spring 2026", "25-Feb-26", "\xa0"])
        + _row(["2", "Student Payment", "", "", "0", "0", "10,000",
                "[261] Spring 2026", "01-Mar-26", "paid"])
    )
    bill = parse_bill(html)
    assert len(bill.items) == 2
    charge = bill.items[0]
    assert charge.fee_type == "Tuition Fee"
    assert charge.course_code == "CSE 2217"
    assert charge.amount == 19500.0
    assert charge.remark is None  # \xa0 → None
    payment = bill.items[1]
    assert payment.payment == 10000.0
    assert payment.remark == "paid"
    # Totals summed over items.
    assert bill.total_billed == 19500.0
    assert bill.total_paid == 10000.0


def test_parse_bill_empty_grid_totals_are_none():
    # No items → totals are None (so the app shows "—"), not 0.
    bill = parse_bill(_grid(""))
    assert bill.items == []
    assert bill.total_billed is None
    assert bill.total_paid is None


def test_parse_bill_zero_total_stays_zero_not_none():
    # A student with items but no discounts: total_discount must be 0.0, NOT None
    # (the old `sum(...) or None` collapsed a legit zero to "—").
    html = _grid(
        _row(["1", "Tuition Fee", "CSE 2217", "3", "19,500", "0", "0",
              "[261] Spring 2026", "25-Feb-26", ""])
    )
    bill = parse_bill(html)
    assert bill.total_discount == 0.0


def test_parse_bill_skips_short_rows():
    # A malformed row with < 10 cells is skipped, not crashed on.
    html = _grid("<tr><td>only</td><td>two</td></tr>")
    assert parse_bill(html).items == []

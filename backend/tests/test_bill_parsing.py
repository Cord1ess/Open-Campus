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


_MC = "ctl00_MainContainer_"


def _totals(billed="", discount="", paid="", balance="") -> str:
    """The server-rendered summary input boxes (UCAM's own computed totals)."""
    def inp(name, val):
        return f'<input id="{_MC}{name}" type="text" value="{val}">'
    return (inp("txtTotalFee", billed) + inp("txtTotalDiscount", discount)
            + inp("txtPaidAmount", paid) + inp("txtBalance", balance))


def test_parse_bill_prefers_authoritative_totals_over_grid_sum():
    # Grid sums to 100 billed, but UCAM's own txt* totals say 579,275 / -25 —
    # we must trust UCAM's figures, not the row sum.
    html = _totals(billed="579,275.00", discount="-123,622.00",
                   paid="455,678.00", balance="-25.00") + _grid(
        _row(["1", "Tuition Fee", "X", "3", "100", "0", "0", "t", "d", ""])
    )
    bill = parse_bill(html)
    assert bill.total_billed == 579275.0
    assert bill.total_discount == -123622.0
    assert bill.total_paid == 455678.0
    assert bill.balance == -25.0            # negative = advance (no due)


def test_parse_bill_falls_back_to_grid_when_totals_absent():
    # No txt* fields (older/JS-only render) -> sum the grid, balance stays None
    # so the route fills it from the home page.
    html = _grid(_row(["1", "Tuition Fee", "X", "3", "19,500", "0", "0",
                       "t", "d", ""]))
    bill = parse_bill(html)
    assert bill.total_billed == 19500.0
    assert bill.balance is None


def test_parse_bill_tolerates_extra_trailing_columns():
    # Some accounts/config append a hidden action cell — read the first 10.
    html = _grid(
        "<tr>"
        + "".join(f"<td>{c}</td>" for c in
                  ["1", "Tuition Fee", "CSE 2217", "3", "19,500", "0", "0",
                   "2026 Spring", "25-Feb-26", "", "<hidden>", "x"])
        + "</tr>"
    )
    bill = parse_bill(html)
    assert len(bill.items) == 1
    assert bill.items[0].amount == 19500.0
    assert bill.items[0].trimester == "2026 Spring"


def test_parse_bill_cleans_dash_and_nbsp_cells():
    # A course-less payment row often has "-" / nbsp placeholders.
    html = _grid(
        _row(["1", "Student Payment", "-", "0", "\xa0", "--", "10,000",
              "", "10-Jan-26", ""])
    )
    item = parse_bill(html).items[0]
    assert item.course_code is None      # "-" cleaned
    assert item.amount is None           # nbsp cleaned
    assert item.discount is None         # "--" cleaned
    assert item.payment == 10000.0
    assert item.trimester is None        # empty term (payment) cleaned


def test_parse_bill_discount_only_row():
    # A retake/waiver row: only a (negative) discount, no amount, no payment.
    html = _grid(
        _row(["1", "Retake Discount", "MATH 2183", "0", "", "-8,287.50", "",
              "2025 Fall", "09-Nov-25", "50% Discount"])
    )
    item = parse_bill(html).items[0]
    assert item.amount is None
    assert item.payment is None
    assert item.discount == -8287.5
    assert item.remark == "50% Discount"


def test_parse_bill_extracts_payment_gateways():
    # The gateway buttons call ShowGatewayModal(id,'code'); we surface the codes.
    html = _totals(balance="0") + _grid("") + (
        '<img onclick="ShowGatewayModal(4,\'bk\')">'
        '<img onclick="ShowGatewayModal(1,\'vs\')">'
        '<img onclick="ShowGatewayModal(2,\'ms\')">'
        '<img onclick="ShowGatewayModal(3,\'nx\')">'
        '<img onclick="ShowGatewayModal(5,\'mx\')">'
        # duplicate (the radio button) must not double-count
        '<input onclick="ShowGatewayModal(4,\'bk\');">'
    )
    methods = parse_bill(html).payment_methods
    codes = [m.code for m in methods]
    assert codes == ["bk", "vs", "ms", "nx", "mx"]  # order preserved, de-duped
    names = {m.code: m.name for m in methods}
    assert names["bk"] == "bKash"
    assert names["nx"] == "DBBL Nexus"

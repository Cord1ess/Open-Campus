// Bill model — mirrors GET /student/bill.

double? _numN(dynamic v) => v is num
    ? v.toDouble()
    // Strip comma thousands-separators so "6,500" parses (the backend sends bare
    // numbers, but a cached/edge payload may carry a formatted string).
    : (v is String ? double.tryParse(v.replaceAll(',', '')) : null);
String? _strN(dynamic v) => v?.toString();

const _monthByAbbr = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  // Full names too, in case a locale/config renders them.
  'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
  'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11,
  'december': 12,
};

int? _normYear(int y) {
  if (y >= 1000) return y; // 4-digit
  if (y < 100) return 2000 + y; // 2-digit -> 2000-based (no pre-2000 records)
  return null;
}

/// Parse a UCAM bill date into a DateTime, defensively across the formats
/// different accounts / config could produce:
///   "25-Feb-26" / "25-Feb-2026"    (day-month-year, the common form)
///   "25/02/2026" / "25-02-26"      (numeric day-month-year)
///   "2026-02-25"                    (ISO year-month-day)
/// Returns null if absent or unrecognizable (callers sort those to the end).
DateTime? _parseBillDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  // 1) DD-MMM-YY(YY) with a month NAME.
  var m = RegExp(r'^(\d{1,2})[-/\s]([A-Za-z]{3,})[-/\s](\d{2,4})$').firstMatch(s);
  if (m != null) {
    final day = int.tryParse(m.group(1)!);
    final month = _monthByAbbr[m.group(2)!.toLowerCase()];
    final year = int.tryParse(m.group(3)!);
    if (day != null && month != null && year != null) {
      final y = _normYear(year);
      if (y != null) return _safeDate(y, month, day);
    }
  }
  // 2) ISO YYYY-MM-DD.
  m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(s);
  if (m != null) {
    return _safeDate(int.parse(m.group(1)!), int.parse(m.group(2)!),
        int.parse(m.group(3)!));
  }
  // 3) Numeric DD-MM-YY(YY) (day first, as UCAM is BD-locale).
  m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$').firstMatch(s);
  if (m != null) {
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final year = _normYear(int.parse(m.group(3)!));
    if (year != null) return _safeDate(year, month, day);
  }
  return null;
}

/// Build a DateTime only if the components are in range, else null (so a stray
/// "31-02-26" doesn't silently roll over to March and reorder the statement).
DateTime? _safeDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  return (d.year == year && d.month == month && d.day == day) ? d : null;
}

// UIU trimester order within a year (Spring is first, then Summer, then Fall).
const _seasonOrder = {'spring': 1, 'summer': 2, 'fall': 3, 'autumn': 3};

/// A monotonically-increasing rank for a trimester NAME so newer terms sort
/// higher, regardless of format:
///   "[261] Spring 2026"  -> the bracket code 261 dominates (already ordinal).
///   "2026 Spring" / "Spring 2026" -> year*10 + season order.
/// Unknown formats fall back to any leading number, else -1 (sorts oldest).
int _termRank(String term) {
  final t = term.toLowerCase();
  // Bracketed numeric code, e.g. "[261] ..." — UCAM's own ordinal term id.
  final bracket = RegExp(r'\[(\d{2,4})\]').firstMatch(t);
  if (bracket != null) {
    final code = int.tryParse(bracket.group(1)!);
    if (code != null) return 100000 + code; // keep above the year-based space
  }
  // Year + season (either order).
  final year = RegExp(r'\b(20\d{2})\b').firstMatch(t);
  int? season;
  for (final e in _seasonOrder.entries) {
    if (t.contains(e.key)) {
      season = e.value;
      break;
    }
  }
  if (year != null) {
    return int.parse(year.group(1)!) * 10 + (season ?? 0);
  }
  // Last resort: any leading number (guarded against overflow).
  final n = RegExp(r'\d+').firstMatch(t);
  return n != null ? (int.tryParse(n.group(0)!) ?? -1) : -1;
}

/// What a bill row represents. UCAM rows come in three real shapes:
///   payment    — money received (payment column set)
///   charge     — a fee billed (amount column set)
///   adjustment — a waiver/discount/reversal with no amount or payment, only a
///                discount value (e.g. "Retake Discount -8,287.5"). These vary a
///                lot between students, so they get their own kind rather than
///                being mistaken for a zero-amount charge.
enum BillKind { payment, charge, adjustment }

class BillItem {
  final String? feeType;
  final String? courseCode;
  final double? credit;
  final double? amount;
  final double? discount;
  final double? payment;
  final String? trimester;
  final String? date;
  final String? remark;

  const BillItem({
    this.feeType,
    this.courseCode,
    this.credit,
    this.amount,
    this.discount,
    this.payment,
    this.trimester,
    this.date,
    this.remark,
  });

  /// Classify robustly for any account. A payment is anything with a non-zero
  /// payment value; a row with a real charge amount is a charge; anything left
  /// that carries only a discount/waiver is an adjustment. Rows with none of
  /// the three still default to charge (so they're at least shown), but their
  /// amount will render as "—".
  BillKind get kind {
    if ((payment ?? 0).abs() > 0) return BillKind.payment;
    if ((amount ?? 0).abs() > 0) return BillKind.charge;
    if ((discount ?? 0).abs() > 0) return BillKind.adjustment;
    return BillKind.charge;
  }

  bool get isPayment => kind == BillKind.payment;
  bool get isAdjustment => kind == BillKind.adjustment;

  /// The signed amount this row moves against the balance: payments and
  /// waivers/discounts REDUCE what's owed (negative), charges INCREASE it.
  /// Used for per-term net math that must hold for any mix of rows.
  double get signedAmount {
    switch (kind) {
      case BillKind.payment:
        return -(payment ?? 0).abs();
      case BillKind.adjustment:
        // Discount is already stored negative by UCAM; normalize to a reduction.
        return -((discount ?? 0).abs());
      case BillKind.charge:
        return (amount ?? 0);
    }
  }

  /// Parse UCAM's date (e.g. "25-Feb-26") into a DateTime for chronological
  /// ordering. Null if absent/unparseable (sorts to the end).
  DateTime? get parsedDate => _parseBillDate(date);

  factory BillItem.fromJson(Map<String, dynamic> j) => BillItem(
        feeType: _strN(j['fee_type']),
        courseCode: _strN(j['course_code']),
        credit: _numN(j['credit']),
        amount: _numN(j['amount']),
        discount: _numN(j['discount']),
        payment: _numN(j['payment']),
        trimester: _strN(j['trimester']),
        date: _strN(j['date']),
        remark: _strN(j['remark']),
      );

  Map<String, dynamic> toJson() => {
        'fee_type': feeType,
        'course_code': courseCode,
        'credit': credit,
        'amount': amount,
        'discount': discount,
        'payment': payment,
        'trimester': trimester,
        'date': date,
        'remark': remark,
      };
}

/// An online-payment method UCAM accepts (display only — the app deep-links to
/// UCAM's own payment page rather than handling money).
class PaymentMethod {
  final String code; // "bk", "vs", "ms", "nx", "mx"
  final String name; // "bKash", "Visa", ...
  const PaymentMethod({required this.code, required this.name});

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
        code: _strN(j['code']) ?? '',
        name: _strN(j['name']) ?? '',
      );

  Map<String, dynamic> toJson() => {'code': code, 'name': name};
}

class BillData {
  final double? totalBilled;
  final double? totalDiscount;
  final double? totalPaid;
  final double? balance; // >0 due, <0 advance
  final List<BillItem> items;
  final List<PaymentMethod> paymentMethods;

  const BillData({
    this.totalBilled,
    this.totalDiscount,
    this.totalPaid,
    this.balance,
    this.items = const [],
    this.paymentMethods = const [],
  });

  bool get hasDue => (balance ?? 0) > 0;

  /// Items grouped by trimester (in arrival order).
  Map<String, List<BillItem>> get byTrimester {
    final map = <String, List<BillItem>>{};
    for (final i in items) {
      (map[i.trimester ?? 'Payments'] ??= []).add(i);
    }
    return map;
  }

  /// A statement view: every transaction grouped under the trimester it belongs
  /// to, newest trimester first, and within each trimester a single
  /// date-descending stream of bills AND payments interleaved (as UCAM shows).
  ///
  /// Bills carry an explicit trimester. Payments do NOT (UCAM leaves the term
  /// blank on a payment), so each payment is assigned to the trimester it
  /// *follows* chronologically: the most recent term whose bills predate the
  /// payment. A payment made before any billed term falls into the earliest
  /// term. This reconstructs UCAM's own layout, which the flat feed lost.
  /// A bucket key for transactions that have no trimester and no billed term to
  /// attach to (e.g. a student who has only made payments, or payments made
  /// before any course was billed). Kept distinct so it never collides with a
  /// real term name.
  static const paymentsBucket = 'Payments';

  bool _hasTerm(BillItem i) => i.trimester != null && i.trimester!.trim().isNotEmpty;

  Map<String, List<BillItem>> get statementByTrimester {
    if (items.isEmpty) return {};

    // Stable index so undated / same-date rows keep their original UCAM order
    // (which is newest-first) instead of shuffling non-deterministically.
    final indexed = [
      for (var k = 0; k < items.length; k++) (idx: k, item: items[k])
    ];

    // 1) Oldest -> newest for the assignment walk. Undated rows are treated as
    //    OLDEST here so a payment with a missing date still lands in a sensible
    //    term rather than jumping to the front; ties break by original index.
    final ascending = [...indexed];
    ascending.sort((a, b) {
      final da = a.item.parsedDate, db = b.item.parsedDate;
      if (da != null && db != null && da != db) return da.compareTo(db);
      if (da == null && db != null) return -1; // undated first (oldest)
      if (da != null && db == null) return 1;
      // both dated-equal or both undated: preserve UCAM order. UCAM is
      // newest-first, so a HIGHER original index is OLDER -> sort descending idx.
      return b.idx.compareTo(a.idx);
    });

    // 2) Earliest real trimester (first billed term chronologically), used for
    //    any transaction that predates all billed terms.
    String? earliestTerm;
    for (final e in ascending) {
      if (_hasTerm(e.item) && !e.item.isPayment) {
        earliestTerm = e.item.trimester!.trim();
        break;
      }
    }

    // 3) Walk oldest->newest, carrying the "current" term forward; assign each
    //    tagless row (payment/adjustment) to it. If there is NO billed term at
    //    all (payments-only account), everything falls into the payments bucket.
    final assigned = <String, List<BillItem>>{};
    String? current = earliestTerm;
    for (final e in ascending) {
      final i = e.item;
      if (_hasTerm(i) && !i.isPayment) current = i.trimester!.trim();
      final key = _hasTerm(i)
          ? i.trimester!.trim()
          : (current ?? paymentsBucket);
      (assigned[key] ??= []).add(i);
    }

    // 4) Within each term, newest first (date-descending); undated rows keep
    //    UCAM's newest-first position (shown first). Then order the term keys
    //    newest-first by their latest dated transaction; the payments-only
    //    bucket (no dates) sorts last.
    DateTime latest(List<BillItem> l) {
      DateTime? best;
      for (final i in l) {
        final d = i.parsedDate;
        if (d == null) continue;
        if (best == null || d.isAfter(best)) best = d;
      }
      return best ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    for (final l in assigned.values) {
      // Build the same stable index within this bucket to break ties.
      final withIdx = [for (var k = 0; k < l.length; k++) (idx: k, item: l[k])];
      withIdx.sort((a, b) {
        final da = a.item.parsedDate, db = b.item.parsedDate;
        if (da != null && db != null && da != db) return db.compareTo(da);
        if (da == null && db != null) return -1; // undated shown first (newest)
        if (da != null && db == null) return 1;
        return a.idx.compareTo(b.idx); // preserve within-bucket order
      });
      l
        ..clear()
        ..addAll(withIdx.map((e) => e.item));
    }

    final keys = assigned.keys.toList()
      ..sort((a, b) => latest(assigned[b]!).compareTo(latest(assigned[a]!)));
    return {for (final k in keys) k: assigned[k]!};
  }

  /// The most recent trimester key, chosen deterministically rather than relying
  /// on backend ordering. Works across the term-name formats different UCAM
  /// pages / accounts use:
  ///   "[261] Spring 2026"  -> uses the embedded numeric code (higher = newer)
  ///   "2026 Spring"        -> uses year + season order (the bill-page format)
  String? get currentTrimester {
    final terms = <String>[];
    for (final i in items) {
      final t = i.trimester?.trim();
      if (t != null && t.isNotEmpty && t != paymentsBucket && !terms.contains(t)) {
        terms.add(t);
      }
    }
    if (terms.isEmpty) return null;
    terms.sort((a, b) => _termRank(b).compareTo(_termRank(a)));
    return terms.first;
  }

  factory BillData.fromJson(Map<String, dynamic> j) => BillData(
        totalBilled: _numN(j['total_billed']),
        totalDiscount: _numN(j['total_discount']),
        totalPaid: _numN(j['total_paid']),
        balance: _numN(j['balance']),
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => BillItem.fromJson(e.cast<String, dynamic>()))
            .toList(),
        paymentMethods: ((j['payment_methods'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => PaymentMethod.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'total_billed': totalBilled,
        'total_discount': totalDiscount,
        'total_paid': totalPaid,
        'balance': balance,
        'items': items.map((e) => e.toJson()).toList(),
        'payment_methods': paymentMethods.map((e) => e.toJson()).toList(),
      };
}

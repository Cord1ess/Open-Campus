// Bill model — mirrors GET /student/bill.

double? _numN(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String? _strN(dynamic v) => v?.toString();

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

  bool get isPayment => (payment ?? 0) > 0;

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

class BillData {
  final double? totalBilled;
  final double? totalDiscount;
  final double? totalPaid;
  final double? balance; // >0 due, <0 advance
  final List<BillItem> items;

  const BillData({
    this.totalBilled,
    this.totalDiscount,
    this.totalPaid,
    this.balance,
    this.items = const [],
  });

  bool get hasDue => (balance ?? 0) > 0;

  /// Items grouped by trimester (newest groups first as they appear).
  Map<String, List<BillItem>> get byTrimester {
    final map = <String, List<BillItem>>{};
    for (final i in items) {
      (map[i.trimester ?? 'Payments'] ??= []).add(i);
    }
    return map;
  }

  factory BillData.fromJson(Map<String, dynamic> j) => BillData(
        totalBilled: _numN(j['total_billed']),
        totalDiscount: _numN(j['total_discount']),
        totalPaid: _numN(j['total_paid']),
        balance: _numN(j['balance']),
        items: ((j['items'] as List?) ?? const [])
            .map((e) => BillItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'total_billed': totalBilled,
        'total_discount': totalDiscount,
        'total_paid': totalPaid,
        'balance': balance,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

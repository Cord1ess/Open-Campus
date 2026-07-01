// UIU installment payment logic. See memory: uiu-grading-finance-rules.
//
// NOTE: this is the OFFICIAL UIU 40/70/100 cumulative-threshold plan, shown on
// the live Balance & Dues page (bill_page.dart) for a registered fee. It is
// DELIBERATELY DIFFERENT from tuition.dart's installment split (40% then the
// remainder halved), which is a faithful port of the reference *manual*
// calculator. Do not "reconcile" the two — they model different things.
//
// From the registered Tuition+Trimester fee, students may pay in 3 installments:
//   1st: 40% by date (else ৳500 fine)
//   2nd: 70% cumulative by date (else ৳500 fine)
//   3rd: 100% by date (else ৳500 fine)
// 252-and-onward students also pay ৳20,000 at registration (counts toward the
// total). Transport/Gym fees (if any) are paid in full by the 1st date.
//
// Dates come from the academic calendar (not captured yet) — scaffolded.

class Installment {
  final int number; // 1, 2, 3
  final double cumulativePercent; // 40 / 70 / 100
  final double cumulativeAmount; // total that must be paid by this point
  final double thisInstallment; // incremental amount for this installment
  final double fineIfLate; // ৳500
  final String? dateLabel; // null until calendar wired

  const Installment({
    required this.number,
    required this.cumulativePercent,
    required this.cumulativeAmount,
    required this.thisInstallment,
    required this.fineIfLate,
    this.dateLabel,
  });
}

class InstallmentPlan {
  final double tuitionTrimesterFee; // the amount installments are computed on
  final double registrationPayment; // ৳20,000 for 252+ else 0
  final List<Installment> installments;
  final double finePerMiss;

  const InstallmentPlan({
    required this.tuitionTrimesterFee,
    required this.registrationPayment,
    required this.installments,
    required this.finePerMiss,
  });
}

const double _fine = 500;
const double _reg252 = 20000;

/// Build the 40/70/100 installment plan for a registered fee.
/// [is252OrLater] adds the ৳20,000 registration payment (which counts toward the
/// total already paid, reducing what's left for the percentage thresholds).
InstallmentPlan buildInstallmentPlan(
  double tuitionTrimesterFee, {
  bool is252OrLater = true,
  List<String?> dateLabels = const [null, null, null],
}) {
  const percents = [40.0, 70.0, 100.0];
  final reg = is252OrLater ? _reg252 : 0.0;
  final installments = <Installment>[];
  double prevCumulative = reg; // registration payment already counts
  for (var i = 0; i < percents.length; i++) {
    final cumAmount = tuitionTrimesterFee * percents[i] / 100;
    // What still needs paying for THIS installment, on top of what's required so
    // far (and after the registration payment already made).
    final thisAmt =
        (cumAmount - prevCumulative).clamp(0, double.infinity).toDouble();
    installments.add(Installment(
      number: i + 1,
      cumulativePercent: percents[i],
      cumulativeAmount: cumAmount,
      thisInstallment: thisAmt,
      fineIfLate: _fine,
      dateLabel: i < dateLabels.length ? dateLabels[i] : null,
    ));
    prevCumulative = cumAmount > prevCumulative ? cumAmount : prevCumulative;
  }
  return InstallmentPlan(
    tuitionTrimesterFee: tuitionTrimesterFee,
    registrationPayment: reg,
    installments: installments,
    finePerMiss: _fine,
  );
}

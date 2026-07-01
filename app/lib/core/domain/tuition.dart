// UIU tuition-fee domain — a pure port of the reference calculator
// (github.com/kawsarcodes/uiu-calculator, calculateTuitionFee) so the manual
// Tuition tool computes fees the same way, but as testable Dart with no UI.
//
// Policy summary (UIU):
//   • Tuition  = credits × per-credit fee, by course type.
//   • Discounts apply to NEW-course tuition. Waiver vs Scholarship: the higher of
//     the two is used; BUT scholarship is capped at the first 13 credits — any
//     credits beyond 13 fall back to the waiver rate (the "hybrid" rule).
//   • First-time retakes get a flat 50% off. Second+ retakes get no discount.
//   • Extra waivers (sibling/spouse, ethnic/tribal, disability) stack on new
//     tuition, but total new-course discount can't exceed the new tuition.
//   • Admin = trimester fee + (late fee 500 if late registration).
//   • Installments: 1st = 40% (of gross, or of net if waiverInFirstInstallment),
//     remainder split 50/50 across 2nd & 3rd.
//
// NOTE: this 40-then-split model is the REFERENCE manual calculator's, and is
// intentionally different from the official UIU 40/70/100 cumulative-threshold
// plan in installments.dart (used on the live Balance & Dues page). Two distinct
// tools, two models — don't merge them.

import 'dart:math' as math;

const double lateRegistrationFee = 500;
const int scholarshipCreditCap = 13; // scholarship applies to first 13 credits

/// All inputs to a tuition estimate. Percentages are 0–100.
class TuitionInput {
  final double newCredits;
  final double retakeFirstCredits; // first-time retake (50% off)
  final double retakeRegularCredits; // 2nd+ retake (no discount)
  final double perCreditFee;
  final double trimesterFee;
  final double waiverPercent;
  final double scholarshipPercent;
  final double siblingSpouseWaiver;
  final double ethnicTribalWaiver;
  final double disabilityWaiver;
  final bool lateRegistration;
  final bool waiverInFirstInstallment;

  const TuitionInput({
    this.newCredits = 0,
    this.retakeFirstCredits = 0,
    this.retakeRegularCredits = 0,
    this.perCreditFee = 6500,
    this.trimesterFee = 6500,
    this.waiverPercent = 0,
    this.scholarshipPercent = 0,
    this.siblingSpouseWaiver = 0,
    this.ethnicTribalWaiver = 0,
    this.disabilityWaiver = 0,
    this.lateRegistration = false,
    this.waiverInFirstInstallment = false,
  });
}

/// A single labelled discount line for the breakdown.
class DiscountLine {
  final String label;
  final String description;
  final double amount;
  const DiscountLine(this.label, this.description, this.amount);
}

class TuitionResult {
  final double newTuition;
  final double retakeFirstTuition;
  final double retakeRegularTuition;
  final double adminFees; // trimester + late
  final double grossTotal; // before discounts
  final List<DiscountLine> discounts;
  final double totalDiscount;
  final double netPayable;
  final double firstInstallment;
  final double secondInstallment;
  final double thirdInstallment;
  final String installmentMethod;
  /// True when the only thing left to pay is admin fees (100% tuition waived).
  final bool onlyAdminFee;

  const TuitionResult({
    required this.newTuition,
    required this.retakeFirstTuition,
    required this.retakeRegularTuition,
    required this.adminFees,
    required this.grossTotal,
    required this.discounts,
    required this.totalDiscount,
    required this.netPayable,
    required this.firstInstallment,
    required this.secondInstallment,
    required this.thirdInstallment,
    required this.installmentMethod,
    required this.onlyAdminFee,
  });
}

TuitionResult calculateTuition(TuitionInput i) {
  final feeNew = i.newCredits * i.perCreditFee;
  final feeRetake1 = i.retakeFirstCredits * i.perCreditFee;
  final feeRetakeReg = i.retakeRegularCredits * i.perCreditFee;
  final lateFee = i.lateRegistration ? lateRegistrationFee : 0.0;
  final admin = i.trimesterFee + lateFee;
  final gross = feeNew + feeRetake1 + feeRetakeReg + admin;

  final discounts = <DiscountLine>[];

  // New-course discount: waiver vs scholarship, with the 13-credit hybrid rule.
  double newRegularDiscount;
  if (i.waiverPercent >= i.scholarshipPercent) {
    newRegularDiscount = feeNew * i.waiverPercent / 100;
    if (i.waiverPercent > 0) {
      discounts.add(DiscountLine(
          'Waiver', '${_pct(i.waiverPercent)} on new courses', newRegularDiscount));
    }
  } else {
    if (i.newCredits <= scholarshipCreditCap) {
      newRegularDiscount = feeNew * i.scholarshipPercent / 100;
      if (i.scholarshipPercent > 0) {
        discounts.add(DiscountLine('Scholarship',
            '${_pct(i.scholarshipPercent)} on new courses', newRegularDiscount));
      }
    } else {
      // Scholarship on the first 13 credits, waiver on the rest.
      final feeFor13 = scholarshipCreditCap * i.perCreditFee;
      final part1 = feeFor13 * i.scholarshipPercent / 100;
      final remainingCredits = i.newCredits - scholarshipCreditCap;
      final part2 = remainingCredits * i.perCreditFee * i.waiverPercent / 100;
      newRegularDiscount = part1 + part2;
      discounts.add(DiscountLine('Scholarship (first 13 cr)',
          '${_pct(i.scholarshipPercent)} on first 13 credits', part1));
      if (i.waiverPercent > 0) {
        discounts.add(DiscountLine('Waiver (remaining)',
            '${_pct(i.waiverPercent)} on ${_cr(remainingCredits)} credits', part2));
      }
    }
  }

  final discSibling = feeNew * i.siblingSpouseWaiver / 100;
  final discEthnic = feeNew * i.ethnicTribalWaiver / 100;
  final discDisability = feeNew * i.disabilityWaiver / 100;
  final discRetake1 = feeRetake1 * 0.5; // first retake: flat 50% off

  // Total new-course discount can't exceed the new tuition itself.
  final totalNewDiscount = math.min(
      feeNew, newRegularDiscount + discSibling + discEthnic + discDisability);

  if (i.retakeFirstCredits > 0) {
    discounts.add(DiscountLine(
        'Retake waiver', '50% on first-time retakes', discRetake1));
  }
  if (i.siblingSpouseWaiver > 0) {
    discounts.add(DiscountLine('Sibling/Spouse waiver',
        '${_pct(i.siblingSpouseWaiver)} on new courses', discSibling));
  }
  if (i.ethnicTribalWaiver > 0) {
    discounts.add(DiscountLine('Ethnic/Tribal waiver',
        '${_pct(i.ethnicTribalWaiver)} on new courses', discEthnic));
  }
  if (i.disabilityWaiver > 0) {
    discounts.add(DiscountLine('Disability waiver',
        '${_pct(i.disabilityWaiver)} on new courses', discDisability));
  }

  final net = feeNew -
      totalNewDiscount +
      (feeRetake1 - discRetake1) +
      feeRetakeReg +
      admin;
  final totalDiscount = gross - net;

  // Installments.
  double first, second, third;
  String method;
  final onlyAdmin = net <= admin + 1e-6;
  if (onlyAdmin) {
    first = net;
    second = 0;
    third = 0;
    method = 'Tuition fully waived — only the trimester fee is payable';
  } else {
    final target = i.waiverInFirstInstallment
        ? (net * 0.4).roundToDouble()
        : (gross * 0.4).roundToDouble();
    method = i.waiverInFirstInstallment
        ? '40% of net payable in the 1st installment'
        : '40% of gross fee in the 1st installment';
    if (target >= net) {
      first = net;
      second = 0;
      third = 0;
      method = '100% in the 1st installment';
    } else {
      first = target;
      final remaining = net - first;
      second = (remaining / 2).roundToDouble();
      third = remaining - second;
    }
  }

  return TuitionResult(
    newTuition: feeNew,
    retakeFirstTuition: feeRetake1,
    retakeRegularTuition: feeRetakeReg,
    adminFees: admin,
    grossTotal: gross,
    discounts: discounts,
    totalDiscount: totalDiscount,
    netPayable: net,
    firstInstallment: first,
    secondInstallment: second,
    thirdInstallment: third,
    installmentMethod: method,
    onlyAdminFee: onlyAdmin,
  );
}

String _pct(double v) =>
    '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}%';
String _cr(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Format a BDT amount the way the reference app does (no decimals + ৳, Western
/// 3-digit grouping). NOTE: deliberately NOT Bangladeshi lakh/crore (2-2-3)
/// grouping — the manual Tuition tool is a faithful port of the reference
/// calculator (kawsarcodes/uiu-calculator), which uses plain 3-digit grouping,
/// and matching it keeps the two tools' numbers identical for users comparing
/// them. Revisit only if the whole app moves to a locale-aware formatter.
String formatBdt(num amount) {
  final n = amount.round();
  final s = n.abs().toString();
  // Thousands separators (3-digit groups).
  final buf = StringBuffer();
  for (var k = 0; k < s.length; k++) {
    if (k > 0 && (s.length - k) % 3 == 0) buf.write(',');
    buf.write(s[k]);
  }
  return '${n < 0 ? '-' : ''}${buf.toString()}৳';
}

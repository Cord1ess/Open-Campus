import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/core/domain/tuition.dart';

/// Locks the tuition math to the reference calculator's behaviour
/// (github.com/kawsarcodes/uiu-calculator, calculateTuitionFee).
void main() {
  test('plain new courses, no discount → 40% gross first installment', () {
    final r = calculateTuition(const TuitionInput(
      newCredits: 12,
      perCreditFee: 6500,
      trimesterFee: 6500,
    ));
    expect(r.newTuition, 78000); // 12 × 6500
    expect(r.adminFees, 6500);
    expect(r.grossTotal, 84500);
    expect(r.totalDiscount, 0);
    expect(r.netPayable, 84500);
    // 40% of gross = 33800
    expect(r.firstInstallment, 33800);
    // remaining 50700 split 50/50
    expect(r.secondInstallment, 25350);
    expect(r.thirdInstallment, 25350);
  });

  test('waiver applies to new tuition only', () {
    final r = calculateTuition(const TuitionInput(
      newCredits: 10,
      perCreditFee: 6500,
      trimesterFee: 6500,
      waiverPercent: 50,
    ));
    expect(r.newTuition, 65000);
    // 50% waiver on 65000 = 32500
    expect(r.totalDiscount, 32500);
    expect(r.netPayable, 65000 - 32500 + 6500); // 39000
  });

  test('scholarship caps at first 13 credits, waiver on the rest', () {
    // 16 new credits, scholarship 100%, waiver 50%.
    final r = calculateTuition(const TuitionInput(
      newCredits: 16,
      perCreditFee: 6500,
      trimesterFee: 6500,
      waiverPercent: 50,
      scholarshipPercent: 100,
    ));
    // first 13 cr: 100% off = 13×6500 = 84500 off
    // remaining 3 cr: 50% off = 3×6500×0.5 = 9750 off
    expect(r.totalDiscount, 84500 + 9750);
    // net = newTuition(104000) - discount(94250) + admin(6500)
    expect(r.netPayable, 104000 - 94250 + 6500);
  });

  test('first-time retake gets flat 50% off', () {
    final r = calculateTuition(const TuitionInput(
      retakeFirstCredits: 3,
      perCreditFee: 6500,
      trimesterFee: 6500,
    ));
    expect(r.retakeFirstTuition, 19500);
    // 50% off retake = 9750 discount
    expect(r.totalDiscount, 9750);
    expect(r.netPayable, 19500 - 9750 + 6500);
  });

  test('100% waiver → only admin fee payable in 1st installment', () {
    final r = calculateTuition(const TuitionInput(
      newCredits: 9,
      perCreditFee: 6500,
      trimesterFee: 6500,
      waiverPercent: 100,
    ));
    expect(r.onlyAdminFee, isTrue);
    expect(r.firstInstallment, r.adminFees);
    expect(r.secondInstallment, 0);
    expect(r.thirdInstallment, 0);
  });

  test('late registration adds 500 to admin', () {
    final r = calculateTuition(const TuitionInput(
      newCredits: 3,
      perCreditFee: 6500,
      trimesterFee: 6500,
      lateRegistration: true,
    ));
    expect(r.adminFees, 7000);
  });

  test('formatBdt adds thousands separators and ৳', () {
    expect(formatBdt(84500), '84,500৳');
    expect(formatBdt(500), '500৳');
    expect(formatBdt(1234567), '1,234,567৳');
  });
}

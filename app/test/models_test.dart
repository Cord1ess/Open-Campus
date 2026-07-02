import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/features/finance/bill_model.dart';
import 'package:open_campus/features/dashboard/home_model.dart';
import 'package:open_campus/features/academics/calendar_model.dart';

/// Model deserialization tests. These lock in the crash-guards added during the
/// audit: malformed list elements are skipped (not thrown on), comma-formatted
/// numbers parse, and an over-long term code doesn't crash the sort.
void main() {
  group('BillData.fromJson', () {
    test('parses items and computes totals-by-trimester', () {
      final d = BillData.fromJson({
        'balance': 5000,
        'items': [
          {
            'fee_type': 'Tuition Fee',
            'amount': 19500,
            'trimester': '[261] Spring 2026',
          },
          {'fee_type': 'Payment', 'payment': 10000, 'trimester': '[261] Spring 2026'},
        ],
      });
      expect(d.items.length, 2);
      expect(d.hasDue, isTrue);
      expect(d.byTrimester['[261] Spring 2026']!.length, 2);
      expect(d.items[1].isPayment, isTrue);
    });

    test('does NOT crash on a malformed items list (null / scalar elements)', () {
      final d = BillData.fromJson({
        'items': [
          null,
          'not a map',
          42,
          {'fee_type': 'Real', 'amount': 100},
        ],
      });
      // Only the one valid map survives.
      expect(d.items.length, 1);
      expect(d.items.first.feeType, 'Real');
    });

    test('parses comma-formatted number strings', () {
      final item = BillItem.fromJson({'amount': '6,500', 'credit': 3});
      expect(item.amount, 6500.0);
      expect(item.credit, 3.0);
    });

    test('currentTrimester picks the highest term code and never throws', () {
      final d = BillData.fromJson({
        'items': [
          {'trimester': '[253] Fall 2025', 'amount': 1},
          {'trimester': '[261] Spring 2026', 'amount': 1},
          // An absurdly long digit run must not crash the int parse.
          {'trimester': '[99999999999999999999999] weird', 'amount': 1},
        ],
      });
      // Doesn't throw; returns *some* key deterministically.
      expect(d.currentTrimester, isNotNull);
    });

    test('int vs double JSON numbers both become double', () {
      final a = BillItem.fromJson({'amount': 3});
      final b = BillItem.fromJson({'amount': 3.0});
      expect(a.amount, 3.0);
      expect(b.amount, 3.0);
    });

    test('statementByTrimester interleaves + assigns payments by date', () {
      // Real-shape data: bills carry a trimester, payments do not. A payment
      // dated between Spring's bills and Fall's bills belongs to Spring.
      final d = BillData.fromJson({
        'items': [
          // newest first, as UCAM sends
          {'fee_type': 'Student Payment', 'payment': 15100, 'date': '14-Jun-26'},
          {'fee_type': 'Tuition Fee', 'course_code': 'CSE 3411', 'amount': 16575,
           'trimester': '2026 Spring', 'date': '25-Feb-26'},
          {'fee_type': 'Student Payment', 'payment': 23800, 'date': '10-Dec-25'},
          {'fee_type': 'Tuition Fee', 'course_code': 'CSE 4165', 'amount': 16575,
           'trimester': '2025 Fall', 'date': '09-Nov-25'},
        ],
      });
      final st = d.statementByTrimester;
      // Two terms, newest (2026 Spring) first.
      expect(st.keys.toList(), ['2026 Spring', '2025 Fall']);
      // Spring holds its bill AND the 14-Jun payment that followed it.
      final spring = st['2026 Spring']!;
      expect(spring.length, 2);
      // Within the term, newest first: the 14-Jun payment before the 25-Feb bill.
      expect(spring.first.isPayment, isTrue);
      expect(spring.first.date, '14-Jun-26');
      expect(spring.last.courseCode, 'CSE 3411');
      // Fall holds its bill + the 10-Dec payment that followed it.
      final fall = st['2025 Fall']!;
      expect(fall.length, 2);
      expect(fall.any((i) => i.isPayment && i.payment == 23800), isTrue);
    });

    // --- Edge cases: other students' accounts differ a lot ------------------

    test('empty account: no items -> empty statement, null current term', () {
      final d = BillData.fromJson({'items': []});
      expect(d.statementByTrimester, isEmpty);
      expect(d.currentTrimester, isNull);
    });

    test('payments-only account (no bills) -> single Payments bucket', () {
      final d = BillData.fromJson({
        'items': [
          {'fee_type': 'Student Payment', 'payment': 5000, 'date': '10-Jan-26'},
          {'fee_type': 'Student Payment', 'payment': 3000, 'date': '05-Jan-26'},
        ],
      });
      final st = d.statementByTrimester;
      expect(st.keys.toList(), [BillData.paymentsBucket]);
      expect(st[BillData.paymentsBucket]!.length, 2);
      // Newest first within the bucket.
      expect(st[BillData.paymentsBucket]!.first.date, '10-Jan-26');
    });

    test('discount-only row classifies as adjustment, not a blank charge', () {
      final item = BillItem.fromJson({
        'fee_type': 'Retake Discount',
        'course_code': 'MATH 2183',
        'discount': -8287.5,
        'trimester': '2025 Fall',
        'date': '09-Nov-25',
      });
      expect(item.kind, BillKind.adjustment);
      expect(item.isPayment, isFalse);
      expect(item.isAdjustment, isTrue);
      // A waiver reduces what's owed.
      expect(item.signedAmount, -8287.5);
    });

    test('charge vs payment vs adjustment signedAmount math', () {
      final charge =
          BillItem.fromJson({'fee_type': 'Tuition Fee', 'amount': 16575});
      final payment =
          BillItem.fromJson({'fee_type': 'Student Payment', 'payment': 10000});
      final waiver =
          BillItem.fromJson({'fee_type': 'Waiver', 'discount': -5000});
      expect(charge.signedAmount, 16575);
      expect(payment.signedAmount, -10000);
      expect(waiver.signedAmount, -5000);
    });

    test('undated items do not crash and sort deterministically', () {
      final d = BillData.fromJson({
        'items': [
          {'fee_type': 'Tuition Fee', 'amount': 100, 'trimester': '2026 Spring'},
          {'fee_type': 'Student Payment', 'payment': 100}, // no date, no term
        ],
      });
      final st = d.statementByTrimester;
      // Everything lands under the one billed term; no throw.
      expect(st.keys.toList(), ['2026 Spring']);
      expect(st['2026 Spring']!.length, 2);
    });

    test('season-aware current term: Fall beats Spring within/across years', () {
      // Bill-page format is "YYYY Season" (no bracket code). Fall 2025 is newer
      // than Spring 2025, and Spring 2026 newer than both.
      final d = BillData.fromJson({
        'items': [
          {'fee_type': 'Tuition Fee', 'amount': 1, 'trimester': '2025 Spring',
           'date': '01-Feb-25'},
          {'fee_type': 'Tuition Fee', 'amount': 1, 'trimester': '2025 Fall',
           'date': '01-Nov-25'},
          {'fee_type': 'Tuition Fee', 'amount': 1, 'trimester': '2026 Spring',
           'date': '01-Feb-26'},
        ],
      });
      expect(d.currentTrimester, '2026 Spring');
    });

    test('bracket-code term format also orders newest-first', () {
      final d = BillData.fromJson({
        'items': [
          {'fee_type': 'Fee', 'amount': 1, 'trimester': '[253] Fall 2025'},
          {'fee_type': 'Fee', 'amount': 1, 'trimester': '[261] Spring 2026'},
        ],
      });
      expect(d.currentTrimester, '[261] Spring 2026');
    });

    test('alternate date formats parse (DD/MM/YYYY, ISO)', () {
      expect(BillItem.fromJson({'date': '25/02/2026'}).parsedDate,
          DateTime(2026, 2, 25));
      expect(BillItem.fromJson({'date': '2026-02-25'}).parsedDate,
          DateTime(2026, 2, 25));
      expect(BillItem.fromJson({'date': '25-Feb-2026'}).parsedDate,
          DateTime(2026, 2, 25));
      // Garbage / out-of-range -> null, not a wrong date.
      expect(BillItem.fromJson({'date': '31-02-26'}).parsedDate, isNull);
      expect(BillItem.fromJson({'date': 'whenever'}).parsedDate, isNull);
    });

    test('parses payment methods and tolerates missing/malformed entries', () {
      final d = BillData.fromJson({
        'balance': -25,
        'payment_methods': [
          {'code': 'bk', 'name': 'bKash'},
          {'code': 'vs', 'name': 'Visa'},
          null,
          'garbage',
        ],
      });
      expect(d.paymentMethods.length, 2);
      expect(d.paymentMethods.first.code, 'bk');
      expect(d.paymentMethods.first.name, 'bKash');
      expect(d.hasDue, isFalse); // -25 balance = advance
    });
  });

  group('HomeSummary.fromJson', () {
    test('tolerates malformed routine / next_terms elements', () {
      final h = HomeSummary.fromJson({
        'name': 'Test',
        'cgpa': '3.50',
        'next_terms': [null, 'x', {'code': '262', 'name': 'Summer 2026'}],
        'routine': [
          null,
          {'day': 'Monday', 'course_code': 'CSE 3411'},
        ],
      });
      expect(h.cgpa, 3.50);
      expect(h.nextTerms.length, 1);
      expect(h.routine.length, 1);
      expect(h.routine.first.courseCode, 'CSE 3411');
    });

    test('dueAmount is 0 for a negative (advance) balance', () {
      final h = HomeSummary.fromJson({'current_balance': -250});
      expect(h.hasDue, isFalse);
      expect(h.dueAmount, 0);
    });
  });

  group('CalendarEvent', () {
    test('ids are namespaced by term so cross-calendar events do not collide', () {
      final e1 = CalendarEvent.fromJson(
          {'start_date': '2026-06-16', 'event': 'Eid Holiday', 'day': 'Mon'},
          keyPrefix: 'Spring 2026|Undergraduate');
      final e2 = CalendarEvent.fromJson(
          {'start_date': '2026-06-16', 'event': 'Eid Holiday', 'day': 'Mon'},
          keyPrefix: 'Spring 2026|Graduate');
      expect(e1.id, isNot(e2.id));
      expect(e1.notificationId, isNot(e2.notificationId));
    });

    test('installment ordinal is parsed from the title, not just position', () {
      final cal = AcademicCalendar.fromJson({
        'term': 'Spring 2026',
        'program': 'Undergraduate',
        'events': [
          // Only the 2nd and 3rd are present (1st already pruned/passed).
          {
            'start_date': '2026-03-01',
            'end_date': '2026-03-01',
            'event': '2nd installment payment',
            'day': 'Sun',
          },
          {
            'start_date': '2026-04-01',
            'end_date': '2026-04-01',
            'event': '3rd installment payment',
            'day': 'Wed',
          },
        ],
      });
      final deadlines = cal.installmentDeadlines;
      expect(deadlines.length, 2);
      // Labeled by their parsed ordinal (2nd, 3rd), NOT re-numbered 1st/2nd.
      expect(deadlines[0].ordinalLabel, '2nd');
      expect(deadlines[1].ordinalLabel, '3rd');
    });

    test('_inferType does not misfire on substring "fee" in "coffee"', () {
      final e = CalendarEvent.fromJson(
          {'start_date': '2026-05-01', 'event': 'Free coffee meetup', 'day': 'Fri'});
      expect(e.type, isNot(CalendarEventType.payment));
    });
  });
}

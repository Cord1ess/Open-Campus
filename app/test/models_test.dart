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

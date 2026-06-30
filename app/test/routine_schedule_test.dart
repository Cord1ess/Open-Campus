import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/features/academics/routine_schedule.dart';
import 'package:open_campus/features/dashboard/home_model.dart';

void main() {
  ClassSession s(String day, String start, String end) => ClassSession(
      day: day, courseCode: 'CSE 1234', section: 'A', start: start, end: end);

  test('parseClock handles 12h and 24h', () {
    expect(parseClock('08:30 AM'), (8, 30));
    expect(parseClock('1:50 PM'), (13, 50));
    expect(parseClock('12:00 AM'), (0, 0));
    expect(parseClock('12:00 PM'), (12, 0));
    expect(parseClock('13:50'), (13, 50));
    expect(parseClock('garbage'), isNull);
  });

  test('nextOccurrence finds the upcoming weekday/time', () {
    // A Wednesday 10:00.
    final now = DateTime(2026, 7, 1, 9, 0); // Wed
    final at = nextOccurrence(s('Wednesday', '10:00 AM', '11:00 AM'), now);
    expect(at, DateTime(2026, 7, 1, 10, 0)); // same day, later
  });

  test('nextOccurrence rolls to next week when time passed today', () {
    final now = DateTime(2026, 7, 1, 11, 0); // Wed, after 10:00
    final at = nextOccurrence(s('Wednesday', '10:00 AM', '11:00 AM'), now);
    expect(at, DateTime(2026, 7, 8, 10, 0)); // next Wednesday
  });

  test('nextClass picks the soonest across the routine', () {
    final now = DateTime(2026, 7, 1, 9, 0); // Wed
    final routine = [
      s('Friday', '09:00 AM', '10:00 AM'),
      s('Wednesday', '02:00 PM', '03:00 PM'),
      s('Wednesday', '10:00 AM', '11:00 AM'),
    ];
    final n = nextClass(routine, now);
    expect(n!.start, DateTime(2026, 7, 1, 10, 0)); // Wed 10am is soonest
  });

  test('isOngoing detects a live class', () {
    final now = DateTime(2026, 7, 1, 10, 30); // Wed 10:30
    expect(isOngoing(s('Wednesday', '10:00 AM', '11:00 AM'), now), isTrue);
    expect(isOngoing(s('Wednesday', '11:00 AM', '12:00 PM'), now), isFalse);
    expect(isOngoing(s('Thursday', '10:00 AM', '11:00 AM'), now), isFalse);
  });

  test('routineIcs builds weekly recurring VEVENTs', () {
    final ics = routineIcs(
      [s('Wednesday', '10:00 AM', '11:00 AM')],
      from: DateTime(2026, 7, 1, 9, 0),
      stampNow: DateTime.utc(2026, 6, 30, 12),
    );
    expect(ics.contains('BEGIN:VCALENDAR\r\n'), isTrue);
    expect(ics.contains('RRULE:FREQ=WEEKLY;BYDAY=WE'), isTrue);
    expect(ics.contains('DTSTART:20260701T100000'), isTrue);
    expect(ics.contains('DTEND:20260701T110000'), isTrue);
    expect(ics.contains('SUMMARY:CSE 1234 (A)'), isTrue);
    expect(ics.endsWith('\r\n'), isTrue);
  });
}

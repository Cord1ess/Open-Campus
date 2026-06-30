import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/features/academics/calendar_model.dart';
import 'package:open_campus/features/academics/google_calendar.dart';

/// Validates that GoogleCalendar.icsFor produces a strictly RFC 5545–compliant
/// document — the cause of "unable to launch event" was non-compliant output
/// (LF endings, missing DTSTAMP, unfolded long lines). These assertions lock the
/// fix in so it can't silently regress.
void main() {
  CalendarEvent ev(String title, String day, DateTime start, [DateTime? end]) =>
      CalendarEvent(
        id: '$start|$title',
        title: title,
        detail: day,
        date: start,
        endDate: end,
        dateText: 'x',
        type: CalendarEventType.other,
      );

  final events = [
    // Long title with comma + semicolon to exercise escaping + line folding.
    ev(
      'Course Advising & Registration, Add/Drop; late fee applies for everyone '
          'enrolled in this very long trimester title that exceeds seventy five octets',
      'Sat-Mon',
      DateTime(2026, 7, 4),
      DateTime(2026, 7, 6),
    ),
    ev('Mid-term Exam', 'Wed', DateTime(2026, 7, 15)),
  ];

  final ics = GoogleCalendar.icsFor(events,
      calendarName: 'Spring 2026 · Undergraduate',
      stampNow: DateTime.utc(2026, 6, 30, 12, 0, 0));

  test('every line is CRLF-terminated (no bare LF)', () {
    expect(RegExp(r'(?<!\r)\n').hasMatch(ics), isFalse,
        reason: 'Found a bare LF — calendar apps reject LF-only ICS.');
    expect(ics.endsWith('\r\n'), isTrue);
  });

  test('has the required calendar envelope', () {
    expect(ics.contains('BEGIN:VCALENDAR\r\n'), isTrue);
    expect(ics.contains('END:VCALENDAR\r\n'), isTrue);
    expect(ics.contains('VERSION:2.0\r\n'), isTrue);
    expect(ics.contains('PRODID:'), isTrue);
  });

  test('every VEVENT has UID, DTSTAMP, DTSTART, DTEND, SUMMARY', () {
    final blocks = RegExp(r'BEGIN:VEVENT\r\n([\s\S]*?)END:VEVENT')
        .allMatches(ics)
        .map((m) => m.group(1)!)
        .toList();
    expect(blocks.length, 2);
    for (final b in blocks) {
      expect(b.contains('UID:'), isTrue, reason: 'missing UID');
      expect(b.contains('DTSTAMP:'), isTrue, reason: 'missing DTSTAMP');
      expect(b.contains('DTSTART;VALUE=DATE:'), isTrue, reason: 'missing DTSTART');
      expect(b.contains('DTEND;VALUE=DATE:'), isTrue, reason: 'missing DTEND');
      expect(b.contains('SUMMARY:'), isTrue, reason: 'missing SUMMARY');
    }
  });

  test('DTSTAMP is a valid UTC timestamp', () {
    expect(ics.contains('DTSTAMP:20260630T120000Z'), isTrue);
  });

  test('all-day end dates are EXCLUSIVE (day after the inclusive end)', () {
    // Range 4–6 July → DTEND 7 July.
    expect(ics.contains('DTSTART;VALUE=DATE:20260704'), isTrue);
    expect(ics.contains('DTEND;VALUE=DATE:20260707'), isTrue);
    // Single day 15 July → DTEND 16 July.
    expect(ics.contains('DTSTART;VALUE=DATE:20260715'), isTrue);
    expect(ics.contains('DTEND;VALUE=DATE:20260716'), isTrue);
  });

  test('no physical line exceeds 75 octets (lines are folded)', () {
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75),
          reason: 'Unfolded line >75 octets: "$line"');
    }
  });

  test('folded continuation lines start with a single space', () {
    // The long title must have wrapped, producing at least one " " continuation.
    expect(ics.contains('\r\n '), isTrue);
  });

  test('TEXT values are escaped (comma, semicolon, ampersand kept literal)', () {
    expect(ics.contains(r'\,'), isTrue, reason: 'comma not escaped');
    expect(ics.contains(r'\;'), isTrue, reason: 'semicolon not escaped');
    expect(ics.contains('&'), isTrue, reason: 'ampersand should stay literal');
  });

  test('refolding/unfolding round-trips back to valid content', () {
    // Unfold (RFC 5545: CRLF + space → nothing) and confirm the title survives.
    final unfolded = ics.replaceAll('\r\n ', '');
    expect(unfolded.contains('SUMMARY:Course Advising'), isTrue);
  });
}

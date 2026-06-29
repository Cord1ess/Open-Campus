import 'dart:convert';

import 'calendar_model.dart';

/// Builds Google Calendar "add event" template URLs.
///
/// Single events open the prefilled event-creation dialog. Since the academic
/// calendar entries are all-day, we use Google's all-day date format
/// (YYYYMMDD/YYYYMMDD) where the END date is EXCLUSIVE — so a one-day event on
/// the 6th is `20260706/20260707`, and a range 4–6 is `20260704/20260707`.
class GoogleCalendar {
  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  /// A link that adds a single [event] to the user's Google Calendar.
  static String eventUrl(CalendarEvent e, {String? calendarName}) {
    final start = e.date;
    // End is exclusive for all-day events → day after the (inclusive) end.
    final inclusiveEnd = e.endDate ?? e.date;
    final exclusiveEnd = inclusiveEnd.add(const Duration(days: 1));

    final details = StringBuffer();
    if (e.detail != null && e.detail!.isNotEmpty) {
      details.writeln('Day: ${e.detail}');
    }
    if (calendarName != null) details.writeln('From: $calendarName');
    details.write('Added from Open Campus');

    final params = {
      'action': 'TEMPLATE',
      'text': e.title,
      'dates': '${_ymd(start)}/${_ymd(exclusiveEnd)}',
      'details': details.toString(),
    };
    final query = params.entries
        .map((p) =>
            '${p.key}=${Uri.encodeQueryComponent(p.value)}')
        .join('&');
    return 'https://calendar.google.com/calendar/render?$query';
  }

  /// An iCalendar (.ics) document containing ALL [events] — the standard way to
  /// import a whole calendar into Google Calendar (or Apple/Outlook) in one go.
  static String icsFor(List<CalendarEvent> events, {String? calendarName}) {
    final b = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//Open Campus//Academic Calendar//EN')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH');
    if (calendarName != null) {
      b.writeln('X-WR-CALNAME:${_esc(calendarName)}');
    }
    for (final e in events) {
      final start = e.date;
      final exclusiveEnd = (e.endDate ?? e.date).add(const Duration(days: 1));
      b
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:${e.notificationId}@opencampus')
        ..writeln('DTSTART;VALUE=DATE:${_ymd(start)}')
        ..writeln('DTEND;VALUE=DATE:${_ymd(exclusiveEnd)}')
        ..writeln('SUMMARY:${_esc(e.title)}');
      if (e.detail != null && e.detail!.isNotEmpty) {
        b.writeln('DESCRIPTION:${_esc('Day: ${e.detail}')}');
      }
      b.writeln('END:VEVENT');
    }
    b.writeln('END:VCALENDAR');
    return b.toString();
  }

  /// A `data:` URL wrapping the .ics so it can be opened/downloaded without a
  /// backend. Works on web (downloads) and mobile (opens the calendar import).
  static String icsDataUrl(List<CalendarEvent> events, {String? calendarName}) {
    final ics = icsFor(events, calendarName: calendarName);
    final b64 = base64Encode(utf8.encode(ics));
    return 'data:text/calendar;base64,$b64';
  }

  /// Escape per RFC 5545 (commas, semicolons, newlines, backslashes).
  static String _esc(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;')
      .replaceAll('\n', r'\n');
}

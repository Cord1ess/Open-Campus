import 'dart:convert';

import 'calendar_model.dart';

/// Builds Google Calendar "add event" links and strictly RFC 5545–compliant
/// iCalendar (.ics) documents for the academic calendar.
///
/// All academic-calendar entries are ALL-DAY, so we use the date-only value form
/// (`VALUE=DATE`, `YYYYMMDD`) where the END date is EXCLUSIVE — a one-day event
/// on the 6th is `20260706`→`20260707`; a range 4–6 is `20260704`→`20260707`.
class GoogleCalendar {
  // ICS lines MUST be CRLF-terminated (RFC 5545 §3.1). LF-only output is the
  // most common reason calendar apps reject a file with "unable to launch".
  static const _crlf = '\r\n';

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  /// UTC timestamp in iCalendar form (`YYYYMMDDTHHMMSSZ`). Used for DTSTAMP,
  /// which is REQUIRED on every VEVENT.
  static String _dtStamp(DateTime now) {
    final u = now.toUtc();
    return '${_ymd(u)}T'
        '${u.hour.toString().padLeft(2, '0')}'
        '${u.minute.toString().padLeft(2, '0')}'
        '${u.second.toString().padLeft(2, '0')}Z';
  }

  /// A link that adds a single [event] to the user's Google Calendar. This is a
  /// plain `https://` URL (the most reliable cross-platform path — it just opens
  /// Google Calendar with the event prefilled, no file handling needed).
  static String eventUrl(CalendarEvent e, {String? calendarName}) {
    final start = e.date;
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
        .map((p) => '${p.key}=${Uri.encodeQueryComponent(p.value)}')
        .join('&');
    return 'https://calendar.google.com/calendar/render?$query';
  }

  /// A strictly RFC 5545–compliant iCalendar document containing ALL [events] —
  /// the standard way to import a whole calendar into Google / Apple / Outlook.
  static String icsFor(List<CalendarEvent> events, {String? calendarName,
      DateTime? stampNow}) {
    // A single fixed stamp for the whole document (passed in so callers can keep
    // it deterministic; defaults to now).
    final stamp = _dtStamp(stampNow ?? DateTime.now());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Open Campus//Academic Calendar//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      if (calendarName != null) 'X-WR-CALNAME:${_esc(calendarName)}',
    ];

    for (final e in events) {
      final start = e.date;
      final exclusiveEnd = (e.endDate ?? e.date).add(const Duration(days: 1));
      lines
        ..add('BEGIN:VEVENT')
        ..add('UID:${e.notificationId}@opencampus')
        ..add('DTSTAMP:$stamp')
        ..add('DTSTART;VALUE=DATE:${_ymd(start)}')
        ..add('DTEND;VALUE=DATE:${_ymd(exclusiveEnd)}')
        ..add('SUMMARY:${_esc(e.title)}');
      if (e.detail != null && e.detail!.isNotEmpty) {
        lines.add('DESCRIPTION:${_esc('Day: ${e.detail}')}');
      }
      lines.add('END:VEVENT');
    }
    lines.add('END:VCALENDAR');

    // Fold each content line to <=75 octets and join with CRLF (RFC 5545 §3.1).
    return lines.map(_fold).join(_crlf) + _crlf;
  }

  /// Escape a TEXT value per RFC 5545 §3.3.11 (backslash, comma, semicolon, and
  /// newlines — CR is dropped, LF becomes the literal `\n`).
  static String _esc(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;')
      .replaceAll('\r\n', '\\n')
      .replaceAll('\r', '\\n')
      .replaceAll('\n', '\\n');

  /// Fold a content line to a max of 75 OCTETS per line, continuation lines
  /// starting with a single space (RFC 5545 §3.1). We fold on UTF-8 byte
  /// boundaries so multi-byte characters are never split.
  static String _fold(String line) {
    final bytes = utf8.encode(line);
    if (bytes.length <= 75) return line;
    final out = StringBuffer();
    var i = 0;
    var first = true;
    while (i < bytes.length) {
      // First line: up to 75 bytes. Continuations: 1 leading space + up to 74.
      final limit = first ? 75 : 74;
      var end = (i + limit).clamp(0, bytes.length);
      // Don't split a multi-byte UTF-8 sequence: back up off continuation bytes
      // (0b10xxxxxx) until we're at a code-point boundary.
      while (end > i && end < bytes.length && (bytes[end] & 0xC0) == 0x80) {
        end--;
      }
      final chunk = utf8.decode(bytes.sublist(i, end));
      if (!first) out.write('$_crlf ');
      out.write(chunk);
      i = end;
      first = false;
    }
    return out.toString();
  }
}

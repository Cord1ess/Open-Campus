import 'dart:convert';

import '../dashboard/home_model.dart';

/// Helpers for the class routine: parsing class times, finding the next upcoming
/// class (for the countdown), and exporting the weekly routine as a recurring
/// `.ics`. Self-contained so it can be unit-tested.

const _weekdayByName = {
  'saturday': DateTime.saturday,
  'sunday': DateTime.sunday,
  'monday': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'friday': DateTime.friday,
};

/// Parse a clock string like "08:30 AM" / "1:50 PM" / "13:50" → (hour, minute)
/// in 24h. Returns null if unparseable.
(int, int)? parseClock(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toUpperCase();
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?').firstMatch(s);
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final ampm = m.group(3);
  if (ampm == 'PM' && h != 12) h += 12;
  if (ampm == 'AM' && h == 12) h = 0;
  if (h > 23 || min > 59) return null;
  return (h, min);
}

/// The next occurrence of a session's start at-or-after [from]. Returns null if
/// the session has no parseable day/time.
DateTime? nextOccurrence(ClassSession s, DateTime from) {
  final wd = _weekdayByName[s.day.trim().toLowerCase()];
  final hm = parseClock(s.start);
  if (wd == null || hm == null) return null;
  // Days until that weekday (0..6).
  var add = (wd - from.weekday) % 7;
  if (add < 0) add += 7;
  var candidate = DateTime(from.year, from.month, from.day, hm.$1, hm.$2)
      .add(Duration(days: add));
  // If it's today's weekday but the time already passed, jump a week.
  if (candidate.isBefore(from)) candidate = candidate.add(const Duration(days: 7));
  return candidate;
}

/// The next class across the whole routine relative to [now] (the soonest
/// upcoming session), with its start time. Null if nothing is schedulable.
({ClassSession session, DateTime start})? nextClass(
    List<ClassSession> routine, DateTime now) {
  ({ClassSession session, DateTime start})? best;
  for (final s in routine) {
    final at = nextOccurrence(s, now);
    if (at == null) continue;
    if (best == null || at.isBefore(best.start)) {
      best = (session: s, start: at);
    }
  }
  return best;
}

/// True when [now] falls within a session's start–end window today.
bool isOngoing(ClassSession s, DateTime now) {
  final wd = _weekdayByName[s.day.trim().toLowerCase()];
  if (wd != now.weekday) return false;
  final start = parseClock(s.start), end = parseClock(s.end);
  if (start == null || end == null) return false;
  final startMin = start.$1 * 60 + start.$2;
  final endMin = end.$1 * 60 + end.$2;
  final nowMin = now.hour * 60 + now.minute;
  return nowMin >= startMin && nowMin < endMin;
}

// ---------------------------------------------------------------------------
// ICS export (weekly recurring events).
// ---------------------------------------------------------------------------

const _crlf = '\r\n';

String _two(int v) => v.toString().padLeft(2, '0');

/// `YYYYMMDDTHHMMSS` (local/floating time — no Z) for a routine event.
String _localStamp(DateTime d) =>
    '${d.year}${_two(d.month)}${_two(d.day)}T${_two(d.hour)}${_two(d.minute)}00';

String _utcStamp(DateTime d) {
  final u = d.toUtc();
  return '${u.year}${_two(u.month)}${_two(u.day)}T'
      '${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
}

const _icalDayByWeekday = {
  DateTime.monday: 'MO',
  DateTime.tuesday: 'TU',
  DateTime.wednesday: 'WE',
  DateTime.thursday: 'TH',
  DateTime.friday: 'FR',
  DateTime.saturday: 'SA',
  DateTime.sunday: 'SU',
};

String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;')
    .replaceAll('\n', '\\n');

String _fold(String line) {
  final bytes = utf8.encode(line);
  if (bytes.length <= 75) return line;
  final out = StringBuffer();
  var i = 0;
  var first = true;
  while (i < bytes.length) {
    final limit = first ? 75 : 74;
    var end = (i + limit).clamp(0, bytes.length);
    while (end > i && end < bytes.length && (bytes[end] & 0xC0) == 0x80) {
      end--;
    }
    out.write(first ? '' : '$_crlf ');
    out.write(utf8.decode(bytes.sublist(i, end)));
    i = end;
    first = false;
  }
  return out.toString();
}

/// Build a weekly-recurring `.ics` for the routine. Each session becomes a
/// VEVENT whose first occurrence is the next instance of its weekday/time, with
/// `RRULE:FREQ=WEEKLY` so it repeats. Times are floating (local) so they show at
/// the same clock time wherever the calendar app is.
String routineIcs(
  List<ClassSession> routine, {
  String calendarName = 'Class Routine',
  DateTime? from,
  DateTime? stampNow,
}) {
  final now = from ?? DateTime.now();
  final stamp = _utcStamp(stampNow ?? DateTime.now());
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Open Campus//Class Routine//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${_esc(calendarName)}',
  ];

  var n = 0;
  for (final s in routine) {
    final start = nextOccurrence(s, now);
    final endHm = parseClock(s.end);
    final startHm = parseClock(s.start);
    final wd = _weekdayByName[s.day.trim().toLowerCase()];
    if (start == null || startHm == null || wd == null) continue;
    // End: same day as start; if end time missing, default to +1h.
    final end = endHm != null
        ? DateTime(start.year, start.month, start.day, endHm.$1, endHm.$2)
        : start.add(const Duration(hours: 1));
    final title = '${s.courseCode}${s.section != null ? ' (${s.section})' : ''}';
    lines
      ..add('BEGIN:VEVENT')
      ..add('UID:routine-${n++}-${s.courseCode}@opencampus')
      ..add('DTSTAMP:$stamp')
      ..add('DTSTART:${_localStamp(start)}')
      ..add('DTEND:${_localStamp(end)}')
      ..add('RRULE:FREQ=WEEKLY;BYDAY=${_icalDayByWeekday[wd]}')
      ..add('SUMMARY:${_esc(title)}')
      ..add('END:VEVENT');
  }
  lines.add('END:VCALENDAR');
  return lines.map(_fold).join(_crlf) + _crlf;
}

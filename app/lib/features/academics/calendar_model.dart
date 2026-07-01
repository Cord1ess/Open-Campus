import 'package:flutter/material.dart';

/// Kind of academic-calendar entry — drives the icon/color. Inferred from the
/// event text since the source is free-form.
enum CalendarEventType { registration, payment, exam, holiday, classDay, other }

class CalendarEvent {
  final String id;
  final String title;
  final String? detail; // the day label, e.g. "Sat-Mon"
  final DateTime date; // start date
  final DateTime? endDate; // for multi-day ranges
  final String dateText; // raw, e.g. "Jul 4 - 6, 2026"
  final CalendarEventType type;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.detail,
    required this.date,
    this.endDate,
    this.dateText = '',
    this.type = CalendarEventType.other,
  });

  /// Whether the event (or its whole range) is already over.
  bool get isPast {
    final n = DateTime.now();
    return (endDate ?? date).isBefore(DateTime(n.year, n.month, n.day));
  }

  /// A stable integer id for the notification system.
  int get notificationId => id.hashCode & 0x7fffffff;

  IconData get icon => switch (type) {
        CalendarEventType.registration => Icons.app_registration_outlined,
        CalendarEventType.payment => Icons.payments_outlined,
        CalendarEventType.exam => Icons.edit_note_outlined,
        CalendarEventType.holiday => Icons.beach_access_outlined,
        CalendarEventType.classDay => Icons.menu_book_outlined,
        CalendarEventType.other => Icons.event_outlined,
      };

  /// [keyPrefix] namespaces the id (and thus the notification id) to a specific
  /// calendar/term, so an event with the same date+title in two calendars —
  /// e.g. the Undergraduate and Graduate "Eid Holiday" — gets a DISTINCT id.
  /// Without it, both would collide: setting a reminder on one would toggle the
  /// other, and their scheduled notifications would overwrite each other.
  factory CalendarEvent.fromJson(Map<String, dynamic> j, {String keyPrefix = ''}) {
    final event = (j['event'] ?? '').toString();
    final start = _parseIso(j['start_date']) ?? DateTime(1970);
    return CalendarEvent(
      // Include end date + day too, not just start+title, so same-day distinct
      // events don't share an id within one calendar either.
      id: '$keyPrefix|${j['start_date'] ?? ''}|${j['end_date'] ?? ''}'
          '|${j['day'] ?? ''}|$event',
      title: event,
      detail: (j['day'] ?? '').toString(),
      date: start,
      endDate: _parseIso(j['end_date']),
      dateText: (j['date_text'] ?? '').toString(),
      type: _inferType(event),
    );
  }
}

/// Match a whole word (not a substring) so short tokens like "fee" don't fire on
/// "coffee"/"feedback" and "class" on "classroom allocation".
bool _hasWord(String text, String word) =>
    RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(text);

/// Parse an installment ordinal from free text: "1st"/"2nd"/"3rd"/"4th" or the
/// words "first".."fourth". Returns null if none present (caller falls back to
/// encounter position). [text] is expected lower-cased.
int? _parseOrdinal(String text) {
  final digit = RegExp(r'\b([1-9])\s*(?:st|nd|rd|th)\b').firstMatch(text);
  if (digit != null) return int.tryParse(digit.group(1)!);
  const words = {'first': 1, 'second': 2, 'third': 3, 'fourth': 4};
  for (final entry in words.entries) {
    if (_hasWord(text, entry.key)) return entry.value;
  }
  return null;
}

DateTime? _parseIso(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

CalendarEventType _inferType(String text) {
  final t = text.toLowerCase();
  // Short/ambiguous tokens use whole-word matching (_hasWord); unambiguous
  // longer phrases can stay as substrings.
  if (t.contains('registration') || t.contains('advising') ||
      t.contains('add/drop') || _hasWord(t, 'withdraw')) {
    return CalendarEventType.registration;
  }
  if (t.contains('payment') || t.contains('installment') ||
      t.contains('instalment') || t.contains('tuition') ||
      _hasWord(t, 'fee') || _hasWord(t, 'fees') || _hasWord(t, 'fine')) {
    return CalendarEventType.payment;
  }
  if (_hasWord(t, 'exam') || t.contains('mid-term') || t.contains('midterm') ||
      _hasWord(t, 'final') || t.contains('finals')) {
    return CalendarEventType.exam;
  }
  if (t.contains('holiday') || _hasWord(t, 'eid') || t.contains('closed') ||
      t.contains('vacation') || t.contains('puja') || _hasWord(t, 'break')) {
    return CalendarEventType.holiday;
  }
  if (t.contains('semester begin') || t.contains('classes begin') ||
      t.contains('class resume') || _hasWord(t, 'class') ||
      _hasWord(t, 'classes')) {
    return CalendarEventType.classDay;
  }
  return CalendarEventType.other;
}

/// One academic calendar (a term + program) with its events.
class AcademicCalendar {
  final String title;
  final String term; // "Spring 2026"
  final String program; // "Undergraduate"
  final bool revised;
  final List<CalendarEvent> events;

  const AcademicCalendar({
    required this.title,
    required this.term,
    required this.program,
    required this.revised,
    required this.events,
  });

  factory AcademicCalendar.fromJson(Map<String, dynamic> j) {
    final term = (j['term'] ?? '').toString();
    final program = (j['program'] ?? '').toString();
    // Namespace each event's id by term+program so identical events across two
    // calendars don't collide (see CalendarEvent.fromJson keyPrefix).
    final keyPrefix = '$term|$program';
    return AcademicCalendar(
      title: (j['title'] ?? '').toString(),
      term: term,
      program: program,
      revised: j['revised'] == true,
      events: ((j['events'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) =>
              CalendarEvent.fromJson(e.cast<String, dynamic>(), keyPrefix: keyPrefix))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
    );
  }

  /// The next upcoming event (range not yet over). Null if all are past.
  CalendarEvent? get nextEvent {
    for (final e in events) {
      if (!e.isPast) return e;
    }
    return null;
  }

  /// The next [n] upcoming events (ranges not yet over), in date order.
  List<CalendarEvent> nextEvents(int n) {
    final out = <CalendarEvent>[];
    for (final e in events) {
      if (!e.isPast) {
        out.add(e);
        if (out.length >= n) break;
      }
    }
    return out;
  }

  /// Tuition installment deadlines for this term, in date order (1st, 2nd, 3rd…).
  /// Detected from payment-type events whose text mentions an installment.
  /// Events are already date-sorted, so this preserves chronological order.
  List<InstallmentDeadline> get installmentDeadlines {
    final out = <InstallmentDeadline>[];
    for (final e in events) {
      if (e.type != CalendarEventType.payment) continue;
      final t = e.title.toLowerCase();
      if (!t.contains('installment') && !t.contains('instalment')) continue;
      // Prefer the ordinal parsed from the title ("1st"/"first" installment) so
      // the label is correct even when the calendar omits an earlier one; only
      // fall back to encounter-position when the text has no ordinal.
      final parsed = _parseOrdinal(t);
      // The deadline is the END of the range if it's a span, else the single date.
      out.add(InstallmentDeadline(
        ordinal: parsed ?? out.length + 1,
        deadline: e.endDate ?? e.date,
        title: e.title,
        dateText: e.dateText,
      ));
    }
    return out;
  }

  /// The installment currently being counted down to: the first whose deadline
  /// hasn't passed. Returns null if there are none, or all have passed.
  /// As each deadline passes (midnight after it), the next one becomes active
  /// automatically — 1st → 2nd → 3rd.
  InstallmentDeadline? get activeInstallment {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    for (final d in installmentDeadlines) {
      // Active while the deadline day itself hasn't fully passed.
      if (!d.deadline.isBefore(today)) return d;
    }
    return null;
  }
}

/// A single tuition installment deadline, derived from the academic calendar.
class InstallmentDeadline {
  final int ordinal; // 1, 2, 3 — order within the term
  final DateTime deadline; // the last day to pay
  final String title; // raw calendar event text
  final String dateText; // e.g. "Jul 6, 2026"

  const InstallmentDeadline({
    required this.ordinal,
    required this.deadline,
    required this.title,
    required this.dateText,
  });

  /// "1st", "2nd", "3rd", "4th"…
  String get ordinalLabel {
    if (ordinal == 1) return '1st';
    if (ordinal == 2) return '2nd';
    if (ordinal == 3) return '3rd';
    return '${ordinal}th';
  }
}

class AcademicCalendarData {
  final List<AcademicCalendar> calendars;
  const AcademicCalendarData({required this.calendars});

  factory AcademicCalendarData.fromJson(Map<String, dynamic> j) =>
      AcademicCalendarData(
        calendars: ((j['calendars'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AcademicCalendar.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  /// The best default calendar: prefer an Undergraduate one whose range covers
  /// today (or the nearest upcoming), else the first Undergraduate, else first.
  AcademicCalendar? get defaultCalendar {
    if (calendars.isEmpty) return null;
    final ug = calendars
        .where((c) => c.program.toLowerCase().contains('undergrad'))
        .toList();
    final pool = ug.isNotEmpty ? ug : calendars;
    // Prefer the first one with an upcoming event (the current/next term).
    for (final c in pool) {
      if (c.nextEvent != null) return c;
    }
    return pool.first;
  }
}

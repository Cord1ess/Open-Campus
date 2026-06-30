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

  factory CalendarEvent.fromJson(Map<String, dynamic> j) {
    final event = (j['event'] ?? '').toString();
    final start = _parseIso(j['start_date']) ?? DateTime(1970);
    return CalendarEvent(
      id: '${j['start_date'] ?? ''}|$event',
      title: event,
      detail: (j['day'] ?? '').toString(),
      date: start,
      endDate: _parseIso(j['end_date']),
      dateText: (j['date_text'] ?? '').toString(),
      type: _inferType(event),
    );
  }
}

DateTime? _parseIso(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

CalendarEventType _inferType(String text) {
  final t = text.toLowerCase();
  if (t.contains('registration') || t.contains('advising') || t.contains('add/drop') || t.contains('withdraw')) {
    return CalendarEventType.registration;
  }
  if (t.contains('payment') || t.contains('installment') || t.contains('fee') || t.contains('fine') || t.contains('tuition')) {
    return CalendarEventType.payment;
  }
  if (t.contains('exam') || t.contains('mid-term') || t.contains('midterm') || t.contains('final')) {
    return CalendarEventType.exam;
  }
  if (t.contains('holiday') || t.contains('eid') || t.contains('closed') || t.contains('vacation') || t.contains('puja') || t.contains('break')) {
    return CalendarEventType.holiday;
  }
  if (t.contains('class') || t.contains('semester begin') || t.contains('classes begin')) {
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

  factory AcademicCalendar.fromJson(Map<String, dynamic> j) => AcademicCalendar(
        title: (j['title'] ?? '').toString(),
        term: (j['term'] ?? '').toString(),
        program: (j['program'] ?? '').toString(),
        revised: j['revised'] == true,
        events: ((j['events'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => CalendarEvent.fromJson(e.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date)),
      );

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
      // The deadline is the END of the range if it's a span, else the single date.
      out.add(InstallmentDeadline(
        ordinal: out.length + 1,
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

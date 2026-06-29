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

import 'package:flutter/material.dart';

/// Kind of academic-calendar entry — drives the icon/color.
enum CalendarEventType { registration, payment, exam, holiday, classDay, other }

class CalendarEvent {
  final String id;
  final String title;
  final String? detail;
  final DateTime date;
  final CalendarEventType type;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.detail,
    required this.date,
    this.type = CalendarEventType.other,
  });

  bool get isPast => date.isBefore(DateTime.now());

  /// A stable integer id for the notification system (hash of the string id).
  int get notificationId => id.hashCode & 0x7fffffff;

  IconData get icon => switch (type) {
        CalendarEventType.registration => Icons.app_registration_outlined,
        CalendarEventType.payment => Icons.payments_outlined,
        CalendarEventType.exam => Icons.edit_note_outlined,
        CalendarEventType.holiday => Icons.beach_access_outlined,
        CalendarEventType.classDay => Icons.menu_book_outlined,
        CalendarEventType.other => Icons.event_outlined,
      };
}

/// Placeholder calendar until the per-term academic calendar is captured.
/// Dates are relative to "now" so the UI always shows a sensible mix of
/// upcoming/past. TODO(data): replace with the real calendar feed.
List<CalendarEvent> sampleCalendar(DateTime now) {
  DateTime d(int offsetDays) =>
      DateTime(now.year, now.month, now.day).add(Duration(days: offsetDays));
  return [
    CalendarEvent(
      id: 'reg-open',
      title: 'Registration opens',
      detail: 'Summer 2026 course registration begins',
      date: d(-10),
      type: CalendarEventType.registration,
    ),
    CalendarEvent(
      id: 'inst-1',
      title: '1st installment deadline',
      detail: 'Pay 40% of tuition + trimester fee to avoid a ৳500 fine',
      date: d(3),
      type: CalendarEventType.payment,
    ),
    CalendarEvent(
      id: 'classes-begin',
      title: 'Classes begin',
      detail: 'First day of Summer 2026 classes',
      date: d(7),
      type: CalendarEventType.classDay,
    ),
    CalendarEvent(
      id: 'inst-2',
      title: '2nd installment deadline',
      detail: 'Pay up to 70% of tuition + trimester fee',
      date: d(30),
      type: CalendarEventType.payment,
    ),
    CalendarEvent(
      id: 'midterm',
      title: 'Mid-term exams',
      detail: 'Mid-term examination week',
      date: d(45),
      type: CalendarEventType.exam,
    ),
    CalendarEvent(
      id: 'inst-3',
      title: '3rd installment deadline',
      detail: 'Pay 100% of tuition + trimester fee',
      date: d(55),
      type: CalendarEventType.payment,
    ),
    CalendarEvent(
      id: 'holiday',
      title: 'Eid holiday',
      detail: 'University closed',
      date: d(60),
      type: CalendarEventType.holiday,
    ),
    CalendarEvent(
      id: 'final',
      title: 'Final exams',
      detail: 'Final examination week',
      date: d(80),
      type: CalendarEventType.exam,
    ),
  ];
}

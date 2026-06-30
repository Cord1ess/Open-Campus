import 'calendar_model.dart';
import 'google_calendar.dart';
// Platform-specific implementation: a real file download on web, an OS hand-off
// on mobile/desktop. Chosen at compile time so neither dart:html nor
// url_launcher leaks into the wrong platform.
import 'ics_export_stub.dart'
    if (dart.library.html) 'ics_export_web.dart'
    if (dart.library.io) 'ics_export_io.dart';

/// Exports the given events as an `.ics` file the user can import into Google
/// Calendar (or Apple/Outlook). Returns true if the export was handed off
/// successfully (download started on web, or a handler opened on mobile).
///
/// On web this downloads a real `.ics` file (the reliable path — base64 `data:`
/// URLs are blocked/ignored by many browsers and never reach mobile calendar
/// apps). On mobile/desktop it asks the OS to open the calendar data with
/// whatever app handles it.
Future<bool> exportIcs(
  List<CalendarEvent> events, {
  String? calendarName,
  DateTime? stampNow,
}) {
  final ics = GoogleCalendar.icsFor(
    events,
    calendarName: calendarName,
    stampNow: stampNow,
  );
  final filename = _safeName(calendarName) ?? 'open-campus-calendar';
  return saveOrOpenIcs(ics, '$filename.ics');
}

/// Export a pre-built ICS document (e.g. the weekly class routine, which uses
/// recurring VEVENTs rather than the all-day calendar events above). Same
/// platform delivery as [exportIcs].
Future<bool> exportRawIcs(String ics, {String? calendarName}) {
  final filename = _safeName(calendarName) ?? 'open-campus';
  return saveOrOpenIcs(ics, '$filename.ics');
}

/// Make a filesystem-safe file name from the calendar's display name.
String? _safeName(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final cleaned = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? null : cleaned;
}

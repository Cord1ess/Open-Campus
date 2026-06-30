// Web-only: fire an immediate browser notification (with permission request).
//
// True *scheduled* day-of reminders on web need a service worker, which we
// deliberately don't register (it caused white-screen issues). So on web a
// reminder gives an immediate confirmation notification — "Reminder set for X" —
// and the in-app reminder list still tracks it. Day-of firing remains a
// mobile-app feature. Chosen at compile time via conditional import so neither
// package:web nor dart:io leaks into the wrong platform.
import 'web_notify_stub.dart'
    if (dart.library.js_interop) 'web_notify_web.dart';

/// Requests browser notification permission (if needed) and shows an immediate
/// confirmation notification. Returns true if a notification was shown.
/// No-op returning false off the web.
Future<bool> showWebConfirmation(String title, String body) =>
    showWebNotification(title, body);

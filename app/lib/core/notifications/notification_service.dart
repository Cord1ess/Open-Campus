import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper over flutter_local_notifications for scheduling on-device
/// reminders (academic-calendar events, installment deadlines). All scheduling
/// is local — nothing is sent to a server, consistent with the stateless model.
///
/// Web has no local-notification support in this plugin, so calls are no-ops
/// there (guarded by kIsWeb) — the calendar UI still works; reminders just don't
/// fire on web.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  // The academic calendar is a Bangladesh calendar: a "9 AM on the day" reminder
  // means 9 AM *Dhaka time*, not 9 AM wherever the user's device happens to be.
  // We schedule against this fixed zone using the reminder's wall-clock
  // components (see scheduleAt) so it fires at the intended local-to-UIU time.
  tz.Location? _campusZone;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      _campusZone = tz.getLocation('Asia/Dhaka');
      tz.setLocalLocation(_campusZone!);
    } catch (_) {/* fall back to default local */}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// Schedule a one-off reminder at [when]. [id] must be stable per event so we
  /// can cancel/replace it. No-op if [when] is in the past.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (kIsWeb) return;
    await init();
    // Interpret [when]'s wall-clock components in the campus zone (Dhaka) rather
    // than converting the device-local instant — otherwise an off-Bangladesh
    // device would fire the reminder shifted by its UTC offset difference.
    final zone = _campusZone ?? tz.local;
    final scheduled = tz.TZDateTime(
        zone, when.year, when.month, when.day, when.hour, when.minute,
        when.second);
    if (scheduled.isBefore(tz.TZDateTime.now(zone))) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'oc_calendar',
        'Academic calendar',
        channelDescription: 'Reminders for academic events and deadlines',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}

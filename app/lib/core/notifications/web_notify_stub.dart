// Non-web platforms: no browser Notification API. Mobile/desktop reminders go
// through flutter_local_notifications (NotificationService), so this is a no-op.
Future<bool> showWebNotification(String title, String body) async => false;

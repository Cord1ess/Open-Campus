import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: request the browser Notification permission (if not already decided) and
/// show an immediate notification. Uses package:web / dart:js_interop so it
/// compiles under the WASM (skwasm) renderer. Returns true if shown.
Future<bool> showWebNotification(String title, String body) async {
  try {
    // Reading permission throws on browsers without the Notification API
    // (older / some mobile webviews) — caught below → returns false.
    var permission = web.Notification.permission;
    if (permission == 'default') {
      permission = (await web.Notification.requestPermission().toDart).toDart;
    }
    if (permission != 'granted') return false;
    web.Notification(title, web.NotificationOptions(body: body));
    return true;
  } catch (_) {
    return false;
  }
}

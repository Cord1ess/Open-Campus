import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

/// Mobile/desktop: try to hand the calendar data to the OS via a compliant
/// `data:text/calendar` URL. `platformDefault` lets the system route it to a
/// calendar importer where one is registered.
///
/// NOTE (v0.2): reliably opening the calendar app from an `.ics` on a phone
/// needs a real file + share intent (path_provider + share_plus) — deferred to
/// the native build. Here we attempt the data: hand-off and report whether the
/// OS accepted it, so the UI can fall back to the per-event "Add to Google
/// Calendar" links (plain https URLs, which open reliably on mobile) when it
/// doesn't. We do NOT claim success when the OS has no handler.
Future<bool> saveOrOpenIcs(String ics, String filename) async {
  final b64 = base64Encode(utf8.encode(ics));
  final uri = Uri.parse('data:text/calendar;charset=utf-8;base64,$b64');
  try {
    if (!await canLaunchUrl(uri)) return false;
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:url_launcher/url_launcher.dart';

/// Mobile/desktop: hand the PNG to the OS via a `data:image/png` URL so the
/// system can preview/save/share it. Reports whether the OS accepted it.
///
/// NOTE: a first-class native share (save to gallery / share sheet) needs
/// share_plus + path_provider; deferred to the native build. On web — the app's
/// primary target — the Blob download path is fully reliable.
Future<bool> savePng(Uint8List bytes, String filename) async {
  final uri = Uri.parse('data:image/png;base64,${base64Encode(bytes)}');
  try {
    if (!await canLaunchUrl(uri)) return false;
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}

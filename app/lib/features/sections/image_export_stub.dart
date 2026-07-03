import 'dart:typed_data';

/// Fallback when neither dart:js_interop nor dart:io is available. Never used in
/// practice; keeps the conditional import total and the analyzer satisfied.
Future<bool> savePng(Uint8List bytes, String filename) async => false;

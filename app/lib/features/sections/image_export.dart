import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

// Platform-specific delivery: a real PNG download on web, an OS share/save on
// mobile/desktop. Chosen at compile time (same pattern as ics_export).
import 'image_export_stub.dart'
    if (dart.library.js_interop) 'image_export_web.dart'
    if (dart.library.io) 'image_export_io.dart';

/// Render the widget captured by [boundary] to a PNG and hand it off to the
/// platform (download on web, share sheet on mobile). Returns true on success.
///
/// This is the simplest export that works everywhere with no heavy deps: the
/// schedule card is a widget, so a screenshot of it IS the export — no PDF
/// engine, no layout duplication.
Future<bool> exportBoundaryPng(
  RenderRepaintBoundary boundary, {
  required String filename,
  double pixelRatio = 3.0,
}) async {
  try {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return false;
    final bytes = data.buffer.asUint8List();
    return savePng(bytes, filename);
  } catch (_) {
    return false;
  }
}

/// Exposed for callers that already have PNG bytes.
Future<bool> savePngBytes(Uint8List bytes, String filename) =>
    savePng(bytes, filename);

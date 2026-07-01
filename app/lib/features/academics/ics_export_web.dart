import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: trigger a real `.ics` file download via a Blob + temporary anchor.
///
/// Uses package:web / dart:js_interop (NOT the legacy dart:html) so it compiles
/// AND runs under the WASM (skwasm) renderer the app ships — dart:html is
/// unavailable there, which silently routed this to the no-op stub before.
/// A real Blob download is far more reliable than a base64 `data:` URL, which
/// browsers often block or open as text.
Future<bool> saveOrOpenIcs(String ics, String filename) async {
  try {
    // UTF-8 bytes so multi-byte characters survive the Blob.
    final part = utf8.encode(ics).toJS; // JSUint8Array (a valid BlobPart)
    final blob = web.Blob(
      <JSAny>[part].toJS,
      web.BlobPropertyBag(type: 'text/calendar;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor =
        web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = filename
          ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}

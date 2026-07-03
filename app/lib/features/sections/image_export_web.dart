import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: download PNG bytes via a Blob + temporary anchor. Uses package:web /
/// dart:js_interop so it compiles and runs under the WASM (skwasm) renderer.
Future<bool> savePng(Uint8List bytes, String filename) async {
  try {
    final part = bytes.toJS; // JSUint8Array (a valid BlobPart)
    final blob = web.Blob(
      <JSAny>[part].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
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

import 'dart:convert';
import 'dart:html' as html;

/// Web: trigger a real `.ics` file download via a Blob + temporary anchor. This
/// produces an actual file the browser/OS recognises as a calendar import —
/// unlike a base64 `data:` URL, which browsers often block or open as text.
Future<bool> saveOrOpenIcs(String ics, String filename) async {
  try {
    // Encode as UTF-8 bytes so multi-byte characters survive the Blob.
    final bytes = utf8.encode(ics);
    final blob = html.Blob([bytes], 'text/calendar;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}

import 'package:web/web.dart' as web;

/// Web: set (or create) the `<meta name="theme-color">` so the PWA/browser
/// status bar matches the app surface. Uses package:web / dart:js_interop, so it
/// compiles under the WASM (skwasm) renderer. There may be multiple theme-color
/// metas (index.html can define media-scoped ones); we update the primary
/// non-media one and drop any media-scoped ones so ours always wins.
void updateThemeColorMeta(String hex) {
  try {
    final doc = web.document;
    // The selector only matches <meta name="theme-color"> elements, so each node
    // is an HTMLMetaElement — cast directly (a runtime `is` check on JS-interop
    // types is meaningless).
    final metas = doc.querySelectorAll('meta[name="theme-color"]');
    web.HTMLMetaElement? primary;
    for (var i = 0; i < metas.length; i++) {
      final el = metas.item(i) as web.HTMLMetaElement?;
      if (el == null) continue;
      // A media-scoped meta (e.g. prefers-color-scheme) would override ours;
      // neutralize it by clearing its media so our value applies uniformly.
      if (el.media.isNotEmpty) {
        el.media = '';
      }
      primary ??= el;
    }
    if (primary == null) {
      primary = web.HTMLMetaElement()..name = 'theme-color';
      doc.head?.append(primary);
    }
    primary.content = hex;
  } catch (_) {
    // Never let a DOM hiccup break theming.
  }
}

import 'package:flutter/material.dart';

import 'browser_theme_color_stub.dart'
    if (dart.library.js_interop) 'browser_theme_color_web.dart';

/// Updates the browser/PWA `<meta name="theme-color">` so the installed webapp's
/// status bar / toolbar matches the app's current surface — the web equivalent
/// of the native Android status-bar theming. No-op off the web.
///
/// Without this, a PWA (website → Add to Home Screen) keeps the hardcoded white
/// theme-color from index.html and shows a white status bar even in dark mode.
void setBrowserThemeColor(Color surface) {
  // Format as #RRGGBB (theme-color ignores alpha).
  final hex = '#'
      '${(surface.r * 255).round().toRadixString(16).padLeft(2, '0')}'
      '${(surface.g * 255).round().toRadixString(16).padLeft(2, '0')}'
      '${(surface.b * 255).round().toRadixString(16).padLeft(2, '0')}';
  updateThemeColorMeta(hex);
}

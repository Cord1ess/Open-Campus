import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A background/foreground pair for a tonal accent surface. Generated rather
/// than taken from primary/secondary/tertiary, which often collapse to two
/// near-identical hues for a given seed.
class AccentTone {
  final Color background;
  final Color foreground;
  const AccentTone(this.background, this.foreground);
}

/// Harmonized accent tones derived from the theme's primary color. Each tone is
/// the seed hue rotated by a fixed offset at container-appropriate
/// lightness/saturation. Sharing the seed's chroma keeps them reading as a
/// family rather than random colors.
class Accents {
  /// Hue offsets (degrees) applied around the seed hue. Chosen to spread evenly
  /// enough to be distinguishable without leaving the seed's neighbourhood.
  static const _hueOffsets = <double>[0, -28, 30, -56, 58, -84];

  static List<AccentTone> of(BuildContext context) {
    final scheme = context.scheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final seedHsl = HSLColor.fromColor(scheme.primary);

    // Container tones: in light mode pale + saturated bg with a deep fg; in dark
    // mode a deep-but-vivid bg with a light fg. Tuned to match M3 container feel.
    final bgLightness = dark ? 0.22 : 0.90;
    final bgSaturation = dark ? 0.42 : 0.62;
    final fgLightness = dark ? 0.82 : 0.32;
    final fgSaturation = dark ? 0.55 : 0.70;

    return [
      for (final offset in _hueOffsets)
        AccentTone(
          HSLColor.fromAHSL(
            1,
            (seedHsl.hue + offset) % 360,
            bgSaturation,
            bgLightness,
          ).toColor(),
          HSLColor.fromAHSL(
            1,
            (seedHsl.hue + offset) % 360,
            fgSaturation,
            fgLightness,
          ).toColor(),
        ),
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Open Campus brand marks, rendered from the real optimized SVG assets.
///
/// Two distinct marks (per the brand kit):
///   * [BrandIcon] — the icon ONLY (blue + orange mark, no text).
///   * [BrandLogo] — the full lockup: icon + "OPEN CAMPUS" wordmark.
///
/// The marks carry their own blue (#01badd) and orange (#f57f20) colors, and the
/// wordmark is dark, so they are only ever placed on NEUTRAL surfaces (white /
/// dark), never on an orange or blue fill. There is deliberately no "on colored
/// background" variant.
class _BrandAssets {
  static const icon = 'assets/brand/open_campus_icon.svg';
  static const logo = 'assets/brand/open_campus_logo.svg';
}

/// The icon-only mark. Square-ish (source viewBox ~159x168). [size] is the
/// height in logical pixels; width scales to keep the aspect ratio.
class BrandIcon extends StatelessWidget {
  final double size;
  const BrandIcon({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _BrandAssets.icon,
      height: size,
      // Semantics for screen readers; the mark is decorative-but-identifying.
      semanticsLabel: 'Open Campus',
    );
  }
}

/// The full logo lockup (icon + wordmark). The source is a wide horizontal SVG
/// (viewBox ~334x168), so [height] drives the size and width scales to fit.
/// Optionally shown as a centered column ([stacked]) is NOT used — the brand
/// lockup is a single horizontal artwork.
class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 56});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _BrandAssets.logo,
      height: height,
      semanticsLabel: 'Open Campus',
    );
  }
}

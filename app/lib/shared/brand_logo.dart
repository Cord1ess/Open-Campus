import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Combined Open Campus logo mark. PLACEHOLDER — replace with the real asset:
/// drop a logo into assets/ and swap the body for Image.asset(...).
///
/// Designed as a single centered mark (icon + wordmark in one lockup), not a
/// separate icon + text, per the desired login layout.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool onColor; // true when drawn on a colored (primary) background
  const BrandLogo({super.key, this.size = 92, this.onColor = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = onColor ? scheme.onPrimary : scheme.primary;
    final bg = onColor ? scheme.onPrimary.withValues(alpha: 0.15) : scheme.primaryContainer;
    final iconColor = onColor ? scheme.onPrimary : scheme.onPrimaryContainer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          // Placeholder glyph — represents the combined mark.
          child: Icon(Icons.school_rounded, size: size * 0.52, color: iconColor),
        ),
        SizedBox(height: size * 0.18),
        Text(
          'Open Campus',
          style: context.text.headlineSmall?.copyWith(
              color: fg, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ],
    );
  }
}

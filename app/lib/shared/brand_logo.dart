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
    final fg = onColor ? scheme.onPrimary : scheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.orange, // flat brand orange
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Icon(Icons.school_rounded,
              size: size * 0.52, color: Colors.white),
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

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A compact stat tile for page headers. [filled] = solid accent background
/// with white text (a bold focal tile); otherwise a clean white tile with a
/// hairline border, an accent icon chip, and an accent-colored value.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool filled;
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = onAccent(accent); // readable text on the filled accent
    final bg = filled ? accent : scheme.surface;
    final valueColor = filled ? fg : scheme.onSurface;
    final labelColor =
        filled ? fg.withValues(alpha: 0.85) : scheme.onSurfaceVariant;
    final iconBg = filled ? fg.withValues(alpha: 0.20) : accent;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: filled ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            // Filled: icon chip is a translucent fg tint, so use fg. Unfilled:
            // chip is the solid accent, so use the accent's readable foreground.
            child: Icon(icon, size: 16, color: filled ? fg : onAccent(accent)),
          ),
          const SizedBox(height: Spacing.lg),
          // Fixed-height value box: a FittedBox reports its child's UNSCALED
          // intrinsic height, which under IntrinsicHeight overflowed the tile by
          // ~2px. Pinning the height makes the intrinsic measurement exact and
          // still lets long currency values scale down to fit the width.
          SizedBox(
            height: 30,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: context.text.headlineSmall?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w800,
                      height: 1.0)),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: labelColor)),
        ],
      ),
    );
  }
}

/// A responsive row of stat tiles (wraps to fit).
class StatRow extends StatelessWidget {
  final List<Widget> tiles;
  const StatRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight gives the stretch a bounded height; without it the Row's
    // cross-axis is unbounded inside a scroll view and throws (white screen).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: Spacing.md),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

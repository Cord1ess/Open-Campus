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
    final bg = filled ? accent : scheme.surface;
    final valueColor = filled ? Colors.white : scheme.onSurface;
    final labelColor =
        filled ? Colors.white.withValues(alpha: 0.85) : scheme.onSurfaceVariant;
    final iconBg = filled ? Colors.white.withValues(alpha: 0.20) : accent;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: filled ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(height: Spacing.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: context.text.headlineSmall?.copyWith(
                    color: valueColor, fontWeight: FontWeight.w800, height: 1.0)),
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

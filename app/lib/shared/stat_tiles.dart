import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A compact stat tile used in page headers (Academics/Finance summary rows).
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final Color onTone;
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.onTone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: onTone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: onTone),
          ),
          const SizedBox(height: Spacing.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: context.text.headlineSmall?.copyWith(
                    color: onTone, fontWeight: FontWeight.w800, height: 1.0)),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium
                  ?.copyWith(color: onTone.withValues(alpha: 0.85))),
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

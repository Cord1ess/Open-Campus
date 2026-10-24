import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A small semantic label: soft tint background, readable ink text. The only
/// badge/chip style in the app.
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool outlined;
  const StatusBadge(
    this.label, {
    super.key,
    this.tone = StatusTone.neutral,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final ink = p.inkFor(tone, scheme);
    final bg = outlined ? Colors.transparent : p.tintFor(tone, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.xs),
        border: outlined ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: ink),
            const SizedBox(width: Spacing.xs),
          ],
          Text(label,
              style: context.text.labelSmall?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabularFigures)),
        ],
      ),
    );
  }
}

/// A 8-px status dot (for compact lists and legends).
class StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  const StatusDot(this.color, {super.key, this.size = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

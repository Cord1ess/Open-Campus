import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A small pill label: pastel container with dark text (or a translucent white
/// pill with [onColored] when it sits on a colour container).
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool outlined;
  final bool onColored;
  const StatusBadge(
    this.label, {
    super.key,
    this.tone = StatusTone.neutral,
    this.icon,
    this.outlined = false,
    this.onColored = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final fg = onColored
        ? p.onContainer
        : (tone == StatusTone.neutral ? scheme.onSurface : p.onContainer);
    final bg = onColored
        ? Colors.white.withValues(alpha: 0.55)
        : outlined
            ? Colors.transparent
            : p.tintFor(tone, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.full),
        border: outlined && !onColored
            ? Border.all(color: scheme.outlineVariant, width: 1.2)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: Spacing.xs),
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabularFigures)),
          ),
        ],
      ),
    );
  }
}

/// A status dot (compact lists and legends).
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

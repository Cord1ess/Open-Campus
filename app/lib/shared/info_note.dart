import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_icons.dart';

/// A rounded note: pastel container (by tone) or white card (neutral), with a
/// leading icon, optional title and action.
class InfoNote extends StatelessWidget {
  final String text;
  final String? title;
  final IconData icon;
  final StatusTone tone;
  final Widget? action;
  const InfoNote({
    super.key,
    required this.text,
    this.title,
    this.icon = AppIcons.info,
    this.tone = StatusTone.neutral,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final neutral = tone == StatusTone.neutral;
    final fg = neutral ? scheme.onSurface : p.onContainer;
    final sub = neutral
        ? scheme.onSurfaceVariant
        : p.onContainer.withValues(alpha: 0.8);
    final bg = neutral ? scheme.surface : p.tintFor(tone, scheme);
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(title!,
                      style: context.text.titleSmall?.copyWith(color: fg)),
                  const SizedBox(height: Spacing.xxs),
                ],
                Text(text, style: context.text.bodySmall?.copyWith(color: sub)),
                if (action != null) ...[
                  const SizedBox(height: Spacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_icons.dart';

/// A flat note: soft background, leading icon, optional title and action. Used
/// for provenance ("Live from uiu.ac.bd"), caveats, and short instructions.
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
    final ink = neutral ? scheme.onSurfaceVariant : p.inkFor(tone, scheme);
    final bg = neutral ? scheme.surfaceContainerLow : p.tintFor(tone, scheme);
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: ink),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(title!,
                      style: context.text.titleSmall?.copyWith(
                          color: neutral ? scheme.onSurface : ink)),
                  const SizedBox(height: Spacing.xxs),
                ],
                Text(text,
                    style: context.text.bodySmall?.copyWith(
                        color: neutral ? scheme.onSurfaceVariant : ink)),
                if (action != null) ...[
                  const SizedBox(height: Spacing.sm),
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

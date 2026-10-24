import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';

/// Which sensitive figures the user has revealed this session. Everything
/// starts hidden on every launch; revealing one figure reveals it on every
/// screen (CGPA on the dashboard and on Results stay in sync).
final revealedSecretsProvider = StateProvider<Set<String>>((_) => const {});

/// Stable ids for the figures that are hidden by default.
class Secrets {
  static const cgpa = 'cgpa';
  static const totalPaid = 'total_paid';
}

/// A value that is masked ("• • • •") until the eye button is pressed.
class SecretText extends ConsumerWidget {
  final String id;
  final String value;
  final TextStyle? style;
  final Color? iconColor;
  final double iconSize;
  const SecretText({
    super.key,
    required this.id,
    required this.value,
    this.style,
    this.iconColor,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(revealedSecretsProvider).contains(id);
    final color = iconColor ?? style?.color ?? context.scheme.onSurface;
    void toggle() {
      final set = {...ref.read(revealedSecretsProvider)};
      shown ? set.remove(id) : set.add(id);
      ref.read(revealedSecretsProvider.notifier).state = set;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(a), child: c),
            ),
            child: Text(
              shown ? value : '••••',
              key: ValueKey(shown),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: style,
            ),
          ),
        ),
        const SizedBox(width: Spacing.xs),
        Semantics(
          button: true,
          label: shown ? 'Hide value' : 'Show value',
          child: InkResponse(
            onTap: toggle,
            radius: iconSize + 6,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: iconSize,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

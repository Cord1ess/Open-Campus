import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_icons.dart';

/// Loading: a plain indicator with an optional label. No halo, no shimmer.
class LoadingState extends StatelessWidget {
  final String? label;
  final double verticalPadding;
  const LoadingState({super.key, this.label, this.verticalPadding = Spacing.xxl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            if (label != null) ...[
              const SizedBox(height: Spacing.md),
              Text(label!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state: icon, title, optional explanation and one optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final bool compact;
  const EmptyState({
    super.key,
    this.icon = AppIcons.empty,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: compact ? Spacing.lg : Spacing.xxl, horizontal: Spacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 24 : 32, color: scheme.onSurfaceVariant),
              SizedBox(height: compact ? Spacing.sm : Spacing.md),
              Text(title,
                  textAlign: TextAlign.center, style: context.text.titleSmall),
              if (message != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(message!,
                    textAlign: TextAlign.center, style: context.text.bodySmall),
              ],
              if (onAction != null) ...[
                const SizedBox(height: Spacing.lg),
                actionIcon != null
                    ? FilledButton.tonalIcon(
                        onPressed: onAction,
                        icon: Icon(actionIcon, size: 18),
                        label: Text(actionLabel ?? 'Retry'),
                      )
                    : FilledButton.tonal(
                        onPressed: onAction,
                        child: Text(actionLabel ?? 'Retry'),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with a retry action.
class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;
  const ErrorState({
    super.key,
    this.title = 'Couldn’t load',
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: AppIcons.offline,
        title: title,
        message: message,
        actionLabel: 'Try again',
        actionIcon: AppIcons.refresh,
        onAction: onRetry,
        compact: compact,
      );
}

/// One-line freshness indicator shown above cached content: tells the user
/// the data is an on-device copy, when it was fetched, and (if a refresh just
/// failed) why, with a retry.
class FreshnessLine extends StatelessWidget {
  final DateTime? at;
  final bool live;
  final String? error;
  final VoidCallback? onRetry;
  const FreshnessLine({
    super.key,
    this.at,
    this.live = false,
    this.error,
    this.onRetry,
  });

  static String ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (live && error == null) return const SizedBox.shrink();
    final p = context.palette;
    final tone = error != null ? StatusTone.warning : StatusTone.neutral;
    final ink = p.inkFor(tone, context.scheme);
    final when = at != null ? ' · updated ${ago(at!)}' : '';
    final text = error != null
        ? 'Couldn’t refresh — showing saved copy$when'
        : 'Saved copy$when';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: [
          Icon(error != null ? AppIcons.offline : AppIcons.time,
              size: 14, color: ink),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: ink)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  visualDensity: VisualDensity.compact),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

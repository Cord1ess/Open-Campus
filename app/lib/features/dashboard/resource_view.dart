import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import 'dashboard_controller.dart';

/// Renders a `ResourceState` as a SectionCard with loading/error/data states,
/// including the freshness chip. Keeps each page DRY.
class ResourceSection<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final ResourceState<T> state;
  final Widget Function(T data) builder;
  final Widget loadingSkeleton;
  final VoidCallback? onRetry;
  /// When set, the card title becomes tappable (shows an arrow) and opens the
  /// full page. Used on the dashboard so Results/Attendance cards link through
  /// without hijacking the in-card chart/accordion/filter interactions.
  final VoidCallback? onOpen;

  const ResourceSection({
    super.key,
    required this.title,
    required this.icon,
    required this.state,
    required this.builder,
    required this.loadingSkeleton,
    this.onRetry,
    this.onOpen,
  });

  Widget? _openAffordance(BuildContext context) {
    if (onOpen == null) return null;
    final scheme = context.scheme;
    return SpringTap(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(Radii.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Open',
                style: context.text.labelSmall?.copyWith(
                    color: scheme.primary, fontWeight: FontWeight.w800)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_forward_rounded, size: 14, color: scheme.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ResLoading<T>() => SectionCard(
          title: title, icon: icon, child: loadingSkeleton),
      ResError<T>(:final message) => SectionCard(
          title: title,
          icon: icon,
          child: StateMessage(
            icon: Icons.cloud_off,
            title: 'Couldn\'t load',
            subtitle: message,
            actionLabel: 'Try again',
            onAction: onRetry,
          ),
        ),
      ResData<T>(:final loaded) => SectionCard(
          title: title,
          icon: icon,
          trailing: onOpen != null
              ? _openAffordance(context)
              : FreshnessChip(freshness: loaded.freshness, at: loaded.syncedAt),
          child: builder(loaded.data),
        ),
    };
  }
}

/// Standard in-card loading state. Kept named `CardSkeleton` for its many call
/// sites, but it now shows the app's unified [LoadingIndicator] (a circular
/// progress ring) instead of shimmer bars. [lines]/[chart] are retained for API
/// compatibility but no longer affect the look.
class CardSkeleton extends StatelessWidget {
  final int lines;
  final bool chart;
  final String? label;
  const CardSkeleton(
      {super.key, this.lines = 3, this.chart = false, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(child: LoadingIndicator(label: label));
  }
}

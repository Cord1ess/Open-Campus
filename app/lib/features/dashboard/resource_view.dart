import 'package:flutter/material.dart';

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

  const ResourceSection({
    super.key,
    required this.title,
    required this.icon,
    required this.state,
    required this.builder,
    required this.loadingSkeleton,
    this.onRetry,
  });

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
          trailing:
              FreshnessChip(freshness: loaded.freshness, at: loaded.syncedAt),
          child: builder(loaded.data),
        ),
    };
  }
}

/// Standard skeletons.
class CardSkeleton extends StatelessWidget {
  final int lines;
  final bool chart;
  const CardSkeleton({super.key, this.lines = 3, this.chart = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chart) ...[
          const Skeleton(height: 120, radius: 16),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Skeleton(height: 14, width: i.isEven ? null : 180),
        ],
      ],
    );
  }
}

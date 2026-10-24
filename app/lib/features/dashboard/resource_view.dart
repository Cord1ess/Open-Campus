import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import 'dashboard_controller.dart';

/// Renders a [ResourceState]: loading → [LoadingState], error → [ErrorState],
/// data → [builder], with a [FreshnessLine] above cached data so the user can
/// see they are looking at an on-device copy (and why, if a refresh failed).
class ResourceBody<T> extends StatelessWidget {
  final ResourceState<T> state;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final String? loadingLabel;
  final bool showFreshness;
  final String? errorTitle;

  const ResourceBody({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
    this.loadingLabel,
    this.showFreshness = true,
    this.errorTitle,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ResLoading<T>() => LoadingState(label: loadingLabel),
      ResError<T>(:final message) => ErrorState(
          title: errorTitle ?? 'Couldn’t load',
          message: message,
          onRetry: onRetry,
        ),
      ResData<T>(:final loaded, :final staleReason) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showFreshness && loaded.freshness == Freshness.cached)
              FreshnessLine(
                at: loaded.syncedAt,
                error: staleReason,
                onRetry: staleReason != null ? onRetry : null,
              ),
            builder(loaded.data),
          ],
        ),
    };
  }
}

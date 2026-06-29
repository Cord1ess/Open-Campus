import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Material 3 large top app bar: one title that morphs between large (expanded)
/// and compact (pinned, always reachable) as the user scrolls. Page content goes
/// in [slivers].
class CollapsingTitleScrollView extends StatelessWidget {
  final String title;
  final List<Widget> slivers;

  /// Optional actions shown in the compact bar (e.g. a refresh button).
  final List<Widget>? actions;

  /// Optional pull-to-refresh handler. When provided the whole view becomes a
  /// RefreshIndicator.
  final Future<void> Function()? onRefresh;

  const CollapsingTitleScrollView({
    super.key,
    required this.title,
    required this.slivers,
    this.actions,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final scroll = CustomScrollView(
      slivers: [
        SliverAppBar.large(
          pinned: true,
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: Text(title),
          titleTextStyle: context.text.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
          actions: actions,
          expandedHeight: 132,
        ),
        ...slivers,
      ],
    );
    if (onRefresh == null) return scroll;
    return RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

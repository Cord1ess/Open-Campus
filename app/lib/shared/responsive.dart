import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Layout breakpoints. Phones get a single column; tablets/desktop fill the
/// wider working area (see app_shell `_MaxWidth`) with multi-column grids.
class Breakpoints {
  /// At or above this width we treat the layout as "wide" (tablet/desktop) and
  /// switch single-column lists into multi-column grids.
  static const wide = 760.0;
  static const desktop = 1100.0;

  static bool isWide(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= wide;
  static bool isDesktop(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= desktop;

  /// Column count for a flowing card grid given the current width.
  static int columns(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= desktop) return 3;
    if (w >= wide) return 2;
    return 1;
  }
}

/// Lays [children] out in a responsive grid of [columns] (defaults to the
/// breakpoint-derived count), with even spacing. Rows are built manually (not
/// GridView) so each cell sizes to its content and the grid composes cleanly
/// inside a CustomScrollView's SliverList.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? columns;
  final double spacing;
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columns,
    this.spacing = Spacing.md,
  });

  @override
  Widget build(BuildContext context) {
    final cols = columns ?? Breakpoints.columns(context);
    if (cols <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final cells = <Widget>[];
      for (var j = 0; j < cols; j++) {
        final idx = i + j;
        if (j > 0) cells.add(SizedBox(width: spacing));
        cells.add(Expanded(
          child: idx < children.length ? children[idx] : const SizedBox(),
        ));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cells,
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

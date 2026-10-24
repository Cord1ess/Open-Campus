import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Window-size classes (Material 3): compact phones, medium tablets / split
/// screens, expanded desktop. One source of truth for every layout switch.
class Breakpoints {
  static const medium = 600.0;
  static const expanded = 840.0;
  static const large = 1200.0;

  /// Readable ceiling for page content. Beyond this the gutters grow.
  static const contentMaxWidth = 1040.0;

  /// Ceiling for single-column forms (login, tool inputs).
  static const formMaxWidth = 480.0;

  static double width(BuildContext c) => MediaQuery.sizeOf(c).width;
  static bool isCompact(BuildContext c) => width(c) < medium;
  static bool isMedium(BuildContext c) =>
      width(c) >= medium && width(c) < expanded;
  static bool isExpanded(BuildContext c) => width(c) >= expanded;

  /// Legacy aliases.
  static bool isWide(BuildContext c) => width(c) >= medium;
  static bool isDesktop(BuildContext c) => isExpanded(c);

  /// Horizontal page gutter for the current width.
  static double gutter(BuildContext c) =>
      isCompact(c) ? Spacing.lg : Spacing.xl;

  /// Column count for a flowing grid of equal cards.
  static int columns(BuildContext c, {int max = 3}) {
    final w = width(c);
    if (w >= large) return max;
    if (w >= expanded) return max >= 2 ? 2 : 1;
    if (w >= medium) return max >= 2 ? 2 : 1;
    return 1;
  }

  /// Padding that centres content of [maxWidth] inside [totalWidth], never
  /// smaller than the page gutter.
  static EdgeInsets centeredPadding(BuildContext c,
      {double? maxWidth, double? totalWidth}) {
    final total = totalWidth ?? width(c);
    final g = gutter(c);
    final max = maxWidth ?? contentMaxWidth;
    final side = total > max + g * 2 ? (total - max) / 2 : g;
    return EdgeInsets.symmetric(horizontal: side);
  }
}

/// Lays [children] out in a responsive grid of [columns] (defaults to the
/// breakpoint-derived count). Rows are built manually so each cell sizes to its
/// content and the grid composes inside a scroll view.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? columns;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  /// Stretch cells in a row to equal height (cards); false keeps each cell at
  /// its natural height, top-aligned (lists of differing length).
  final bool stretch;
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columns,
    this.maxColumns = 3,
    this.spacing = Spacing.lg,
    this.runSpacing = Spacing.lg,
    this.stretch = true,
  });

  @override
  Widget build(BuildContext context) {
    final cols = columns ?? Breakpoints.columns(context, max: maxColumns);
    if (cols <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: runSpacing),
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
      if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
      final row = Row(
        crossAxisAlignment:
            stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: cells,
      );
      rows.add(stretch ? IntrinsicHeight(child: row) : row);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Two children side by side on medium+ widths, stacked on compact. The
/// [ratio] is the left child's flex share (0..1).
class TwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double ratio;
  final double spacing;
  final bool stretch;
  const TwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.ratio = 0.5,
    this.spacing = Spacing.lg,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, SizedBox(height: spacing), right],
      );
    }
    final l = (ratio * 100).round().clamp(1, 99);
    final row = Row(
      crossAxisAlignment:
          stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        Expanded(flex: l, child: left),
        SizedBox(width: spacing),
        Expanded(flex: 100 - l, child: right),
      ],
    );
    return stretch ? IntrinsicHeight(child: row) : row;
  }
}

/// Constrains a form or action area so it never stretches across a desktop
/// window. Left-aligned on wide screens (reads as part of the page), full width
/// on phones.
class FormWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Alignment alignment;
  const FormWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.formMaxWidth,
    this.alignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

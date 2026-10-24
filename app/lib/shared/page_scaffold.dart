import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'responsive.dart';

/// The one page frame used by every screen: a standard 56-px pinned app bar,
/// optional pull-to-refresh, and content centred to a readable width with
/// consistent gutters. On desktop the title and actions align with the content
/// column so the page reads as one block instead of a title stranded at the
/// window edge.
///
/// Pass either [body] (a single boxed widget, the common case) or [slivers]
/// (for lazy lists). The bottom safe-area inset is handled here, so pages no
/// longer add their own spacer.
class PageScaffold extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final Widget? body;
  final List<Widget>? slivers;
  final Widget? floatingActionButton;
  final double maxWidth;
  final bool? showBack;
  final ScrollController? controller;

  /// Vertical space between the app bar and the first content.
  final double topGap;

  const PageScaffold({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.onRefresh,
    this.body,
    this.slivers,
    this.floatingActionButton,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.showBack,
    this.controller,
    this.topGap = Spacing.sm,
  }) : assert(body != null || slivers != null,
            'Provide either body or slivers');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = showBack ?? (ModalRoute.of(context)?.canPop ?? false);
    final pad = Breakpoints.centeredPadding(context, maxWidth: maxWidth);
    final bottomInset = MediaQuery.paddingOf(context).bottom + Spacing.xxl;

    // Keep the title flush with the content column. The leading button is
    // 56 wide, so subtract it when present.
    final titleSpacing = (canPop ? pad.left - 56 : pad.left)
        .clamp(Spacing.lg, double.infinity)
        .toDouble();
    final actionsEnd = (pad.right - Spacing.sm).clamp(Spacing.xs, 999.0);

    final appBar = SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: canPop,
      titleSpacing: titleSpacing,
      systemOverlayStyle: appBarOverlayStyle(isDark),
      title: titleWidget ??
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions == null
          ? null
          : [...actions!, SizedBox(width: actionsEnd)],
    );

    final content = <Widget>[
      appBar,
      if (body != null)
        SliverPadding(
          padding: pad.copyWith(top: topGap, bottom: bottomInset),
          sliver: SliverToBoxAdapter(child: body),
        ),
      if (slivers != null) ...[
        SliverPadding(
            padding: EdgeInsets.only(top: topGap),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink())),
        for (final s in slivers!) SliverPadding(padding: pad, sliver: s),
        SliverPadding(
            padding: EdgeInsets.only(bottom: bottomInset),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink())),
      ],
    ];

    Widget scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: content,
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: 56,
        child: scroll,
      );
    }
    return Scaffold(
      body: scroll,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Vertical rhythm helper: children separated by [gap] (default section gap).
class Stacked extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;
  const Stacked({
    super.key,
    required this.children,
    this.gap = Spacing.xl,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}

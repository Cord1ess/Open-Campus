import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_icons.dart';
import 'list_row.dart';
import 'responsive.dart';

/// Extra bottom space the app shell needs pages to leave free (the floating
/// navigation bar sits over the content on phones).
class ShellInsets extends InheritedWidget {
  final double bottom;
  const ShellInsets({super.key, required this.bottom, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellInsets>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(ShellInsets old) => old.bottom != bottom;
}

/// The page frame used by every screen.
///
/// Pushed pages get a circular back button and a centred title. Top-level tab
/// pages ([showBack] false) get a large bold title at the left. Content is
/// centred to a readable width with consistent gutters on a soft canvas, and
/// the bottom inset (safe area + floating nav) is handled here.
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
    // Centre within the space this page actually gets (beside the sidebar on
    // desktop), not the whole window.
    return LayoutBuilder(
        builder: (context, c) => _build(context, c.maxWidth));
  }

  Widget _build(BuildContext context, double available) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = showBack ?? (ModalRoute.of(context)?.canPop ?? false);
    final pad = Breakpoints.centeredPadding(context,
        maxWidth: maxWidth, totalWidth: available);
    final bottomInset = MediaQuery.paddingOf(context).bottom +
        ShellInsets.of(context) +
        Spacing.xxl;
    final canvas = context.palette.canvas;

    final edgeActions = actions == null
        ? null
        : <Widget>[
            ...actions!,
            SizedBox(width: (pad.right - Spacing.xs).clamp(Spacing.sm, 999.0)),
          ];

    final SliverAppBar appBar;
    if (canPop) {
      appBar = SliverAppBar(
        pinned: true,
        backgroundColor: canvas,
        toolbarHeight: 64,
        systemOverlayStyle: appBarOverlayStyle(isDark),
        leadingWidth: pad.left + 44,
        leading: Padding(
          padding: EdgeInsets.only(left: pad.left),
          child: Center(
            child: CircleButton(
              icon: AppIcons.back,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        centerTitle: true,
        title: titleWidget ??
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge),
        actions: edgeActions,
      );
    } else {
      appBar = SliverAppBar(
        pinned: true,
        backgroundColor: canvas,
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        systemOverlayStyle: appBarOverlayStyle(isDark),
        centerTitle: false,
        titleSpacing: pad.left,
        title: titleWidget ??
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineMedium),
        actions: edgeActions,
      );
    }

    final content = <Widget>[
      appBar,
      if (body != null)
        SliverPadding(
          padding: pad.copyWith(top: topGap, bottom: bottomInset),
          sliver: SliverToBoxAdapter(child: body),
        ),
      if (slivers != null) ...[
        SliverToBoxAdapter(child: SizedBox(height: topGap)),
        for (final s in slivers!) SliverPadding(padding: pad, sliver: s),
        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
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
        edgeOffset: 64,
        child: scroll,
      );
    }
    return Scaffold(
      backgroundColor: canvas,
      body: scroll,
      floatingActionButton: floatingActionButton == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: ShellInsets.of(context)),
              child: floatingActionButton,
            ),
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
    this.gap = Spacing.xl + 4,
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

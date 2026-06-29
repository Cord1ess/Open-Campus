import 'package:flutter/material.dart';

/// A sliver app bar with the Android Material 3 "large top app bar" behaviour:
/// a SINGLE title that smoothly scales and slides from its large expanded
/// position to the small collapsed position next to the leading (back) button
/// as you scroll — one continuous widget, no cross-fade, always visible.
///
/// This is built on Flutter's [FlexibleSpaceBar], which performs the
/// scale + position interpolation for us. The crossfade you get from
/// `SliverAppBar.large` happens because it sets BOTH a toolbar `title` and a
/// flexible-space title; here we set ONLY the flexible-space title, so there's
/// exactly one title and it morphs continuously.
///
/// Drop-in replacement for `SliverAppBar.large`.
class SliverCollapsingAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  /// Force-show/hide the leading back button. Defaults to auto (shown when the
  /// route can pop).
  final bool? showBack;

  const SliverCollapsingAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPop = showBack ?? Navigator.of(context).canPop();

    return SliverAppBar(
      pinned: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      // Subtle hairline once content scrolls under, no color wash.
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: canPop,
      actions: actions,
      // Large-app-bar geometry: standard toolbar + room for the expanded title.
      toolbarHeight: kToolbarHeight,
      expandedHeight: kToolbarHeight + 72,
      // No `title:` here — that's what causes the crossfade. The FlexibleSpaceBar
      // owns the single morphing title.
      //
      // FlexibleSpaceBar bottom-aligns the collapsed title via titlePadding.bottom,
      // while the leading IconButton is vertically CENTERED. To line the collapsed
      // title up with the back button we give it a fixed line height (height: 1.0
      // → text box == fontSize) and a bottom padding that centers that box on the
      // toolbar's center line: (toolbarHeight - fontSize) / 2.
      flexibleSpace: FlexibleSpaceBar(
        // Indent past the leading (back) button when present so the expanded
        // title doesn't sit on top of the back icon. 56 = leading width.
        titlePadding: EdgeInsetsDirectional.only(
            start: canPop ? 56 : 16, bottom: _titleBottom),
        expandedTitleScale: 1.6,
        collapseMode: CollapseMode.pin,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: _titleFontSize,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  static const double _titleFontSize = 22;
  static const double _titleBottom = (kToolbarHeight - _titleFontSize) / 2;
}

/// Convenience scaffold body: a [SliverCollapsingAppBar] followed by [slivers].
/// Optional pull-to-refresh wraps the whole scroll view.
class CollapsingTitleScrollView extends StatelessWidget {
  final String title;
  final List<Widget> slivers;
  final List<Widget>? actions;
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
    final scroll = CustomScrollView(
      slivers: [
        SliverCollapsingAppBar(title: title, actions: actions),
        ...slivers,
      ],
    );
    if (onRefresh == null) return scroll;
    return RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

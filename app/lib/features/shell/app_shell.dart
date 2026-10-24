import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/brand_logo.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/dashboard_page.dart';
import '../hubs/academics_hub.dart';
import '../hubs/finance_hub.dart';
import '../hubs/services_hub.dart';

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Destination(this.label, this.icon, this.selectedIcon);
}

const _items = <_Destination>[
  _Destination('Home', AppIcons.home, AppIcons.homeSelected),
  _Destination('Academics', AppIcons.academics, AppIcons.academicsSelected),
  _Destination('Finance', AppIcons.finance, AppIcons.financeSelected),
  _Destination('Services', AppIcons.services, AppIcons.servicesSelected),
];

/// Top-level navigation. Phones: a floating dark pill bar whose selected tab
/// expands into a light pill with its label. Medium/expanded widths: a pill
/// sidebar (icons only below 1200 px, icons + labels above). Tabs live in an
/// IndexedStack so each keeps its scroll position and data.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeProvider.notifier).ensureLoaded();
      ref.read(noticesProvider.notifier).ensureLoaded();
      ref.read(resultsProvider.notifier).ensureLoaded();
      ref.read(attendanceProvider.notifier).ensureLoaded();
    });
  }

  static const _pages = <Widget>[
    DashboardPage(),
    AcademicsHub(),
    FinanceHub(),
    ServicesHub(),
  ];

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final width = Breakpoints.width(context);
    final canvas = context.palette.canvas;
    final body = IndexedStack(
      index: _index,
      sizing: StackFit.expand,
      children: _pages,
    );

    if (width >= Breakpoints.medium) {
      final extended = width >= Breakpoints.large;
      return Scaffold(
        backgroundColor: canvas,
        body: Row(
          children: [
            _SideBar(index: _index, onSelect: _select, extended: extended),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Phone: the bar floats over the content; pages leave room via ShellInsets.
    const navHeight = 64.0 + Spacing.lg;
    return Scaffold(
      backgroundColor: canvas,
      extendBody: true,
      body: ShellInsets(bottom: navHeight, child: body),
      bottomNavigationBar: _FloatingBar(index: _index, onSelect: _select),
    );
  }
}

class _FloatingBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _FloatingBar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Spacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              height: 64,
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: p.ink,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      flex: i == index ? 2 : 1,
                      child: _BarItem(
                        item: _items[i],
                        selected: i == index,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final _Destination item;
  final bool selected;
  final VoidCallback onTap;
  const _BarItem(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.ink : p.onInk.withValues(alpha: 0.72);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasizedDecelerate,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? p.onInk : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? item.selectedIcon : item.icon,
                      size: 22, color: fg),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: context.text.labelLarge?.copyWith(
                              color: fg, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final bool extended;
  const _SideBar(
      {required this.index, required this.onSelect, required this.extended});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SafeArea(
      right: false,
      child: Container(
        width: extended ? 248 : 96,
        margin: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.lg, 0, Spacing.lg),
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.xl),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
        child: Column(
          crossAxisAlignment:
              extended ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(
                  left: extended ? Spacing.sm : 0, bottom: Spacing.xl + 4),
              child: extended
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: BrandLogo(height: 36))
                  : const BrandIcon(size: 32),
            ),
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const SizedBox(height: Spacing.sm),
              _SideItem(
                item: _items[i],
                selected: i == index,
                extended: extended,
                onTap: () => onSelect(i),
              ),
            ],
            const Spacer(),
            if (extended)
              Padding(
                padding: const EdgeInsets.only(left: Spacing.sm),
                child: Text('Unofficial UCAM companion',
                    style: context.text.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final _Destination item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;
  const _SideItem({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = context.scheme;
    final fg = selected ? p.onInk : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasizedDecelerate,
            height: 52,
            width: extended ? null : 64,
            padding: EdgeInsets.symmetric(
                horizontal: extended ? Spacing.lg : 0),
            decoration: BoxDecoration(
              color: selected ? p.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(selected ? item.selectedIcon : item.icon,
                      size: 22, color: fg),
                  if (extended) ...[
                    const SizedBox(width: Spacing.md),
                    Text(item.label,
                        style: context.text.labelLarge?.copyWith(
                            color: fg,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

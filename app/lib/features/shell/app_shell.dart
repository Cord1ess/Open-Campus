import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/app_icons.dart';
import '../../shared/brand_logo.dart';
import '../../shared/responsive.dart';
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

/// Top-level navigation: a standard bottom navigation bar on phones, a
/// navigation rail on medium/expanded widths (extended with labels beside the
/// icons from 1200 px). Tabs stay alive in an IndexedStack so each keeps its
/// scroll position and loaded data.
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
    // Mount the UI first, then kick off the data fetches so the first fetch
    // never races the restored auth token.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeProvider.notifier).ensureLoaded();
      ref.read(noticesProvider.notifier).ensureLoaded();
      ref.read(resultsProvider.notifier).ensureLoaded();
      ref.read(attendanceProvider.notifier).ensureLoaded();
    });
  }

  static const _items = <_Destination>[
    _Destination('Home', AppIcons.home, AppIcons.homeSelected),
    _Destination('Academics', AppIcons.academics, AppIcons.academicsSelected),
    _Destination('Finance', AppIcons.finance, AppIcons.financeSelected),
    _Destination('Services', AppIcons.services, AppIcons.servicesSelected),
  ];

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
    final useRail = width >= Breakpoints.expanded;
    final extended = width >= Breakpoints.large;

    final body = IndexedStack(
      index: _index,
      sizing: StackFit.expand,
      children: _pages,
    );

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _select,
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                groupAlignment: -1,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, Spacing.md, Spacing.lg, Spacing.xl),
                  child: extended
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: BrandLogo(height: 30))
                      : const BrandIcon(size: 28),
                ),
                destinations: [
                  for (final it in _items)
                    NavigationRailDestination(
                      icon: Icon(it.icon),
                      selectedIcon: Icon(it.selectedIcon),
                      label: Text(it.label),
                      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              for (final it in _items)
                NavigationDestination(
                  icon: Icon(it.icon),
                  selectedIcon: Icon(it.selectedIcon),
                  label: it.label,
                  tooltip: it.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

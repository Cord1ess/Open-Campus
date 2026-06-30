import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/dashboard_page.dart';
import '../hubs/academics_hub.dart';
import '../hubs/finance_hub.dart';
import '../hubs/services_hub.dart';
import 'floating_nav_bar.dart';

/// Top-level navigation shell with a floating Expressive nav bar. The body
/// extends behind the bar; pages add bottom padding so content clears it.
/// On wide screens it switches to a NavigationRail.
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
    // Let the shell + dashboard UI mount FIRST, then kick off the data fetches.
    // This avoids the race where providers fetched at creation time beat the
    // auth token / first frame and left the app blank until a manual reload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeProvider.notifier).ensureLoaded();
      ref.read(noticesProvider.notifier).ensureLoaded();
      ref.read(resultsProvider.notifier).ensureLoaded();
      ref.read(attendanceProvider.notifier).ensureLoaded();
    });
  }

  static const _items = <NavItem>[
    NavItem('Home', Icons.dashboard_outlined, Icons.dashboard_rounded),
    NavItem('Academics', Icons.school_outlined, Icons.school_rounded),
    NavItem('Finance', Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded),
    NavItem('Services', Icons.apps_outlined, Icons.apps_rounded),
  ];

  static const _pages = <Widget>[
    DashboardPage(),
    AcademicsHub(),
    FinanceHub(),
    ServicesHub(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    // IndexedStack keeps all four tabs alive, so switching tabs preserves each
    // page's scroll position and loaded data instead of rebuilding (and
    // re-fetching) it every visit. Content width is capped per page.
    final body = IndexedStack(
      index: _index,
      sizing: StackFit.expand,
      children: [
        for (final page in _pages) _MaxWidth(child: page),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              // Wider rail + circular selection indicator with room to breathe,
              // so the selected icon sits in a clean circle (not a squashed pill).
              minWidth: 88,
              groupAlignment: -0.85,
              useIndicator: true,
              destinations: [
                for (final it in _items)
                  NavigationRailDestination(
                    icon: Icon(it.icon),
                    selectedIcon: Icon(it.selectedIcon),
                    label: Text(it.label),
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: FloatingNavBar(
        items: _items,
        index: _index,
        onSelect: _select,
      ),
    );
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }
}

/// Caps page content width and centers it. On phones/tablets the content fills
/// the width; on desktop it expands to a generous working width (so the app
/// uses the screen instead of sitting as a narrow tablet column) while still
/// capping at an ultrawide ceiling for readability. Pages lay their content out
/// in responsive grids (see [Breakpoints]) to fill this space.
class _MaxWidth extends StatelessWidget {
  final Widget child;
  const _MaxWidth({required this.child});

  // Ultrawide ceiling — beyond this, padding grows instead of line length.
  static const _max = 1320.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _max) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _max),
        child: child,
      ),
    );
  }
}

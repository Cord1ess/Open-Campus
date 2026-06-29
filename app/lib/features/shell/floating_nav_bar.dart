import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';

class NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const NavItem(this.label, this.icon, this.selectedIcon);
}

/// A floating, pill-shaped Material 3 Expressive navigation bar.
///
/// Pattern (overflow-proof + responsive): unselected items are compact (icon
/// only); the SELECTED item expands into a labelled pill sized to its content.
/// The expansion animates with emphasized easing, so the pill appears to grow
/// and glide as you switch tabs. Sizes scale down on very narrow screens.
class FloatingNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final width = MediaQuery.sizeOf(context).width;
    // Compact mode on small phones to guarantee everything fits.
    final compact = width < 380;

    return SafeArea(
      top: false,
      // Column with min height hugs the bottom; Row centers horizontally.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? Spacing.md : Spacing.xl, 0,
                compact ? Spacing.md : Spacing.xl, Spacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(Radii.full),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _NavButton(
                          item: items[i],
                          selected: i == index,
                          compact: compact,
                          onTap: () => onSelect(i),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _NavButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final iconSize = compact ? 22.0 : 24.0;
    final hPad = selected ? (compact ? 14.0 : 18.0) : (compact ? 12.0 : 14.0);

    return SpringTap(
      onTap: onTap,
      pressScale: 0.9,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.emphasizedDecelerate,
        height: compact ? 48 : 52,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                key: ValueKey(selected),
                color: fg,
                size: iconSize,
              ),
            ),
            // Label only on the selected item; width animates open/closed.
            ClipRect(
              child: AnimatedAlign(
                duration: Motion.medium,
                curve: Motion.emphasizedDecelerate,
                alignment: Alignment.centerLeft,
                widthFactor: selected ? 1.0 : 0.0,
                child: Padding(
                  padding: EdgeInsets.only(left: compact ? 6 : 8),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: (compact
                            ? context.text.labelMedium
                            : context.text.labelLarge)
                        ?.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

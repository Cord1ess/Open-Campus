import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets.dart';

/// Appearance settings: pick a source color (the whole palette derives from it,
/// Material-You style) and a theme mode (Light / Dark / Pitch black).
class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final scheme = context.scheme;

    return SectionCard(
      title: 'Appearance',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accent color',
              style: context.text.labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text('Everything else is shaded from this one color.',
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: [
              for (final (name, color) in SeedSwatches.all)
                _Swatch(
                  name: name,
                  color: color,
                  selected: prefs.seed.toARGB32() == color.toARGB32(),
                  onTap: () => controller.setSeed(color),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          Text('Theme',
              style: context.text.labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.md),
          _ModeSelector(
            mode: prefs.mode,
            onSelect: controller.setMode,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SpringTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.full),
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.emphasized,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: selected ? 10 : 0,
              spreadRadius: selected ? 1 : 0,
            ),
          ],
        ),
        child: selected
            ? Icon(Icons.check,
                // Contrast against the swatch itself (white check is invisible
                // on light swatches like lime/yellow).
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                size: 22)
            : null,
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onSelect;
  const _ModeSelector({required this.mode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeTile(
          icon: Icons.light_mode_outlined,
          label: 'Light',
          selected: mode == AppThemeMode.light,
          onTap: () => onSelect(AppThemeMode.light),
        ),
        const SizedBox(width: Spacing.sm),
        _ModeTile(
          icon: Icons.dark_mode_outlined,
          label: 'Dark',
          selected: mode == AppThemeMode.dark,
          onTap: () => onSelect(AppThemeMode.dark),
        ),
        const SizedBox(width: Spacing.sm),
        _ModeTile(
          icon: Icons.contrast,
          label: 'Pitch black',
          selected: mode == AppThemeMode.black,
          onTap: () => onSelect(AppThemeMode.black),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Expanded(
      child: SpringTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

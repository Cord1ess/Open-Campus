import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  const SegmentOption(this.value, this.label, {this.icon, this.enabled = true});
}

/// Pill segmented control: a white track with the selected option as a dark
/// ink pill (Expressive "connected button group"). [expand] fills the width
/// (2–4 options); when false the options size to content and scroll
/// horizontally (e.g. a trimester picker).
class SegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;
  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final segments = <Widget>[
      for (var i = 0; i < options.length; i++) ...[
        if (!expand && i > 0) const SizedBox(width: Spacing.xs),
        _Segment<T>(
          option: options[i],
          selected: options[i].value == value,
          expand: expand,
          onTap: options[i].enabled && options[i].value != value
              ? () => onChanged(options[i].value)
              : null,
        ),
      ],
    ];
    final bar = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: segments,
      ),
    );
    if (expand) return bar;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: bar);
  }
}

class _Segment<T> extends StatelessWidget {
  final SegmentOption<T> option;
  final bool selected;
  final bool expand;
  final VoidCallback? onTap;
  const _Segment({
    required this.option,
    required this.selected,
    required this.expand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final enabled = option.enabled;
    final fg = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
        : selected
            ? p.onInk
            : scheme.onSurfaceVariant;
    final child = Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: option.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.full),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.emphasized,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          decoration: BoxDecoration(
            color: selected ? p.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                        color: fg,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
    return expand ? Expanded(child: child) : child;
  }
}

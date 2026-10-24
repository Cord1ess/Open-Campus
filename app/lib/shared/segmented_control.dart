import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  const SegmentOption(this.value, this.label, {this.icon, this.enabled = true});
}

/// The one segmented control: a low container with the selected segment lifted
/// to the surface. [expand] fills the available width (2–4 options); when false
/// the control sizes to its content and scrolls horizontally (many options,
/// e.g. a trimester picker). 36-px tall so it never dominates a desktop page.
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
      for (final o in options)
        _Segment<T>(
          option: o,
          selected: o.value == value,
          expand: expand,
          onTap: o.enabled && o.value != value ? () => onChanged(o.value) : null,
        ),
    ];
    final bar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: segments,
      ),
    );
    if (expand) return bar;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: bar,
    );
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
    final enabled = option.enabled;
    final fg = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
        : selected
            ? scheme.onSurface
            : scheme.onSurfaceVariant;
    final child = Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: option.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.emphasized,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? scheme.outlineVariant : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: 16, color: fg),
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

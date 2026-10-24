import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/motion.dart';
import 'app_icons.dart';

/// A heading for a group of content: bold title at left, optional trailing
/// widget (count, badge, "See all" action) at right.
class SectionHeading extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;
  const SectionHeading({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: Spacing.md),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.md),
            DefaultTextStyle.merge(
              style: context.text.labelMedium
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Heading + content. The default way to group things on a page.
class Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const Section({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeading(title: title, trailing: trailing),
        child,
      ],
    );
  }
}

/// A rounded white card on the canvas. With [hue] it becomes a pastel colour
/// container (the Expressive focal block).
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Hue? hue;
  final VoidCallback? onTap;
  final bool selected;
  final double radius;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg + 4),
    this.color,
    this.hue,
    this.onTap,
    this.selected = false,
    this.radius = Radii.lg,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final bg = color ?? (hue != null ? p.container(hue!) : scheme.surface);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: selected
          ? BorderSide(color: p.ink, width: 2)
          : BorderSide.none,
    );
    Widget content = Padding(padding: padding, child: child);
    if (hue != null) {
      content = DefaultTextStyle.merge(
        style: TextStyle(color: p.onContainer),
        child: IconTheme.merge(
            data: IconThemeData(color: p.onContainer), child: content),
      );
    }
    final card = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    return onTap == null ? card : PressScale(child: card);
  }
}

/// A white rounded card holding rows separated by inset hairlines, with an
/// optional heading above it.
class RowGroup extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final double dividerIndent;
  const RowGroup({
    super.key,
    this.title,
    this.trailing,
    required this.children,
    this.dividerIndent = Spacing.lg + 4,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) SectionHeading(title: title!, trailing: trailing),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.lg)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        indent: dividerIndent,
                        endIndent: dividerIndent),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A rounded-square pastel tile holding an icon (list leading, feature tiles).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Hue hue;
  final double size;
  final bool muted;
  const IconTile(this.icon,
      {super.key, this.hue = Hue.peach, this.size = 44, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = context.scheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? scheme.surfaceContainerHigh : p.container(hue),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon,
          size: size * 0.5,
          color: muted ? scheme.onSurfaceVariant : p.onContainer),
    );
  }
}

/// A standard list row: optional leading icon (plain, or in a pastel tile when
/// [hue] is set), title, subtitle, and a trailing value / widget / chevron.
class ListRow extends StatelessWidget {
  final IconData? icon;
  final Hue? hue;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool external;
  final bool chevron;
  final bool muted;
  final bool dense;
  final Color? titleColor;
  final int subtitleLines;

  const ListRow({
    super.key,
    this.icon,
    this.hue,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.external = false,
    this.chevron = true,
    this.muted = false,
    this.dense = false,
    this.titleColor,
    this.subtitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg =
        muted ? scheme.onSurfaceVariant : (titleColor ?? scheme.onSurface);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: dense ? 48 : 60),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: Spacing.lg + 4, vertical: dense ? Spacing.sm : 10),
        child: LayoutBuilder(builder: (context, c) {
          // A trailing value never takes more than half the row, so the title
          // keeps room and an extreme value truncates instead of overflowing.
          final valueMax = c.hasBoundedWidth
              ? (c.maxWidth * 0.5).clamp(72.0, double.infinity)
              : double.infinity;
          return Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: Spacing.md + 2),
              ] else if (icon != null) ...[
                hue != null
                    ? IconTile(icon!, hue: hue!, muted: muted)
                    : Icon(icon,
                        size: 22,
                        color: muted ? scheme.onSurfaceVariant : scheme.onSurface),
                const SizedBox(width: Spacing.md + 2),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w500, color: fg)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!,
                          maxLines: subtitleLines,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: Spacing.md),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: valueMax),
                  child: Text(value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: context.text.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: tabularFigures)),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: Spacing.md),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: valueMax),
                  child: trailing!,
                ),
              ],
              if (onTap != null && (chevron || external)) ...[
                const SizedBox(width: Spacing.sm),
                Icon(external ? AppIcons.external : AppIcons.chevron,
                    size: external ? 18 : 22, color: scheme.onSurface),
              ],
            ],
          );
        }),
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Label at left, value at right (profile fields, summaries, totals).
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;
  final IconData? icon;
  final VoidCallback? onTap;
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: Text(label,
                style: context.text.bodyMedium?.copyWith(
                    color: emphasize ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: emphasize ? FontWeight.w600 : null)),
          ),
          const SizedBox(width: Spacing.lg),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: (emphasize
                        ? context.text.titleMedium
                        : context.text.bodyMedium)
                    ?.copyWith(
                  color: valueColor ?? scheme.onSurface,
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: tabularFigures,
                )),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A 44-px circular icon button on a white disc (back, settings, refresh).
class CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final Widget? child;
  const CircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: color ?? scheme.surface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: child ??
                    Icon(icon, size: 22, color: scheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

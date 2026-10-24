import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_icons.dart';

/// A heading for a group of content: title at left, optional trailing widget
/// (count, badge, small action) at right.
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
                style: context.text.titleMedium),
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

/// Heading + content. The default way to group things on a page; no border.
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

/// A bordered container. Use only when a block needs separation from the page
/// (key figures, a form, a selectable list). Not for every section.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool selected;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.color,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final decoration = BoxDecoration(
      color: color ?? scheme.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(
          color: selected ? p.accentInk : scheme.outlineVariant,
          width: selected ? 1.5 : 1),
    );
    if (onTap == null) {
      return DecoratedBox(
          decoration: decoration, child: Padding(padding: padding, child: child));
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: DecoratedBox(
          decoration: decoration,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A bordered list of rows separated by hairlines, with an optional heading.
/// Rows are usually [ListRow]s but any widget works.
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
    this.dividerIndent = Spacing.lg,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) SectionHeading(title: title!, trailing: trailing),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: dividerIndent, endIndent: 0),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A standard list row: optional leading icon, title, subtitle, and a trailing
/// value / widget / chevron. 52-px minimum height for touch; stays the same
/// height on desktop, where the hover state does the work.
class ListRow extends StatelessWidget {
  final IconData? icon;
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
    final fg = muted ? scheme.onSurfaceVariant : (titleColor ?? scheme.onSurface);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: dense ? 44 : 52),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: dense ? Spacing.sm : Spacing.md),
        child: LayoutBuilder(builder: (context, c) {
          // A trailing value never takes more than half the row, so the title
          // always keeps room and an extreme value truncates instead of
          // overflowing.
          final valueMax = c.hasBoundedWidth
              ? (c.maxWidth * 0.5).clamp(72.0, double.infinity)
              : double.infinity;
          return Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: Spacing.md),
            ] else if (icon != null) ...[
              Icon(icon, size: 22, color: scheme.onSurfaceVariant),
              const SizedBox(width: Spacing.md),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500, color: fg)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!,
                        maxLines: subtitleLines,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall),
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
                  size: external ? 18 : 20, color: scheme.onSurfaceVariant),
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

/// Label at left, value at right. For key/value information (profile fields,
/// summaries, totals).
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
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: Text(label,
                style: context.text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: emphasize ? FontWeight.w600 : null)),
          ),
          const SizedBox(width: Spacing.lg),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: (emphasize ? context.text.titleSmall : context.text.bodyMedium)
                    ?.copyWith(
                  color: valueColor ?? scheme.onSurface,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
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

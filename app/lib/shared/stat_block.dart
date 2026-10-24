import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'responsive.dart';

/// A labelled figure. Inside a [StatStrip] it renders as a pastel tile; on its
/// own (or in a borderless strip) it is a plain label-over-value block.
class StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final Color? valueColor;
  final bool large;
  final CrossAxisAlignment align;
  final VoidCallback? onTap;

  /// Tile colour when shown in a tiled [StatStrip]. Defaults to the strip's
  /// rotation, or to the semantic hue implied by [valueColor].
  final Hue? hue;

  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.valueColor,
    this.large = false,
    this.align = CrossAxisAlignment.start,
    this.onTap,
    this.hue,
  });

  Widget _content(BuildContext context, {required bool onTile}) {
    final scheme = context.scheme;
    final p = context.palette;
    final labelColor =
        onTile ? p.onContainer.withValues(alpha: 0.72) : scheme.onSurfaceVariant;
    final vColor = onTile ? p.onContainer : (valueColor ?? scheme.onSurface);
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(color: labelColor)),
        const SizedBox(height: Spacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: (large
                      ? context.text.headlineMedium
                      : context.text.headlineSmall)
                  ?.copyWith(color: vColor, fontFeatures: tabularFigures)),
        ),
        if (note != null) ...[
          const SizedBox(height: Spacing.xxs),
          Text(note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: labelColor)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final col = _content(context, onTile: false);
    if (onTap == null) return col;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: onTap,
      child: col,
    );
  }
}

/// A row of figures. Tiled (default): each figure is a pastel colour tile, like
/// the Expressive stat cards. [bordered] false: plain figures in a row, for use
/// inside a card. Wraps to two per row on phones with more than three items.
class StatStrip extends StatelessWidget {
  final List<StatBlock> items;
  final bool bordered;
  final List<Hue> hues;
  const StatStrip({
    super.key,
    required this.items,
    this.bordered = true,
    this.hues = const [Hue.mint, Hue.sky, Hue.peach, Hue.lavender],
  });

  Hue _hueFor(BuildContext context, StatBlock b, int i) {
    if (b.hue != null) return b.hue!;
    final p = context.palette;
    final v = b.valueColor;
    if (v != null) {
      if (v == p.dangerInk) return Hue.rose;
      if (v == p.successInk) return Hue.mint;
      if (v == p.warningInk) return Hue.lemon;
      if (v == p.accentInk) return Hue.peach;
      if (v == p.infoInk) return Hue.sky;
    }
    return hues[i % hues.length];
  }

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final twoCol = compact && items.length > 3;
    final p = context.palette;

    Widget cell(StatBlock b, int i) {
      if (!bordered) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: b,
        );
      }
      final tile = Container(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.md + 2, Spacing.md, Spacing.md + 2),
        decoration: BoxDecoration(
          color: p.container(_hueFor(context, b, i)),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: b._content(context, onTile: true),
      );
      if (b.onTap == null) return tile;
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: b.onTap, child: tile),
      );
    }

    const gap = Spacing.sm + 2;
    Widget row(List<int> idx) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < idx.length; k++) ...[
                if (k > 0) const SizedBox(width: gap),
                Expanded(child: cell(items[idx[k]], idx[k])),
              ],
            ],
          ),
        );

    if (twoCol) {
      final rows = <Widget>[];
      for (var i = 0; i < items.length; i += 2) {
        if (i > 0) rows.add(const SizedBox(height: gap));
        rows.add(row([i, if (i + 1 < items.length) i + 1]));
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows);
    }
    return row([for (var i = 0; i < items.length; i++) i]);
  }
}

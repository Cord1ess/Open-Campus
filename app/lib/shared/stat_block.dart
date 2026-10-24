import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'responsive.dart';

/// A labelled figure: small label above a tabular value, optional note below.
class StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final Color? valueColor;
  final bool large;
  final CrossAxisAlignment align;
  final VoidCallback? onTap;
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.valueColor,
    this.large = false,
    this.align = CrossAxisAlignment.start,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final col = Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: (large ? context.text.headlineMedium : context.text.titleLarge)
                  ?.copyWith(
                color: valueColor ?? scheme.onSurface,
                fontFeatures: tabularFigures,
              )),
        ),
        if (note != null) ...[
          const SizedBox(height: Spacing.xxs),
          Text(note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall),
        ],
      ],
    );
    if (onTap == null) return col;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: onTap,
      child: col,
    );
  }
}

/// A row of [StatBlock]s separated by hairlines inside one bordered panel. On
/// narrow screens with more than three items it wraps to two columns.
class StatStrip extends StatelessWidget {
  final List<StatBlock> items;
  final bool bordered;
  const StatStrip({super.key, required this.items, this.bordered = true});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final compact = Breakpoints.isCompact(context);
    final twoCol = compact && items.length > 3;

    Widget cell(StatBlock b) => Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.md),
          child: b,
        );

    Widget content;
    if (twoCol) {
      final rows = <Widget>[];
      for (var i = 0; i < items.length; i += 2) {
        if (i > 0) rows.add(const Divider(height: 1));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell(items[i])),
              if (i + 1 < items.length) ...[
                const VerticalDivider(width: 1),
                Expanded(child: cell(items[i + 1])),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        ));
      }
      content = Column(mainAxisSize: MainAxisSize.min, children: rows);
    } else {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1),
              Expanded(child: cell(items[i])),
            ],
          ],
        ),
      );
    }
    if (!bordered) return content;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: content,
    );
  }
}

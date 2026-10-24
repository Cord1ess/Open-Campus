import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A compact data table: header row, hairline-separated body rows, numeric
/// columns right-aligned with tabular figures. Flexes to the available width;
/// if the columns would get narrower than [minColumnWidth] it scrolls
/// horizontally instead of squashing.
class SimpleTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  /// Per column: true = numeric (right aligned). Defaults to all but the first.
  final List<bool>? numeric;

  /// Emphasise the final row (totals).
  final bool emphasizeLast;
  final double minColumnWidth;

  /// Optional per-row text colour override (e.g. a failed grade).
  final Color? Function(int row)? rowColor;

  const SimpleTable({
    super.key,
    required this.columns,
    required this.rows,
    this.numeric,
    this.emphasizeLast = false,
    this.minColumnWidth = 72,
    this.rowColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final n = columns.length;
    final isNum = numeric ?? [for (var i = 0; i < n; i++) i > 0];

    TableRow headerRow() => TableRow(
          decoration: BoxDecoration(color: scheme.surfaceContainer),
          children: [
            for (var c = 0; c < n; c++)
              _cell(
                context,
                columns[c],
                style: context.text.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                right: isNum[c],
                header: true,
              ),
          ],
        );

    TableRow bodyRow(int r) {
      final last = emphasizeLast && r == rows.length - 1;
      final color = rowColor?.call(r);
      return TableRow(
        decoration: last
            ? BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outline)))
            : null,
        children: [
          for (var c = 0; c < n; c++)
            _cell(
              context,
              c < rows[r].length ? rows[r][c] : '',
              style: context.text.bodyMedium?.copyWith(
                color: color ?? scheme.onSurface,
                fontWeight: last || (isNum[c] && c == n - 1)
                    ? FontWeight.w600
                    : (c == 0 ? FontWeight.w500 : FontWeight.w400),
                fontFeatures: isNum[c] ? tabularFigures : null,
              ),
              right: isNum[c],
            ),
        ],
      );
    }

    Table table(Map<int, TableColumnWidth>? widths) => Table(
          columnWidths: widths,
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(color: scheme.outlineVariant),
          ),
          children: [headerRow(), for (var r = 0; r < rows.length; r++) bodyRow(r)],
        );

    return LayoutBuilder(builder: (context, c) {
      final needed = n * minColumnWidth;
      final decoration = BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      );
      if (c.maxWidth.isFinite && needed <= c.maxWidth) {
        // Flex: first column takes the slack, numeric columns size to content.
        final widths = <int, TableColumnWidth>{
          0: const FlexColumnWidth(),
          for (var i = 1; i < n; i++) i: const IntrinsicColumnWidth(),
        };
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: decoration,
          child: table(widths),
        );
      }
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: decoration,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: needed),
            child: table(null),
          ),
        ),
      );
    });
  }

  Widget _cell(BuildContext context, String text,
      {TextStyle? style, bool right = false, bool header = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: header ? 10 : 12),
      child: Text(text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'status_badge.dart';

/// One data series for [TrendChart].
class ChartSeries {
  final String name;
  final Color color;
  final List<double?> values; // aligned to the shared x labels; null = gap
  const ChartSeries(
      {required this.name, required this.color, required this.values});
}

/// Multi-series line chart (GPA vs CGPA, …) with a toggleable legend and a
/// touch tooltip. Flat lines, no area fill. Y-range is padded around the data
/// so differences stay visible.
class TrendChart extends StatefulWidget {
  final List<String> labels;
  final List<ChartSeries> series;
  final double height;
  final double? minY;
  final double? maxY;

  const TrendChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 200,
    this.minY,
    this.maxY,
  });

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  late List<bool> _on;

  @override
  void initState() {
    super.initState();
    _on = List<bool>.filled(widget.series.length, true);
  }

  @override
  void didUpdateWidget(TrendChart old) {
    super.didUpdateWidget(old);
    if (old.series.length != widget.series.length) {
      _on = List<bool>.filled(widget.series.length, true);
    }
  }

  (double, double) _range() {
    if (widget.minY != null && widget.maxY != null) {
      return (widget.minY!, widget.maxY!);
    }
    final vals = <double>[
      for (var i = 0; i < widget.series.length; i++)
        if (_on[i])
          for (final v in widget.series[i].values)
            if (v != null) v,
    ];
    if (vals.isEmpty) return (0, 4);
    var lo = vals.reduce((a, b) => a < b ? a : b);
    var hi = vals.reduce((a, b) => a > b ? a : b);
    if (lo == hi) {
      lo -= 0.5;
      hi += 0.5;
    }
    final pad = (hi - lo) * 0.18;
    return ((lo - pad).clamp(0, double.infinity), hi + pad);
  }

  int _activeCount() => _on.where((e) => e).length;
  List<int> _activeIndices() => [
        for (var i = 0; i < _on.length; i++)
          if (_on[i]) i
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final (minY, maxY) = _range();
    final interval = ((maxY - minY) / 3).clamp(0.01, double.infinity);

    final bars = <LineChartBarData>[];
    for (var i = 0; i < widget.series.length; i++) {
      if (!_on[i]) continue;
      final s = widget.series[i];
      bars.add(LineChartBarData(
        spots: [
          for (var x = 0; x < s.values.length; x++)
            if (s.values[x] != null) FlSpot(x.toDouble(), s.values[x]!),
        ],
        isCurved: false,
        color: s.color,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (sp, _, __, ___) => FlDotCirclePainter(
              radius: 3,
              color: s.color,
              strokeColor: scheme.surface,
              strokeWidth: 1.5),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }

    final summary = <String>[];
    for (var i = 0; i < widget.series.length; i++) {
      if (!_on[i]) continue;
      final s = widget.series[i];
      final latest = s.values.reversed.firstWhere((v) => v != null,
          orElse: () => null);
      if (latest != null) {
        summary.add('${s.name} latest ${latest.toStringAsFixed(2)}');
      }
    }

    final labelStyle =
        context.text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          child: Semantics(
            label: summary.isEmpty
                ? 'Trend chart'
                : 'Trend chart. ${summary.join('. ')}.',
            child: SizedBox(
              height: widget.height,
              child: LineChart(
                duration: Duration.zero,
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: interval,
                        getTitlesWidget: (v, meta) {
                          if (v < minY || v > maxY) return const SizedBox();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(v.toStringAsFixed(2), style: labelStyle),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= widget.labels.length || v != i) {
                            return const SizedBox();
                          }
                          // Short "Fa 24" style labels so they never overlap.
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(_short(widget.labels[i]),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: labelStyle),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchSpotThreshold: 24,
                    getTouchedSpotIndicator: (bar, indexes) => indexes
                        .map((i) => TouchedSpotIndicatorData(
                              FlLine(
                                  color: scheme.outline, strokeWidth: 1),
                              FlDotData(
                                getDotPainter: (sp, _, __, ___) =>
                                    FlDotCirclePainter(
                                  radius: 4,
                                  color: bar.color ?? scheme.primary,
                                  strokeColor: scheme.surface,
                                  strokeWidth: 2,
                                ),
                              ),
                            ))
                        .toList(),
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      tooltipRoundedRadius: Radii.sm,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.sm),
                      getTooltipItems: (spots) {
                        final active = _activeIndices();
                        return [
                          for (var k = 0; k < spots.length; k++)
                            _tooltipItem(spots[k], k, active, scheme),
                        ];
                      },
                    ),
                  ),
                  lineBarsData: bars,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.lg,
          runSpacing: Spacing.xs,
          children: [
            for (var i = 0; i < widget.series.length; i++)
              _LegendItem(
                name: widget.series[i].name,
                color: widget.series[i].color,
                on: _on[i],
                onTap: () => setState(() {
                  if (_on[i] && _activeCount() == 1) return;
                  _on[i] = !_on[i];
                }),
              ),
          ],
        ),
      ],
    );
  }

  /// "Fall 2024" → "Fall\n2024"; short enough for one slot per term.
  static String _short(String label) {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final year = parts.last;
      final season = parts.sublist(0, parts.length - 1).join(' ');
      final yy = year.length == 4 ? "'${year.substring(2)}" : year;
      return '$season $yy';
    }
    return label;
  }

  LineTooltipItem _tooltipItem(
      LineBarSpot sp, int order, List<int> activeIdx, ColorScheme scheme) {
    final seriesIdx = (sp.barIndex >= 0 && sp.barIndex < activeIdx.length)
        ? activeIdx[sp.barIndex]
        : sp.barIndex;
    final series = (seriesIdx >= 0 && seriesIdx < widget.series.length)
        ? widget.series[seriesIdx]
        : null;
    final name = series?.name ?? '';
    final label =
        sp.x.toInt() < widget.labels.length ? widget.labels[sp.x.toInt()] : '';
    final on = scheme.onInverseSurface;
    return LineTooltipItem(
      '',
      const TextStyle(),
      children: [
        if (order == 0)
          TextSpan(
            text: '$label\n',
            style: context.text.labelSmall
                ?.copyWith(color: on.withValues(alpha: 0.75)),
          ),
        TextSpan(
          text: '$name  ',
          style: context.text.labelMedium
              ?.copyWith(color: on.withValues(alpha: 0.85)),
        ),
        TextSpan(
          text: sp.y.toStringAsFixed(2),
          style: context.text.labelMedium?.copyWith(
              color: on,
              fontWeight: FontWeight.w600,
              fontFeatures: tabularFigures),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String name;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  const _LegendItem({
    required this.name,
    required this.color,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Semantics(
      button: true,
      toggled: on,
      label: '$name series',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.xs),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xs, vertical: Spacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(on ? color : scheme.outline, size: 10),
              const SizedBox(width: 6),
              Text(name,
                  style: context.text.labelMedium?.copyWith(
                      color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                      decoration: on ? null : TextDecoration.lineThrough)),
            ],
          ),
        ),
      ),
    );
  }
}

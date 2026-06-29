import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// One data series for [TrendChart].
class ChartSeries {
  final String name;
  final Color color;
  final List<double?> values; // aligned to the shared x labels; null = gap
  const ChartSeries(
      {required this.name, required this.color, required this.values});
}

/// Multi-series line chart for trends (GPA vs CGPA, etc.) with a toggleable
/// legend and touch tooltip. Y-range is auto-padded around the data rather than
/// a forced 0–4 axis, which flattened everything.
class TrendChart extends StatefulWidget {
  final List<String> labels; // x-axis labels (e.g. "Fall 2024")
  final List<ChartSeries> series;
  final double height;

  /// Optional hard min/max for Y. If null, computed tightly from the data.
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

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final (minY, maxY) = _range();
    final interval = ((maxY - minY) / 3).clamp(0.01, double.infinity);

    final bars = <LineChartBarData>[];
    for (var i = 0; i < widget.series.length; i++) {
      if (!_on[i]) continue;
      final s = widget.series[i];
      final spots = <FlSpot>[
        for (var x = 0; x < s.values.length; x++)
          if (s.values[x] != null) FlSpot(x.toDouble(), s.values[x]!),
      ];
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.28,
        color: s.color,
        barWidth: 3,
        dotData: FlDotData(
          show: true,
          getDotPainter: (sp, _, __, ___) => FlDotCirclePainter(
              radius: 3.5,
              color: s.color,
              strokeColor: scheme.surface,
              strokeWidth: 2),
        ),
        belowBarData: BarAreaData(
          // Only fill under the line when a single series is shown — with two,
          // overlapping fills muddy the chart.
          show: _activeCount() == 1,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              s.color.withValues(alpha: 0.20),
              s.color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: LineChart(
            // Animate the line drawing in (and re-animate when toggling series)
            // so the chart feels lively rather than static.
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
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
                // No left Y-axis labels — the exact tick numbers (which could
                // read like impossible >4.0 values due to padding) added noise.
                // Values are shown precisely in the hover tooltip instead.
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= widget.labels.length || v != i) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Transform.rotate(
                          angle: -0.5,
                          child: Text(widget.labels[i],
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                // Easier to land on a point and less twitchy: a generous touch
                // radius means the tooltip doesn't flicker as you move slightly,
                // and it doesn't require pixel-perfect hovering.
                touchSpotThreshold: 24,
                getTouchedSpotIndicator: (bar, indexes) => indexes
                    .map((i) => TouchedSpotIndicatorData(
                          FlLine(
                              color: bar.color ?? scheme.primary,
                              strokeWidth: 2),
                          FlDotData(
                            getDotPainter: (sp, _, __, ___) =>
                                FlDotCirclePainter(
                              radius: 5,
                              color: bar.color ?? scheme.primary,
                              strokeColor: scheme.surface,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ))
                    .toList(),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  tooltipRoundedRadius: 12,
                  tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  // Show the term once as a heading, then each visible series'
                  // value, color-tinted so GPA vs CGPA is unmistakable.
                  getTooltipItems: (spots) {
                    final activeIdx = _activeIndices();
                    return [
                      for (var k = 0; k < spots.length; k++)
                        _tooltipItem(spots[k], k, activeIdx, scheme),
                    ];
                  },
                ),
              ),
              lineBarsData: bars,
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.sm,
          children: [
            for (var i = 0; i < widget.series.length; i++)
              _LegendChip(
                name: widget.series[i].name,
                color: widget.series[i].color,
                on: _on[i],
                onTap: () => setState(() {
                  // Keep at least one series on.
                  if (_on[i] && _activeCount() == 1) return;
                  _on[i] = !_on[i];
                }),
              ),
          ],
        ),
      ],
    );
  }

  int _activeCount() => _on.where((e) => e).length;
  List<int> _activeIndices() => [
        for (var i = 0; i < _on.length; i++)
          if (_on[i]) i
      ];

  /// Builds one tooltip line. The first spot also carries the term label as a
  /// small heading above it. Each series value is tinted with that series'
  /// color so GPA vs CGPA is unmistakable at a glance.
  LineTooltipItem _tooltipItem(
      LineBarSpot sp, int order, List<int> activeIdx, ColorScheme scheme) {
    // sp.barIndex maps into the list of *drawn* (active) bars, which aligns
    // with activeIdx.
    final seriesIdx = (sp.barIndex >= 0 && sp.barIndex < activeIdx.length)
        ? activeIdx[sp.barIndex]
        : sp.barIndex;
    final series = (seriesIdx >= 0 && seriesIdx < widget.series.length)
        ? widget.series[seriesIdx]
        : null;
    final name = series?.name ?? '';
    final color = series?.color ?? scheme.onInverseSurface;
    final label = sp.x.toInt() < widget.labels.length
        ? widget.labels[sp.x.toInt()]
        : '';

    return LineTooltipItem(
      '',
      const TextStyle(),
      children: [
        // Term heading on the first line only.
        if (order == 0)
          TextSpan(
            text: '$label\n',
            style: TextStyle(
              color: scheme.onInverseSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        TextSpan(
          text: '● ',
          style: TextStyle(color: color, fontSize: 12),
        ),
        TextSpan(
          text: '$name  ',
          style: TextStyle(
            color: scheme.onInverseSurface.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        TextSpan(
          text: sp.y.toStringAsFixed(2),
          style: TextStyle(
            color: scheme.onInverseSurface,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String name;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  const _LegendChip({
    required this.name,
    required this.color,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: on ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on
                ? color.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: on ? color.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(name,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                      decoration: on ? null : TextDecoration.lineThrough)),
            ],
          ),
        ),
      ),
    );
  }
}

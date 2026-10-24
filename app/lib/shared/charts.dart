import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/motion.dart';
import 'status_badge.dart';

/// One data series for [TrendChart].
class ChartSeries {
  final String name;
  final Color color;
  final List<double?> values; // aligned to the shared x labels; null = gap
  const ChartSeries(
      {required this.name, required this.color, required this.values});
}

enum ChartMode { line, bars }

/// Small pill toggle used in chart control rows.
class _ChartChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;
  const _ChartChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = context.scheme;
    final fg = selected ? p.onInk : scheme.onSurfaceVariant;
    final chip = Semantics(
      button: true,
      selected: selected,
      label: tooltip ?? label,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 32,
          padding: EdgeInsets.symmetric(
              horizontal: label.isEmpty ? Spacing.sm : Spacing.md),
          decoration: BoxDecoration(
            color: selected ? p.ink : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 16, color: fg),
              if (icon != null && label.isNotEmpty) const SizedBox(width: 4),
              if (label.isNotEmpty)
                Text(label,
                    style: context.text.labelMedium?.copyWith(
                        color: fg,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Multi-series trend chart with controls: Line/Bars, time range, value
/// labels, average line, and a toggleable legend. Smooth curves with a soft
/// area fill, an animated draw-in, and a touch crosshair with a tooltip.
class TrendChart extends StatefulWidget {
  final List<String> labels;
  final List<ChartSeries> series;
  final double height;
  final double? minY;
  final double? maxY;
  final ChartMode initialMode;
  final String Function(double v) format;

  /// Horizontal reference lines (value, label), e.g. a target or threshold.
  final List<(double, String)> references;

  /// Show the Line/Bars switch.
  final bool allowModeSwitch;

  const TrendChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 230,
    this.minY,
    this.maxY,
    this.initialMode = ChartMode.line,
    this.format = _twoDp,
    this.references = const [],
    this.allowModeSwitch = true,
  });

  static String _twoDp(double v) => v.toStringAsFixed(2);

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  late List<bool> _on = List<bool>.filled(widget.series.length, true);
  late ChartMode _mode = widget.initialMode;
  int _range = 0; // 0 = all, otherwise last N
  bool _values = false;
  bool _average = false;

  @override
  void didUpdateWidget(TrendChart old) {
    super.didUpdateWidget(old);
    if (old.series.length != widget.series.length) {
      _on = List<bool>.filled(widget.series.length, true);
    }
  }

  int get _start {
    final n = widget.labels.length;
    return _range == 0 ? 0 : math.max(0, n - _range);
  }

  List<String> get _labels => widget.labels.sublist(_start);
  List<double?> _vals(ChartSeries s) =>
      s.values.sublist(math.min(_start, s.values.length));

  (double, double) _yRange() {
    if (widget.minY != null && widget.maxY != null) {
      return (widget.minY!, widget.maxY!);
    }
    final vals = <double>[
      for (var i = 0; i < widget.series.length; i++)
        if (_on[i])
          for (final v in _vals(widget.series[i]))
            if (v != null) v,
      for (final r in widget.references) r.$1,
    ];
    if (vals.isEmpty) return (0, 1);
    var lo = vals.reduce(math.min);
    var hi = vals.reduce(math.max);
    if (_mode == ChartMode.bars) lo = math.min(0, lo);
    if (lo == hi) {
      lo -= 0.5;
      hi += 0.5;
    }
    final pad = (hi - lo) * 0.18;
    return (
      _mode == ChartMode.bars ? lo : math.max(0, lo - pad),
      hi + pad * (_values ? 1.8 : 1),
    );
  }

  double? get _avg {
    final first = [for (var i = 0; i < _on.length; i++) if (_on[i]) i];
    if (first.isEmpty) return null;
    final v = _vals(widget.series[first.first]).whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  static String _short(String label) {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && RegExp(r'^\d{4}$').hasMatch(parts.last)) {
      final season = parts.sublist(0, parts.length - 1).join(' ');
      final s = season.length > 3 ? season.substring(0, 3) : season;
      return "$s '${parts.last.substring(2)}";
    }
    return label.length > 10 ? '${label.substring(0, 9)}…' : label;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final (minY, maxY) = _yRange();
    final interval = ((maxY - minY) / 4).clamp(0.0001, double.infinity);
    final labels = _labels;
    final n = labels.length;
    final labelStyle =
        context.text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final animate = !reduceMotion(context);
    final dur = animate ? const Duration(milliseconds: 650) : Duration.zero;

    final avg = _average ? _avg : null;
    final extra = ExtraLinesData(horizontalLines: [
      for (final r in widget.references)
        HorizontalLine(
          y: r.$1,
          color: p.dangerInk.withValues(alpha: 0.7),
          strokeWidth: 1.5,
          dashArray: [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: labelStyle?.copyWith(color: p.dangerInk),
            labelResolver: (_) => r.$2,
          ),
        ),
      if (avg != null)
        HorizontalLine(
          y: avg,
          color: p.ink.withValues(alpha: 0.55),
          strokeWidth: 1.5,
          dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            style: labelStyle?.copyWith(color: scheme.onSurface),
            labelResolver: (_) => 'avg ${widget.format(avg)}',
          ),
        ),
    ]);

    final titles = FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: interval,
          getTitlesWidget: (v, meta) {
            if (v <= minY + interval * 0.2 || v >= maxY - interval * 0.2) {
              return const SizedBox();
            }
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 6,
              child: Text(widget.format(v), style: labelStyle),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(),
      topTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= n || v != i) return const SizedBox();
            // Thin the labels when crowded.
            final step = (n / 7).ceil();
            if (n > 8 && i % step != 0 && i != n - 1) return const SizedBox();
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8,
              child: Text(_short(labels[i]), style: labelStyle),
            );
          },
        ),
      ),
    );
    final grid = FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: scheme.outlineVariant, strokeWidth: 1, dashArray: [3, 4]),
    );

    final active = [for (var i = 0; i < _on.length; i++) if (_on[i]) i];

    Widget chart;
    if (_mode == ChartMode.line) {
      final bars = <LineChartBarData>[
        for (final i in active)
          LineChartBarData(
            spots: [
              for (var x = 0; x < n; x++)
                if (x < _vals(widget.series[i]).length &&
                    _vals(widget.series[i])[x] != null)
                  FlSpot(x.toDouble(), _vals(widget.series[i])[x]!),
            ],
            isCurved: true,
            curveSmoothness: 0.32,
            preventCurveOverShooting: true,
            color: widget.series[i].color,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (sp, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: scheme.surface,
                strokeColor: widget.series[i].color,
                strokeWidth: 2.5,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.series[i].color
                      .withValues(alpha: active.length == 1 ? 0.28 : 0.16),
                  widget.series[i].color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
      ];
      final indicators = <ShowingTooltipIndicators>[
        if (_values)
          for (var b = 0; b < bars.length; b++)
            for (final sp in bars[b].spots)
              ShowingTooltipIndicators([LineBarSpot(bars[b], b, sp)]),
      ];
      chart = LineChart(
        duration: dur,
        curve: Curves.easeOutCubic,
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: -0.3,
          maxX: n - 0.7,
          gridData: grid,
          titlesData: titles,
          borderData: FlBorderData(show: false),
          extraLinesData: extra,
          showingTooltipIndicators: indicators,
          lineTouchData: _values
              ? LineTouchData(
                  enabled: false,
                  handleBuiltInTouches: false,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 6,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          widget.format(s.y),
                          labelStyle!.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                )
              : LineTouchData(
                  touchSpotThreshold: 28,
                  getTouchedSpotIndicator: (bar, idx) => [
                    for (final _ in idx)
                      TouchedSpotIndicatorData(
                        FlLine(
                            color: scheme.outline,
                            strokeWidth: 1.5,
                            dashArray: [4, 3]),
                        FlDotData(
                          getDotPainter: (sp, _, __, ___) => FlDotCirclePainter(
                            radius: 6,
                            color: bar.color ?? p.accent,
                            strokeColor: scheme.surface,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                  ],
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => p.ink,
                    tooltipRoundedRadius: Radii.sm,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.sm),
                    getTooltipItems: (spots) => [
                      for (var k = 0; k < spots.length; k++)
                        _tooltip(context, spots[k], k, active),
                    ],
                  ),
                ),
          lineBarsData: bars,
        ),
      );
    } else {
      final groupW = 280 / math.max(n, 1);
      final rodW = (groupW / (active.length + 0.8)).clamp(6.0, 22.0);
      chart = BarChart(
        duration: dur,
        curve: Curves.easeOutCubic,
        BarChartData(
          minY: minY,
          maxY: maxY,
          gridData: grid,
          titlesData: titles,
          borderData: FlBorderData(show: false),
          extraLinesData: extra,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: !_values,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _values ? Colors.transparent : p.ink,
              tooltipRoundedRadius: Radii.sm,
              tooltipPadding: _values
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm),
              tooltipMargin: 4,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (g, gi, rod, ri) {
                final s = widget.series[active[ri]];
                return BarTooltipItem(
                  _values
                      ? widget.format(rod.toY)
                      : '${labels[g.x]}\n${s.name}  ${widget.format(rod.toY)}',
                  (labelStyle ?? const TextStyle()).copyWith(
                      color: _values ? scheme.onSurface : p.onInk,
                      fontWeight: FontWeight.w700),
                );
              },
            ),
          ),
          barGroups: [
            for (var x = 0; x < n; x++)
              BarChartGroupData(
                x: x,
                barsSpace: 4,
                showingTooltipIndicators: _values
                    ? [for (var r = 0; r < active.length; r++) r]
                    : const [],
                barRods: [
                  for (final i in active)
                    BarChartRodData(
                      toY: (x < _vals(widget.series[i]).length
                              ? _vals(widget.series[i])[x]
                              : null) ??
                          0,
                      fromY: minY,
                      width: rodW,
                      color: widget.series[i].color,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(rodW / 2)),
                    ),
                ],
              ),
          ],
        ),
      );
    }

    final summary = active.isEmpty
        ? null
        : '${widget.series[active.first].name}: latest '
            '${widget.format(_vals(widget.series[active.first]).lastWhere((v) => v != null, orElse: () => 0) ?? 0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Controls.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (widget.allowModeSwitch) ...[
                _ChartChip(
                  label: '',
                  icon: Icons.show_chart,
                  tooltip: 'Line chart',
                  selected: _mode == ChartMode.line,
                  onTap: () => setState(() => _mode = ChartMode.line),
                ),
                const SizedBox(width: 4),
                _ChartChip(
                  label: '',
                  icon: Icons.bar_chart,
                  tooltip: 'Bar chart',
                  selected: _mode == ChartMode.bars,
                  onTap: () => setState(() => _mode = ChartMode.bars),
                ),
                const SizedBox(width: Spacing.md),
              ],
              if (widget.labels.length > 4) ...[
                for (final r in [0, 6, 3])
                  if (r == 0 || widget.labels.length > r) ...[
                    _ChartChip(
                      label: r == 0 ? 'All' : 'Last $r',
                      selected: _range == r,
                      onTap: () => setState(() => _range = r),
                    ),
                    const SizedBox(width: 4),
                  ],
                const SizedBox(width: Spacing.sm),
              ],
              _ChartChip(
                label: 'Values',
                icon: Icons.pin_outlined,
                selected: _values,
                onTap: () => setState(() => _values = !_values),
              ),
              const SizedBox(width: 4),
              _ChartChip(
                label: 'Average',
                icon: Icons.horizontal_rule,
                selected: _average,
                onTap: () => setState(() => _average = !_average),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        RepaintBoundary(
          child: Semantics(
            label: summary ?? 'Chart',
            child: SizedBox(
              height: widget.height,
              child: AnimatedSwitcher(
                duration: animate ? Motion.medium : Duration.zero,
                child: KeyedSubtree(key: ValueKey(_mode), child: chart),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            for (var i = 0; i < widget.series.length; i++)
              _LegendChip(
                name: widget.series[i].name,
                color: widget.series[i].color,
                on: _on[i],
                onTap: () => setState(() {
                  if (_on[i] && _on.where((e) => e).length == 1) return;
                  _on[i] = !_on[i];
                }),
              ),
          ],
        ),
      ],
    );
  }

  LineTooltipItem _tooltip(
      BuildContext context, LineBarSpot sp, int order, List<int> active) {
    final p = context.palette;
    final si = sp.barIndex < active.length ? active[sp.barIndex] : 0;
    final s = widget.series[si];
    final i = sp.x.toInt();
    final label = i >= 0 && i < _labels.length ? _labels[i] : '';
    final base = context.text.labelMedium ?? const TextStyle();
    return LineTooltipItem(
      '',
      base,
      children: [
        if (order == 0)
          TextSpan(
              text: '$label\n',
              style: base.copyWith(color: p.onInk.withValues(alpha: 0.7))),
        TextSpan(
            text: '● ',
            style: base.copyWith(color: s.color)),
        TextSpan(
            text: '${s.name}  ',
            style: base.copyWith(color: p.onInk.withValues(alpha: 0.85))),
        TextSpan(
            text: widget.format(sp.y),
            style: base.copyWith(
                color: p.onInk,
                fontWeight: FontWeight.w700,
                fontFeatures: tabularFigures)),
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
    return Semantics(
      button: true,
      toggled: on,
      label: '$name series',
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.full),
            border: Border.all(
                color: on ? Colors.transparent : scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(on ? color : scheme.outline, size: 9),
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

/// One bar in a [BarsChart].
class BarItem {
  final String label;
  final String? detail;
  final double value;
  final Color color;
  const BarItem(
      {required this.label,
      required this.value,
      required this.color,
      this.detail});
}

/// A categorical bar chart (e.g. attendance % per course) with a threshold
/// line, sorting control, value labels, and touch tooltips.
class BarsChart extends StatefulWidget {
  final List<BarItem> items;
  final double maxY;
  final (double, String)? threshold;
  final String Function(double v) format;
  final double height;
  const BarsChart({
    super.key,
    required this.items,
    required this.maxY,
    this.threshold,
    this.format = _pct,
    this.height = 220,
  });

  static String _pct(double v) => '${v.toStringAsFixed(0)}%';

  @override
  State<BarsChart> createState() => _BarsChartState();
}

class _BarsChartState extends State<BarsChart> {
  bool _sorted = false;
  bool _values = true;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final items = [...widget.items];
    if (_sorted) items.sort((a, b) => a.value.compareTo(b.value));
    final n = items.length;
    final labelStyle =
        context.text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final rodW = (240 / math.max(n, 1)).clamp(10.0, 30.0);
    final animate = !reduceMotion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _ChartChip(
              label: 'Course order',
              selected: !_sorted,
              onTap: () => setState(() => _sorted = false),
            ),
            const SizedBox(width: 4),
            _ChartChip(
              label: 'Lowest first',
              selected: _sorted,
              onTap: () => setState(() => _sorted = true),
            ),
            const Spacer(),
            _ChartChip(
              label: '',
              icon: Icons.pin_outlined,
              tooltip: 'Show values',
              selected: _values,
              onTap: () => setState(() => _values = !_values),
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        SizedBox(
          height: widget.height,
          child: BarChart(
            duration: animate ? const Duration(milliseconds: 650) : Duration.zero,
            curve: Curves.easeOutCubic,
            BarChartData(
              maxY: widget.maxY * (_values ? 1.12 : 1),
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: widget.maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: scheme.outlineVariant,
                    strokeWidth: 1,
                    dashArray: [3, 4]),
              ),
              extraLinesData: widget.threshold == null
                  ? null
                  : ExtraLinesData(horizontalLines: [
                      HorizontalLine(
                        y: widget.threshold!.$1,
                        color: p.dangerInk.withValues(alpha: 0.75),
                        strokeWidth: 1.5,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: labelStyle?.copyWith(color: p.dangerInk),
                          labelResolver: (_) => widget.threshold!.$2,
                        ),
                      ),
                    ]),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: widget.maxY / 4,
                    getTitlesWidget: (v, meta) => v > widget.maxY
                        ? const SizedBox()
                        : SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(widget.format(v), style: labelStyle),
                          ),
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= n) return const SizedBox();
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(items[i].label, style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: !_values,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => _values ? Colors.transparent : p.ink,
                  tooltipRoundedRadius: Radii.sm,
                  tooltipPadding: _values
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.sm),
                  tooltipMargin: 4,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (g, gi, rod, ri) {
                    final it = items[g.x];
                    return BarTooltipItem(
                      _values
                          ? widget.format(rod.toY)
                          : '${it.detail ?? it.label}\n${widget.format(rod.toY)}',
                      (labelStyle ?? const TextStyle()).copyWith(
                          color: _values ? scheme.onSurface : p.onInk,
                          fontWeight: FontWeight.w700),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var x = 0; x < n; x++)
                  BarChartGroupData(
                    x: x,
                    showingTooltipIndicators: _values ? const [0] : const [],
                    barRods: [
                      BarChartRodData(
                        toY: items[x].value,
                        width: rodW,
                        color: items[x].color,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(rodW / 2)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: widget.maxY,
                          color: scheme.surfaceContainer,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

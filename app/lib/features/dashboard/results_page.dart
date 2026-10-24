import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import 'dashboard_controller.dart';
import 'models.dart';
import 'resource_view.dart';

/// Results: headline figures, the GPA/CGPA trend, and a per-semester table.
class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(resultsProvider);
    void reload() => ref.read(resultsProvider.notifier).load(force: true);
    return PageScaffold(
      title: 'Results',
      onRefresh: () => ref.read(resultsProvider.notifier).load(force: true),
      body: ResourceBody<ResultsData>(
        state: results,
        loadingLabel: 'Loading your results…',
        errorTitle: 'Couldn’t load results',
        onRetry: reload,
        builder: (d) => _ResultsBody(d),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  final ResultsData data;
  const _ResultsBody(this.data);

  @override
  Widget build(BuildContext context) {
    if (data.semesters.isEmpty) {
      return const EmptyState(
          icon: AppIcons.results, title: 'No results published yet');
    }
    final p = context.palette;
    final sems = data.semesters; // newest first
    final cgpa = data.latestCgpa ?? sems.first.cgpa;
    final gpas = sems.map((s) => s.gpa).toList();
    final best = gpas.reduce((a, b) => a > b ? a : b);
    final worst = gpas.reduce((a, b) => a < b ? a : b);
    final avg = gpas.reduce((a, b) => a + b) / gpas.length;
    final delta = sems.length >= 2 ? sems[0].gpa - sems[1].gpa : null;
    final deltaText = delta == null
        ? '—'
        : '${delta >= 0 ? '+' : '−'}${delta.abs().toStringAsFixed(2)}';

    final ordered = sems.reversed.toList(); // oldest → newest for the chart
    String two(double v) => v.toStringAsFixed(2);

    final sections = <Widget>[
      _CgpaHero(
        cgpa: cgpa,
        term: '${sems.first.semester} ${sems.first.year}',
        deltaText: deltaText,
        delta: delta,
      ),
      StatStrip(items: [
        StatBlock(
            label: 'Best GPA',
            value: two(best),
            numeric: best,
            format: two,
            hue: Hue.mint),
        StatBlock(
            label: 'Average GPA',
            value: two(avg),
            numeric: avg,
            format: two,
            hue: Hue.sky),
        StatBlock(
            label: 'Lowest GPA',
            value: two(worst),
            numeric: worst,
            format: two,
            hue: Hue.peach),
        StatBlock(
            label: 'Terms',
            value: '${sems.length}',
            numeric: sems.length.toDouble(),
            format: (v) => v.toStringAsFixed(0),
            hue: Hue.lavender),
      ]),
      if (ordered.length >= 2)
        Section(
          title: 'Trend',
          child: Panel(
            child: TrendChart(
              labels: [for (final s in ordered) '${s.semester} ${s.year}'],
              series: [
                ChartSeries(
                  name: 'CGPA',
                  color: p.accent,
                  values: [for (final s in ordered) s.cgpa],
                ),
                ChartSeries(
                  name: 'GPA',
                  color: p.infoInk,
                  values: [for (final s in ordered) s.gpa],
                ),
              ],
            ),
          ),
        ),
      Section(
        title: 'By semester',
        child: SimpleTable(
          columns: const ['Term', 'GPA', 'CGPA'],
          rows: [
            for (final s in sems)
              ['${s.semester} ${s.year}', two(s.gpa), two(s.cgpa)],
          ],
        ),
      ),
    ];

    return Stacked(
      children: [
        for (var i = 0; i < sections.length; i++)
          Reveal(index: i, child: sections[i]),
      ],
    );
  }
}

/// Focal block: the (hidden-by-default) CGPA, the latest term and the change
/// in GPA since the term before, with a slowly turning Expressive shape.
class _CgpaHero extends StatelessWidget {
  final double cgpa;
  final String term;
  final String deltaText;
  final double? delta;
  const _CgpaHero({
    required this.cgpa,
    required this.term,
    required this.deltaText,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final up = (delta ?? 0) >= 0;
    return Panel(
      hue: Hue.lavender,
      radius: Radii.xl,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -16,
            child: ExcludeSemantics(
              child: IdleSpin(
                period: const Duration(seconds: 30),
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: ShapeDecoration(
                    color: p.accent.withValues(alpha: 0.9),
                    shape:
                        const ExpressiveShapeBorder(ExpressiveShapeKind.cookie),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xl, Spacing.xl, 120, Spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current CGPA',
                    style: context.text.labelLarge?.copyWith(
                        color: p.onContainer.withValues(alpha: 0.75))),
                const SizedBox(height: Spacing.xs),
                SecretText(
                  id: Secrets.cgpa,
                  value: cgpa.toStringAsFixed(2),
                  iconSize: 24,
                  style: context.text.displaySmall?.copyWith(
                      color: p.onContainer, fontFeatures: tabularFigures),
                ),
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: [
                    StatusBadge('Latest · $term', onColored: true),
                    if (delta != null)
                      StatusBadge(
                        '$deltaText GPA',
                        onColored: true,
                        icon: up ? AppIcons.trendUp : AppIcons.trendDown,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

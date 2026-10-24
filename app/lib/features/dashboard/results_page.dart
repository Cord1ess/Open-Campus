import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/trend_chart.dart';
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
    final deltaColor =
        delta == null ? null : (delta >= 0 ? p.successInk : p.dangerInk);

    final ordered = sems.reversed.toList(); // oldest → newest for the chart

    return Stacked(
      children: [
        StatStrip(items: [
          StatBlock(label: 'CGPA', value: cgpa.toStringAsFixed(2), large: true),
          StatBlock(
              label: 'Terms',
              value: '${sems.length}',
              note: '${sems.first.semester} ${sems.first.year}'),
          StatBlock(
              label: 'Last term',
              value: deltaText,
              valueColor: deltaColor,
              note: 'GPA change'),
        ]),
        StatStrip(items: [
          StatBlock(label: 'Best GPA', value: best.toStringAsFixed(2)),
          StatBlock(label: 'Average GPA', value: avg.toStringAsFixed(2)),
          StatBlock(label: 'Lowest GPA', value: worst.toStringAsFixed(2)),
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
                    color: p.accentInk,
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
                [
                  '${s.semester} ${s.year}',
                  s.gpa.toStringAsFixed(2),
                  s.cgpa.toStringAsFixed(2),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

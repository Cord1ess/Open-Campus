import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'models.dart';
import 'resource_view.dart';

/// Full Results page — richer than the dashboard card: a stats strip (best/worst
/// GPA, trend, total terms), the GPA/CGPA trend chart, then the per-semester
/// breakdown. Everything is theme-coloured.
class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(resultsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(resultsProvider.notifier).load(force: true),
        child: CustomScrollView(
          slivers: [
            const SliverCollapsingAppBar(title: 'Results'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (results) {
                  ResLoading() =>
                    const SectionCard(title: 'Results', icon: Icons.timeline, child: CardSkeleton(label: 'Loading your results…')),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn’t load results',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.read(resultsProvider.notifier).load(force: true),
                    ),
                  ResData(:final loaded) => _ResultsBody(loaded.data),
                },
                const SizedBox(height: 96),
              ]),
            ),
          ],
        ),
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
      return const SectionCard(
        title: 'Results',
        icon: Icons.timeline,
        child: StateMessage(icon: Icons.school_outlined, title: 'No results yet'),
      );
    }
    final sems = data.semesters; // newest-first per the model
    final cgpa = data.latestCgpa ?? sems.first.cgpa;
    final gpas = sems.map((s) => s.gpa).toList();
    final best = gpas.reduce((a, b) => a > b ? a : b);
    final worst = gpas.reduce((a, b) => a < b ? a : b);
    final avgGpa = gpas.reduce((a, b) => a + b) / gpas.length;
    // Trend: latest term GPA vs the one before it.
    final delta = sems.length >= 2 ? sems[0].gpa - sems[1].gpa : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(child: _OverviewCard(cgpa: cgpa, terms: sems.length, delta: delta)),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          delayMs: 60,
          child: SectionCard(
            title: 'GPA insights',
            icon: Icons.insights_outlined,
            child: Row(
              children: [
                Expanded(child: _Stat('Best GPA', best.toStringAsFixed(2), context.scheme.secondary)),
                Expanded(child: _Stat('Average', avgGpa.toStringAsFixed(2), context.scheme.primary)),
                Expanded(child: _Stat('Lowest GPA', worst.toStringAsFixed(2), context.scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        // The chart + per-semester breakdown (shared with the dashboard card).
        FadeSlideIn(
          delayMs: 120,
          child: SectionCard(
            title: 'Trend & breakdown',
            icon: Icons.timeline,
            child: ResultsContent(data, showHeader: false),
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final double cgpa;
  final int terms;
  final double? delta;
  const _OverviewCard({required this.cgpa, required this.terms, this.delta});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final up = (delta ?? 0) >= 0;
    return SectionCard(
      title: 'Overview',
      icon: Icons.school_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current CGPA',
                  style: context.text.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              CountUp(cgpa,
                  style: context.text.displaySmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text('$terms term${terms == 1 ? '' : 's'}',
                    style: context.text.labelMedium?.copyWith(
                        color: scheme.onSurface, fontWeight: FontWeight.w700)),
              ),
              if (delta != null) ...[
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(up ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: up ? scheme.secondary : scheme.error),
                    const SizedBox(width: 4),
                    Text(
                        '${up ? '+' : ''}${delta!.toStringAsFixed(2)} last term',
                        style: context.text.labelSmall?.copyWith(
                            color: up ? scheme.secondary : scheme.error,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.text.labelSmall
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: context.text.titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

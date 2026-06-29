import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/trend_chart.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import '../common/collapsing_title.dart';
import 'course_history_model.dart';

/// Full academic record: degree progress, CGPA, and every course grouped by
/// trimester with grade chips. Data from /student/course-history.
class CourseHistoryPage extends ConsumerWidget {
  const CourseHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(courseHistoryProvider.notifier).ensureLoaded();
    final state = ref.watch(courseHistoryProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(courseHistoryProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            SliverCollapsingAppBar(title: 'Course History'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (state) {
                  ResLoading() => const CardSkeleton(lines: 6),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn\'t load',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.read(courseHistoryProvider.notifier).load(),
                    ),
                  ResData(:final loaded) => _Content(loaded.data),
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

class _Content extends StatelessWidget {
  final CourseHistoryData d;
  const _Content(this.d);

  @override
  Widget build(BuildContext context) {
    final groups = d.byTrimester;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(child: _ProgressHero(d)),
        if (d.trimesterGpas.length >= 2) ...[
          const SizedBox(height: Spacing.lg),
          FadeSlideIn(delayMs: 40, child: _CgpaTrendCard(d.trimesterGpas)),
        ],
        const SizedBox(height: Spacing.lg),
        for (final (i, entry) in groups.entries.indexed) ...[
          if (i > 0) const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 60 + i * 40,
            child: _TrimesterCard(
              trimester: entry.key,
              courses: entry.value,
              gpa: d.trimesterGpas
                  .where((g) => g.trimester == entry.key)
                  .map((g) => g.gpa)
                  .firstOrNull,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressHero extends StatelessWidget {
  final CourseHistoryData d;
  const _ProgressHero(this.d);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (d.program != null)
                Text(d.program!,
                    style: context.text.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800)),
              const Spacer(),
              if (d.batch != null)
                Text(d.batch!,
                    style: context.text.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer
                            .withValues(alpha: 0.8))),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              _Ring(progress: d.progress, color: scheme.onPrimaryContainer),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stat(context, 'CGPA', d.cgpa?.toStringAsFixed(2) ?? '—'),
                    const SizedBox(height: Spacing.sm),
                    _stat(
                        context,
                        'Credits',
                        '${d.completedCredits?.toStringAsFixed(0) ?? '—'} / '
                            '${d.degreeRequirement?.toStringAsFixed(0) ?? '—'}'),
                    if (d.attemptedCredits != null) ...[
                      const SizedBox(height: Spacing.sm),
                      _stat(context, 'Attempted',
                          d.attemptedCredits!.toStringAsFixed(0)),
                    ],
                    if (d.waivedCredits != null && d.waivedCredits! > 0) ...[
                      const SizedBox(height: Spacing.sm),
                      _stat(context, 'Waived',
                          d.waivedCredits!.toStringAsFixed(0)),
                    ],
                    if (d.probation != null) ...[
                      const SizedBox(height: Spacing.sm),
                      _stat(context, 'Status', d.probation!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final scheme = context.scheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: context.text.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8))),
        ),
        Expanded(
          child: Text(value,
              style: context.text.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  final double progress;
  final Color color;
  const _Ring({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: Motion.slow,
            curve: Motion.emphasized,
            builder: (_, v, __) => SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 7,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Text('${(progress * 100).toStringAsFixed(0)}%',
              style: context.text.labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// GPA + CGPA progression across trimesters (from the transcript GPA table).
class _CgpaTrendCard extends StatelessWidget {
  final List<TrimesterGpa> gpas;
  const _CgpaTrendCard(this.gpas);

  @override
  Widget build(BuildContext context) {
    final pts = gpas.where((g) => g.cgpa != null || g.gpa != null).toList();
    if (pts.length < 2) return const SizedBox.shrink();
    return SectionCard(
      title: 'GPA & CGPA trend',
      icon: Icons.trending_up,
      child: TrendChart(
        labels: [for (final g in pts) g.trimester ?? ''],
        series: [
          ChartSeries(
            name: 'CGPA',
            color: context.scheme.primary,
            values: [for (final g in pts) g.cgpa],
          ),
          ChartSeries(
            name: 'GPA',
            color: context.status.good,
            values: [for (final g in pts) g.gpa],
          ),
        ],
      ),
    );
  }
}

class _TrimesterCard extends StatelessWidget {
  final String trimester;
  final List<HistoryCourse> courses;
  final double? gpa;
  const _TrimesterCard({
    required this.trimester,
    required this.courses,
    this.gpa,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final credits =
        courses.fold<double>(0, (s, c) => s + (c.credit ?? 0));
    return SectionCard(
      title: 'Trimester $trimester',
      icon: Icons.calendar_today_outlined,
      trailing: Row(
        children: [
          if (gpa != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('GPA ${gpa!.toStringAsFixed(2)}',
                  style: context.text.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < courses.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _CourseRow(courses[i]),
          ],
          const SizedBox(height: Spacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${credits.toStringAsFixed(0)} credits',
                style: context.text.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final HistoryCourse c;
  const _CourseRow(this.c);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.courseCode ?? '—',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (c.courseName != null)
                Text(c.courseName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        _GradeChip(grade: c.grade, isRunning: c.isRunning),
      ],
    );
  }
}

class _GradeChip extends StatelessWidget {
  final String? grade;
  final bool isRunning;
  const _GradeChip({required this.grade, required this.isRunning});

  // Color by grade band.
  (Color, Color) _tones(BuildContext context) {
    final scheme = context.scheme;
    if (isRunning) {
      return (scheme.tertiaryContainer, scheme.onTertiaryContainer);
    }
    final g = grade ?? '';
    if (g.startsWith('A')) return (context.status.goodContainer, context.status.good);
    if (g.startsWith('B')) {
      return (scheme.secondaryContainer, scheme.onSecondaryContainer);
    }
    if (g.startsWith('C') || g.startsWith('D')) {
      return (context.status.warnContainer, context.status.warn);
    }
    if (g.startsWith('F')) return (context.status.badContainer, context.status.bad);
    return (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tones(context);
    final label = isRunning ? 'Running' : (grade ?? '—');
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: context.text.labelMedium
              ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

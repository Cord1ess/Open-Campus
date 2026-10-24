import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/course_names.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'course_history_model.dart';

/// Course Grades: degree standing + every course grouped by trimester (newest
/// first) with grade badges. Data from /student/course-history.
class CourseHistoryPage extends ConsumerStatefulWidget {
  const CourseHistoryPage({super.key});

  @override
  ConsumerState<CourseHistoryPage> createState() => _CourseHistoryPageState();
}

class _CourseHistoryPageState extends ConsumerState<CourseHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(courseHistoryProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseHistoryProvider);
    return PageScaffold(
      title: 'Course Grades',
      onRefresh: () =>
          ref.read(courseHistoryProvider.notifier).load(force: true),
      body: ResourceBody<CourseHistoryData>(
        state: state,
        loadingLabel: 'Loading your course history…',
        errorTitle: 'Couldn’t load course grades',
        onRetry: () => ref.read(courseHistoryProvider.notifier).load(),
        builder: (d) => _Content(d),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final CourseHistoryData d;
  const _Content(this.d);

  @override
  Widget build(BuildContext context) {
    // Newest trimester first, by the numeric term code (e.g. 261 > 253) so the
    // order doesn't depend on how UCAM happened to list the courses.
    int code(String t) {
      final m = RegExp(r'\d+').firstMatch(t);
      return m != null ? (int.tryParse(m.group(0)!) ?? -1) : -1;
    }

    final groups = d.byTrimester.entries.toList()
      ..sort((x, y) => code(y.key).compareTo(code(x.key)));
    final gpaByTrimester = {
      for (final g in d.trimesterGpas) g.trimester: g.gpa,
    };
    if (groups.isEmpty && d.cgpa == null) {
      return const EmptyState(
          icon: AppIcons.grades, title: 'No course history yet');
    }
    // Term GPA / CGPA trend, oldest first.
    final terms = [
      for (final g in d.trimesterGpas)
        if (g.trimester != null && (g.gpa != null || g.cgpa != null)) g,
    ]..sort((x, y) => code(x.trimester!).compareTo(code(y.trimester!)));
    final p = context.palette;

    return Stacked(
      children: [
        Reveal(index: 0, child: _StandingFigures(d)),
        Reveal(index: 1, child: _StandingPanel(d)),
        if (terms.length >= 2)
          Reveal(
            index: 2,
            child: Section(
              title: 'GPA by term',
              child: Panel(
                child: TrendChart(
                  labels: [for (final t in terms) t.trimester!],
                  series: [
                    ChartSeries(
                      name: 'GPA',
                      color: p.infoInk,
                      values: [for (final t in terms) t.gpa],
                    ),
                    ChartSeries(
                      name: 'CGPA',
                      color: p.accent,
                      values: [for (final t in terms) t.cgpa],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ResponsiveGrid(
          maxColumns: 2,
          stretch: false,
          spacing: Spacing.xl,
          runSpacing: Spacing.xl,
          children: [
            for (final (i, entry) in groups.indexed)
              Reveal(
                index: i + 3,
                child: _TrimesterGroup(
                  trimester: entry.key,
                  courses: entry.value,
                  gpa: gpaByTrimester[entry.key],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

const _kMaxTrimesters = 12;

double? _remaining(CourseHistoryData d) =>
    (d.degreeRequirement != null && d.completedCredits != null)
        ? (d.degreeRequirement! - d.completedCredits!)
            .clamp(0, d.degreeRequirement!)
            .toDouble()
        : null;

/// Pace to graduate within 12 trimesters: remaining credits ÷ remaining
/// trimesters (trimesters used = rows in the transcript GPA table).
int _remainingTrimesters(CourseHistoryData d) =>
    (_kMaxTrimesters - d.trimesterGpas.length).clamp(1, _kMaxTrimesters);

double _avgPerTrimester(CourseHistoryData d) {
  final r = _remaining(d);
  return (r != null && r > 0) ? r / _remainingTrimesters(d) : 0.0;
}

/// The focal pastel figures: CGPA (hidden by default), credits done/left and
/// the pace needed to finish on time.
class _StandingFigures extends StatelessWidget {
  final CourseHistoryData d;
  const _StandingFigures(this.d);

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining(d);
    final avg = _avgPerTrimester(d);
    return StatStrip(items: [
      StatBlock(
        label: 'CGPA',
        value: d.cgpa?.toStringAsFixed(2) ?? '—',
        secretId: d.cgpa != null ? Secrets.cgpa : null,
        hue: Hue.mint,
      ),
      StatBlock(
        label: 'Completed',
        value: d.completedCredits != null
            ? '${d.completedCredits!.toStringAsFixed(0)} cr'
            : '—',
        numeric: d.completedCredits,
        format: (v) => '${v.toStringAsFixed(0)} cr',
        hue: Hue.sky,
      ),
      StatBlock(
        label: 'Remaining',
        value: remaining != null ? '${remaining.toStringAsFixed(0)} cr' : '—',
        numeric: remaining,
        format: (v) => '${v.toStringAsFixed(0)} cr',
        hue: Hue.peach,
      ),
      StatBlock(
        label: 'Credits / term',
        note: 'to finish on time',
        value: avg > 0 ? avg.toStringAsFixed(1) : '—',
        numeric: avg > 0 ? avg : null,
        format: (v) => v.toStringAsFixed(1),
        hue: Hue.lavender,
      ),
    ]);
  }
}

/// Program, degree progress ring, and the credit details.
class _StandingPanel extends StatelessWidget {
  final CourseHistoryData d;
  const _StandingPanel(this.d);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final remainingTrimesters = _remainingTrimesters(d);
    final avgPerTrimester = _avgPerTrimester(d);
    const kMaxTrimesters = _kMaxTrimesters;

    final hasHeader =
        d.program != null || d.batch != null || d.probation != null;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (d.program != null)
                        Text(d.program!, style: context.text.titleMedium),
                      if (d.batch != null)
                        Text(d.batch!, style: context.text.bodySmall),
                    ],
                  ),
                ),
                if (d.probation != null) ...[
                  const SizedBox(width: Spacing.md),
                  StatusBadge(d.probation!,
                      tone: StatusTone.warning, icon: AppIcons.warning),
                ],
              ],
            ),
            const SizedBox(height: Spacing.lg),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                      begin: 0, end: d.progress.clamp(0.0, 1.0).toDouble()),
                  duration: reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 7,
                          color: p.accent,
                          backgroundColor: scheme.surfaceContainerHighest,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text('${(v * 100).toStringAsFixed(0)}%',
                          style: context.text.titleSmall
                              ?.copyWith(fontFeatures: tabularFigures)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Degree progress', style: context.text.titleMedium),
                    Text(
                        '${d.completedCredits?.toStringAsFixed(0) ?? '—'} of '
                        '${d.degreeRequirement?.toStringAsFixed(0) ?? '—'} '
                        'credits completed',
                        style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          const Divider(),
          KeyValueRow(
              label: 'Degree requirement',
              value: '${d.degreeRequirement?.toStringAsFixed(0) ?? '—'} cr'),
          if (d.attemptedCredits != null)
            KeyValueRow(
                label: 'Attempted',
                value: '${d.attemptedCredits!.toStringAsFixed(0)} cr'),
          if (d.waivedCredits != null && d.waivedCredits! > 0)
            KeyValueRow(
                label: 'Waived',
                value: '${d.waivedCredits!.toStringAsFixed(0)} cr'),
          if (avgPerTrimester > 0) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              'Average ${avgPerTrimester.toStringAsFixed(1)} credits per '
              'trimester over your next $remainingTrimesters to graduate within '
              '$kMaxTrimesters trimesters.',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrimesterGroup extends StatelessWidget {
  final String trimester;
  final List<HistoryCourse> courses;
  final double? gpa;
  const _TrimesterGroup({
    required this.trimester,
    required this.courses,
    this.gpa,
  });

  @override
  Widget build(BuildContext context) {
    final credits = courses.fold<double>(0, (s, c) => s + (c.credit ?? 0));
    final running = courses.any((c) => c.isRunning);
    final badge = gpa != null
        ? StatusBadge('GPA ${gpa!.toStringAsFixed(2)}')
        : (running ? const StatusBadge('In progress') : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RowGroup(
          title: 'Trimester $trimester',
          trailing: badge,
          children: [for (final c in courses) _CourseRow(c)],
        ),
        Padding(
          padding: const EdgeInsets.only(top: Spacing.sm, left: Spacing.xs),
          child: Text(
            '${courses.length} course${courses.length == 1 ? '' : 's'} · '
            '${credits.toStringAsFixed(0)} credits',
            style: context.text.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _CourseRow extends StatelessWidget {
  final HistoryCourse c;
  const _CourseRow(this.c);

  @override
  Widget build(BuildContext context) {
    final cr = c.credit != null
        ? '${c.credit!.toStringAsFixed(c.credit! % 1 == 0 ? 0 : 1)} cr'
        : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg + 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: CourseName(
                code: c.courseCode ?? '—',
                title: c.courseName,
                extra: cr,
                titleStyle: context.text.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: Spacing.md),
            if (!c.isRunning && c.point != null) ...[
              Text(c.point!.toStringAsFixed(2),
                  style: context.text.labelMedium?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                      fontFeatures: tabularFigures)),
              const SizedBox(width: Spacing.sm),
            ],
            _gradeBadge(c),
          ],
        ),
      ),
    );
  }

  static StatusBadge _gradeBadge(HistoryCourse c) {
    if (c.isRunning) return const StatusBadge('Running');
    final g = c.grade ?? '—';
    final tone = switch (g.isEmpty ? '' : g[0]) {
      'A' => StatusTone.success,
      'B' => StatusTone.info,
      'C' || 'D' => StatusTone.warning,
      'F' => StatusTone.danger,
      _ => StatusTone.neutral,
    };
    return StatusBadge(g, tone: tone);
  }
}

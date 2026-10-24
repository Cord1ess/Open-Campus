import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
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
      onRefresh: () => ref.read(courseHistoryProvider.notifier).load(force: true),
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
    return Stacked(
      children: [
        _StandingPanel(d),
        ResponsiveGrid(
          maxColumns: 2,
          stretch: false,
          spacing: Spacing.xl,
          runSpacing: Spacing.xl,
          children: [
            for (final entry in groups)
              _TrimesterGroup(
                trimester: entry.key,
                courses: entry.value,
                gpa: gpaByTrimester[entry.key],
              ),
          ],
        ),
      ],
    );
  }
}

/// Program, degree progress ring, and the headline figures.
class _StandingPanel extends StatelessWidget {
  final CourseHistoryData d;
  const _StandingPanel(this.d);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final remaining = (d.degreeRequirement != null && d.completedCredits != null)
        ? (d.degreeRequirement! - d.completedCredits!)
            .clamp(0, d.degreeRequirement!)
            .toDouble()
        : null;

    // Pace to graduate within 12 trimesters: remaining credits ÷ remaining
    // trimesters (trimesters used = rows in the transcript GPA table).
    const kMaxTrimesters = 12;
    final trimestersUsed = d.trimesterGpas.length;
    final remainingTrimesters =
        (kMaxTrimesters - trimestersUsed).clamp(1, kMaxTrimesters);
    final avgPerTrimester = (remaining != null && remaining > 0)
        ? remaining / remainingTrimesters
        : 0.0;

    final hasHeader = d.program != null || d.batch != null || d.probation != null;

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
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: d.progress.clamp(0.0, 1.0).toDouble(),
                      strokeWidth: 6,
                      color: p.accentInk,
                      backgroundColor: scheme.surfaceContainerHighest,
                      strokeCap: StrokeCap.round,
                    ),
                    Text('${(d.progress * 100).toStringAsFixed(0)}%',
                        style: context.text.labelLarge
                            ?.copyWith(fontFeatures: tabularFigures)),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: StatStrip(
                  bordered: false,
                  items: [
                    StatBlock(
                        label: 'CGPA', value: d.cgpa?.toStringAsFixed(2) ?? '—'),
                    StatBlock(
                        label: 'Completed',
                        value: d.completedCredits != null
                            ? '${d.completedCredits!.toStringAsFixed(0)} cr'
                            : '—'),
                    StatBlock(
                        label: 'Remaining',
                        value: remaining != null
                            ? '${remaining.toStringAsFixed(0)} cr'
                            : '—'),
                    StatBlock(
                        label: 'Credits / term',
                        note: 'to finish on time',
                        value: avgPerTrimester > 0
                            ? avgPerTrimester.toStringAsFixed(1)
                            : '—'),
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
    return ListRow(
      title: c.courseCode ?? '—',
      subtitle: c.courseName,
      value: cr,
      chevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

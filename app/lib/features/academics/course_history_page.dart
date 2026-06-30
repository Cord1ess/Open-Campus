import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import '../common/collapsing_title.dart';
import 'course_history_model.dart';

/// Course Grades: degree standing + every course grouped by trimester (newest
/// first) with grade chips. Data from /student/course-history.
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(courseHistoryProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            const SliverCollapsingAppBar(title: 'Course Grades'),
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
    // Newest trimester first (byTrimester is in first-seen / oldest order).
    final groups = d.byTrimester.entries.toList().reversed.toList();
    // Pre-index GPA by trimester once (was an O(n²) scan-per-group below).
    final gpaByTrimester = {
      for (final g in d.trimesterGpas) g.trimester: g.gpa,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(child: _ProgressHero(d)),
        const SizedBox(height: Spacing.lg),
        for (final (i, entry) in groups.indexed) ...[
          if (i > 0) const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 60 + i * 40,
            child: _TrimesterCard(
              trimester: entry.key,
              courses: entry.value,
              gpa: gpaByTrimester[entry.key],
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
    // The 2nd brand accent (blue on the default theme) drives this hero.
    final accent = scheme.secondary;
    final onAcc = scheme.onSecondary;
    final remaining = (d.degreeRequirement != null && d.completedCredits != null)
        ? (d.degreeRequirement! - d.completedCredits!).clamp(0, d.degreeRequirement!)
        : null;

    // Pace to graduate within 12 trimesters: trimesters used = how many appear in
    // the transcript GPA table; remaining trimesters = 12 − that (min 1). The
    // average credits/trimester needed = remaining credits ÷ remaining trimesters.
    const kMaxTrimesters = 12;
    final trimestersUsed = d.trimesterGpas.length;
    final remainingTrimesters =
        (kMaxTrimesters - trimestersUsed).clamp(1, kMaxTrimesters);
    final avgPerTrimester =
        (remaining != null && remaining > 0) ? remaining / remainingTrimesters : 0.0;

    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Program + batch.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.program != null)
                      Text(d.program!,
                          style: context.text.titleLarge?.copyWith(
                              color: onAcc, fontWeight: FontWeight.w800)),
                    if (d.batch != null) ...[
                      const SizedBox(height: 2),
                      Text(d.batch!,
                          style: context.text.bodySmall?.copyWith(
                              color: onAcc.withValues(alpha: 0.85))),
                    ],
                  ],
                ),
              ),
              if (d.probation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: onAcc.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(d.probation!,
                      style: context.text.labelSmall?.copyWith(
                          color: onAcc, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          // Ring + the two headline figures.
          Row(
            children: [
              _Ring(progress: d.progress, color: onAcc),
              const SizedBox(width: Spacing.xl),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _big(context, 'CGPA',
                          d.cgpa?.toStringAsFixed(2) ?? '—', onAcc),
                    ),
                    Expanded(
                      child: _big(
                          context,
                          'Cr / term to finish',
                          avgPerTrimester > 0
                              ? avgPerTrimester.toStringAsFixed(1)
                              : '—',
                          onAcc),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Divider(color: onAcc.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: Spacing.lg),
          // Secondary stat grid.
          Wrap(
            spacing: Spacing.xl,
            runSpacing: Spacing.md,
            children: [
              if (d.completedCredits != null)
                _chip(context, 'Completed',
                    '${d.completedCredits!.toStringAsFixed(0)} cr', onAcc),
              if (remaining != null)
                _chip(context, 'Remaining',
                    '${remaining.toStringAsFixed(0)} cr', onAcc),
              _chip(context, 'Degree requirement',
                  '${d.degreeRequirement?.toStringAsFixed(0) ?? '—'} cr', onAcc),
              if (d.attemptedCredits != null)
                _chip(context, 'Attempted',
                    '${d.attemptedCredits!.toStringAsFixed(0)} cr', onAcc),
              if (d.waivedCredits != null && d.waivedCredits! > 0)
                _chip(context, 'Waived',
                    '${d.waivedCredits!.toStringAsFixed(0)} cr', onAcc),
            ],
          ),
          if (avgPerTrimester > 0) ...[
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Icon(Icons.flag_outlined,
                    size: 13, color: onAcc.withValues(alpha: 0.85)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      'Average ${avgPerTrimester.toStringAsFixed(1)} credits/trimester '
                      'over your next $remainingTrimesters to graduate within $kMaxTrimesters trimesters.',
                      style: context.text.labelSmall?.copyWith(
                          color: onAcc.withValues(alpha: 0.85), height: 1.35)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _big(BuildContext context, String label, String value, Color onAcc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.text.labelSmall
                ?.copyWith(color: onAcc.withValues(alpha: 0.85))),
        Text(value,
            style: context.text.headlineSmall
                ?.copyWith(color: onAcc, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, String value, Color onAcc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: context.text.labelSmall
                ?.copyWith(color: onAcc.withValues(alpha: 0.8))),
        Text(value,
            style: context.text.titleSmall
                ?.copyWith(color: onAcc, fontWeight: FontWeight.w700)),
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
          RepaintBoundary(
            child: TweenAnimationBuilder<double>(
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
          ),
          Text('${(progress * 100).toStringAsFixed(0)}%',
              style: context.text.labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w800)),
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
    final running = courses.any((c) => c.isRunning);
    return SectionCard(
      title: 'Trimester $trimester',
      icon: Icons.calendar_today_outlined,
      trailing: gpa != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.secondary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('GPA ${gpa!.toStringAsFixed(2)}',
                  style: context.text.labelMedium?.copyWith(
                      color: scheme.onSecondary, fontWeight: FontWeight.w800)),
            )
          : (running
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('In progress',
                      style: context.text.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700)),
                )
              : null),
      child: Column(
        children: [
          for (var i = 0; i < courses.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _CourseRow(courses[i]),
          ],
          const SizedBox(height: Spacing.md),
          // Footer: course count + total credits.
          Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${courses.length} course${courses.length == 1 ? '' : 's'}',
                  style: context.text.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text('${credits.toStringAsFixed(0)} credits',
                  style: context.text.labelMedium?.copyWith(
                      color: scheme.secondary, fontWeight: FontWeight.w700)),
            ],
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
    // Sub-line: just credit hours (grade point now shows as a chip).
    final cr = c.credit != null
        ? '${c.credit!.toStringAsFixed(c.credit! % 1 == 0 ? 0 : 1)} cr'
        : null;

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
              if (cr != null) ...[
                const SizedBox(height: 2),
                Text(cr,
                    style: context.text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        // Grade-point chip (when graded), then the grade chip.
        if (!c.isRunning && c.point != null) ...[
          _PointChip(c.point!),
          const SizedBox(width: 6),
        ],
        _GradeChip(grade: c.grade, isRunning: c.isRunning),
      ],
    );
  }
}

/// A small neutral chip showing the numeric grade point (e.g. "3.67").
class _PointChip extends StatelessWidget {
  final double point;
  const _PointChip(this.point);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(point.toStringAsFixed(2),
          style: context.text.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
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

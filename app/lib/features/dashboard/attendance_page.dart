import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/attendance_rules.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'models.dart';
import 'resource_view.dart';

/// Full Attendance page. The headline isn't a raw % vs a 70% cut-off — at UIU
/// attendance carries MARKS: a few absences are free, then each further absence
/// deducts 0.25 (theory: 3 free, lab: 1 free). So each course shows free
/// absences remaining and marks lost so far. See core/domain/attendance_rules.
class AttendancePage extends ConsumerWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(attendanceProvider.notifier).load(force: true),
        child: CustomScrollView(
          slivers: [
            const SliverCollapsingAppBar(title: 'Attendance'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (attendance) {
                  ResLoading() => const SectionCard(
                      title: 'Attendance',
                      icon: Icons.event_available_outlined,
                      child: CardSkeleton(label: 'Loading your attendance…')),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn’t load attendance',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.read(attendanceProvider.notifier).load(force: true),
                    ),
                  ResData(:final loaded) => _AttendanceBody(loaded.data),
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

class _AttendanceBody extends StatelessWidget {
  final AttendanceData data;
  const _AttendanceBody(this.data);

  @override
  Widget build(BuildContext context) {
    if (data.courses.isEmpty) {
      return const SectionCard(
        title: 'Attendance',
        icon: Icons.event_available_outlined,
        child:
            StateMessage(icon: Icons.event_busy_outlined, title: 'No attendance data'),
      );
    }
    // Courses most-at-risk first: those already losing marks, then those closest
    // to the threshold.
    final courses = [...data.courses];
    AttendanceBudget budgetOf(CourseAttendance c) => attendanceBudget(
        absences: c.absent,
        isLab: isLabCourse(title: c.title, courseCode: c.courseCode));
    courses.sort((a, b) {
      final ba = budgetOf(a), bb = budgetOf(b);
      if (bb.marksLost != ba.marksLost) {
        return bb.marksLost.compareTo(ba.marksLost);
      }
      return ba.freeRemaining.compareTo(bb.freeRemaining);
    });

    final totalLost = courses.fold<double>(
        0, (s, c) => s + budgetOf(c).marksLost);
    final deductingCount = courses.where((c) => budgetOf(c).isDeducting).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: _SummaryCard(
            data: data,
            totalMarksLost: totalLost,
            deductingCount: deductingCount,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        for (var i = 0; i < courses.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : Spacing.lg),
            child: FadeSlideIn(
              delayMs: 40 + i * 30,
              child: _CourseCard(courses[i], budgetOf(courses[i])),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AttendanceData data;
  final double totalMarksLost;
  final int deductingCount;
  const _SummaryCard({
    required this.data,
    required this.totalMarksLost,
    required this.deductingCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final overall = overallAttendancePct(data) ?? 0;
    final present = attendedClasses(data);
    final held = totalClasses(data);
    final absent = held - present;
    final lostColor =
        totalMarksLost > 0 ? scheme.error : scheme.secondary;

    return SectionCard(
      title: 'Overview',
      icon: Icons.event_available_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.secondary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('${overall.toStringAsFixed(0)}% present',
            style: context.text.labelLarge
                ?.copyWith(color: scheme.secondary, fontWeight: FontWeight.w800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Marks-lost headline (the thing that actually matters).
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: lostColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Icon(
                    totalMarksLost > 0
                        ? Icons.trending_down_rounded
                        : Icons.verified_outlined,
                    color: lostColor),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          totalMarksLost > 0
                              ? '−${_fmt(totalMarksLost)} attendance marks lost'
                              : 'No attendance marks lost',
                          style: context.text.titleSmall?.copyWith(
                              color: lostColor, fontWeight: FontWeight.w800)),
                      Text(
                          totalMarksLost > 0
                              ? '$deductingCount course${deductingCount == 1 ? '' : 's'} past the free-absence limit'
                              : 'You’re within the free-absence limit in every course',
                          style: context.text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(child: _stat(context, 'Present', '$present', scheme.secondary)),
              Expanded(child: _stat(context, 'Absent', '$absent',
                  absent > 0 ? scheme.error : scheme.onSurfaceVariant)),
              Expanded(child: _stat(context, 'Held', '$held', scheme.onSurface)),
              Expanded(child: _stat(context, 'Courses', '${data.courses.length}',
                  scheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
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

/// One course: name + present/held, a clear "free absences left" or "marks lost"
/// status, and a thin presence bar coloured by whether deductions have started.
class _CourseCard extends StatelessWidget {
  final CourseAttendance c;
  final AttendanceBudget budget;
  const _CourseCard(this.c, this.budget);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final lab = isLabCourse(title: c.title, courseCode: c.courseCode);
    // Status colour, all from the active theme: error red once losing marks,
    // the primary accent when only 1 free absence is left (caution), otherwise
    // the secondary accent (healthy). No fixed amber/brown.
    final Color status;
    if (budget.isDeducting) {
      status = scheme.error;
    } else if (budget.freeRemaining <= 1) {
      status = scheme.primary;
    } else {
      status = scheme.secondary;
    }
    final presentRatio =
        c.totalHeld == 0 ? 0.0 : (c.present / c.totalHeld).clamp(0.0, 1.0);

    return SectionCard(
      title: c.courseCode.isNotEmpty ? c.courseCode : (c.title),
      icon: lab ? Icons.science_outlined : Icons.menu_book_outlined,
      trailing: lab
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('LAB',
                  style: context.text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.title.isNotEmpty)
            Text('${c.title}${c.section.isNotEmpty ? ' · ${c.section}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.md),
          // Status line.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: status.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Row(
              children: [
                Icon(
                    budget.isDeducting
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: 18,
                    color: status),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    budget.isDeducting
                        ? '−${_fmt(budget.marksLost)} marks · ${budget.penalizedAbsences} absence'
                            '${budget.penalizedAbsences == 1 ? '' : 's'} over the limit'
                        : budget.freeRemaining == 0
                            ? 'At the limit — the next absence costs marks'
                            : '${budget.freeRemaining} free absence'
                                '${budget.freeRemaining == 1 ? '' : 's'} left',
                    style: context.text.bodySmall?.copyWith(
                        color: status, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          // Presence bar.
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: presentRatio),
                duration: Motion.slow,
                curve: Motion.emphasized,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(status),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              _meta(context, '${c.present}/${c.totalHeld} attended'),
              const Spacer(),
              _meta(context, '${c.absent} absent · ${budget.freeAbsences} free'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, String text) => Text(text,
      style: context.text.labelSmall
          ?.copyWith(color: context.scheme.onSurfaceVariant));
}

/// Format a marks number: drop the trailing ".00" but keep ".25"/".50"/".75".
String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

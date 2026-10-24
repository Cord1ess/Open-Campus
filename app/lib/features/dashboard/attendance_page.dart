import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/attendance_rules.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/course_names.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'models.dart';
import 'resource_view.dart';

enum _Filter { all, atRisk, strong }

/// Attendance. At UIU attendance carries MARKS: a few absences are free, then
/// each further absence deducts 0.25 (theory: 3 free, lab: 1 free). Each course
/// therefore shows free absences remaining and marks lost so far.
class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceProvider);
    void reload() => ref.read(attendanceProvider.notifier).load(force: true);
    return PageScaffold(
      title: 'Attendance',
      onRefresh: () => ref.read(attendanceProvider.notifier).load(force: true),
      body: ResourceBody<AttendanceData>(
        state: attendance,
        loadingLabel: 'Loading your attendance…',
        errorTitle: 'Couldn’t load attendance',
        onRetry: reload,
        builder: (d) => _AttendanceBody(
          data: d,
          filter: _filter,
          onFilter: (f) => setState(() => _filter = f),
        ),
      ),
    );
  }
}

AttendanceBudget _budgetOf(CourseAttendance c) => attendanceBudget(
    absences: c.absent,
    isLab: isLabCourse(title: c.title, courseCode: c.courseCode));

Hue _hueFor(StatusTone tone) => switch (tone) {
      StatusTone.danger => Hue.rose,
      StatusTone.warning => Hue.lemon,
      StatusTone.success => Hue.mint,
      _ => Hue.sky,
    };

class _AttendanceBody extends StatelessWidget {
  final AttendanceData data;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  const _AttendanceBody({
    required this.data,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    if (data.courses.isEmpty) {
      return const EmptyState(
          icon: AppIcons.attendance, title: 'No attendance data yet');
    }
    final p = context.palette;

    // Courses most-at-risk first: those already losing marks, then those
    // closest to the threshold.
    final courses = [...data.courses];
    courses.sort((a, b) {
      final ba = _budgetOf(a), bb = _budgetOf(b);
      if (bb.marksLost != ba.marksLost) {
        return bb.marksLost.compareTo(ba.marksLost);
      }
      return ba.freeRemaining.compareTo(bb.freeRemaining);
    });

    final overall = overallAttendancePct(data) ?? 0;
    final present = attendedClasses(data);
    final held = totalClasses(data);
    final totalLost =
        courses.fold<double>(0, (s, c) => s + _budgetOf(c).marksLost);
    final deducting = courses.where((c) => _budgetOf(c).isDeducting).length;

    final atRisk = courses.where((c) => c.pct < 70).toList();
    final strong = courses.where((c) => c.pct >= 85).toList();
    final shown = switch (filter) {
      _Filter.all => courses,
      _Filter.atRisk => atRisk,
      _Filter.strong => strong,
    };

    final chart = Panel(
      child: BarsChart(
        maxY: 100,
        threshold: (70, '70% min'),
        items: [
          for (final c in data.courses)
            BarItem(
              label: c.courseCode.isNotEmpty
                  ? splitCourseLabel(c.courseCode).$1
                  : c.title,
              detail: c.title.isNotEmpty ? c.title : c.courseCode,
              value: c.pct,
              color: p.container(_hueFor(attendanceTone(c.pct, _budgetOf(c)))),
            ),
        ],
      ),
    );

    final list = Section(
      title: 'Courses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormWidth(
            child: SegmentedControl<_Filter>(
              value: filter,
              onChanged: onFilter,
              options: [
                SegmentOption(_Filter.all, 'All ${courses.length}'),
                SegmentOption(_Filter.atRisk, 'At risk ${atRisk.length}'),
                SegmentOption(_Filter.strong, 'Strong ${strong.length}'),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: shown.isEmpty
                  ? const EmptyState(
                      key: ValueKey('empty'),
                      icon: AppIcons.attendance,
                      title: 'No courses in this filter',
                      compact: true)
                  : RowGroup(
                      key: ValueKey(filter),
                      children: [
                        for (final c in shown) _CourseRow(c, _budgetOf(c)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );

    return Stacked(
      children: [
        Reveal(
          index: 0,
          child: StatStrip(items: [
            StatBlock(
              label: 'Present',
              value: '${overall.toStringAsFixed(0)}%',
              numeric: overall,
              format: (v) => '${v.toStringAsFixed(0)}%',
              hue: overall < 70 ? Hue.rose : Hue.mint,
            ),
            StatBlock(
              label: 'Marks lost',
              value: totalLost > 0 ? '−${_fmt(totalLost)}' : '0',
              numeric: totalLost,
              format: (v) => v > 0 ? '−${_fmt(_quarter(v))}' : '0',
              hue: totalLost > 0 ? Hue.rose : Hue.sky,
            ),
            StatBlock(
              label: 'Deducting',
              value: '$deducting',
              numeric: deducting.toDouble(),
              format: (v) => v.toStringAsFixed(0),
              note: 'of ${courses.length} courses',
              hue: Hue.peach,
            ),
            StatBlock(
                label: 'Classes', value: '$present/$held', hue: Hue.lavender),
          ]),
        ),
        Reveal(
          index: 1,
          child: Section(title: 'By course', child: chart),
        ),
        Reveal(index: 2, child: list),
      ],
    );
  }
}

/// One course: title (code and section below), percentage, an animated
/// presence bar coloured by its status, and a plain-language line about free
/// absences / marks lost.
class _CourseRow extends StatelessWidget {
  final CourseAttendance c;
  final AttendanceBudget budget;
  const _CourseRow(this.c, this.budget);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final tone = attendanceTone(c.pct, budget);
    final ink = p.inkFor(tone, scheme);
    final lab = isLabCourse(title: c.title, courseCode: c.courseCode);
    final ratio =
        c.totalHeld == 0 ? 0.0 : (c.present / c.totalHeld).clamp(0.0, 1.0);

    final status = budget.isDeducting
        ? '−${_fmt(budget.marksLost)} marks · ${budget.penalizedAbsences} '
            'absence${budget.penalizedAbsences == 1 ? '' : 's'} over the limit'
        : budget.freeRemaining == 0
            ? 'At the limit — the next absence costs marks'
            : '${budget.freeRemaining} free absence'
                '${budget.freeRemaining == 1 ? '' : 's'} left';

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg + 4, vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CourseName(
                  code: c.courseCode.isNotEmpty ? c.courseCode : c.title,
                  title: c.title.isNotEmpty ? c.title : null,
                  extra: c.section.isNotEmpty ? 'Sec ${c.section}' : null,
                  titleStyle: context.text.titleSmall,
                ),
              ),
              const SizedBox(width: Spacing.md),
              if (lab) ...[
                const StatusBadge('Lab'),
                const SizedBox(width: Spacing.sm),
              ],
              CountUp(
                value: c.pct,
                format: (v) => '${v.toStringAsFixed(0)}%',
                style: context.text.titleMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    fontFeatures: tabularFigures),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: reduceMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: p.fillFor(tone, scheme),
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(status,
              style: context.text.bodySmall
                  ?.copyWith(color: ink, fontWeight: FontWeight.w500)),
          Text(
              '${c.present}/${c.totalHeld} attended · ${c.absent} absent · '
              '${budget.freeAbsences} free',
              style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// Round to the nearest quarter mark (for the count-up animation).
double _quarter(double v) => (v * 4).round() / 4;

/// Drop a trailing ".00" but keep ".25"/".50"/".75".
String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

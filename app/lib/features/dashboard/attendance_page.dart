import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/attendance_rules.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
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

class _AttendanceBody extends StatelessWidget {
  final AttendanceData data;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  const _AttendanceBody({
    required this.data,
    required this.filter,
    required this.onFilter,
  });

  AttendanceBudget _budgetOf(CourseAttendance c) => attendanceBudget(
      absences: c.absent,
      isLab: isLabCourse(title: c.title, courseCode: c.courseCode));

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

    return Stacked(
      children: [
        StatStrip(items: [
          StatBlock(label: 'Present', value: '${overall.toStringAsFixed(0)}%'),
          StatBlock(
            label: 'Marks lost',
            value: totalLost > 0 ? '−${_fmt(totalLost)}' : '0',
            valueColor: totalLost > 0 ? p.dangerInk : p.successInk,
          ),
          StatBlock(
              label: 'Deducting',
              value: '$deducting',
              note: 'of ${courses.length} courses'),
          StatBlock(label: 'Classes', value: '$present/$held'),
        ]),
        Section(
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
              if (shown.isEmpty)
                const EmptyState(
                    icon: AppIcons.attendance,
                    title: 'No courses in this filter',
                    compact: true)
              else
                RowGroup(
                  children: [
                    for (final c in shown) _CourseRow(c, _budgetOf(c)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One course: code + section, title, percentage, a thin presence bar coloured
/// by its status, and a plain-language line about free absences / marks lost.
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

    final code = c.courseCode.isNotEmpty ? c.courseCode : c.title;
    final head = c.section.isNotEmpty ? '$code · ${c.section}' : code;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(head, style: context.text.titleSmall),
                    if (c.title.isNotEmpty && c.courseCode.isNotEmpty)
                      Text(c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),
              if (lab) ...[
                const StatusBadge('Lab'),
                const SizedBox(width: Spacing.sm),
              ],
              Text('${c.pct.toStringAsFixed(0)}%',
                  style: context.text.labelLarge?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabularFigures)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: p.fillFor(tone, scheme),
              backgroundColor: scheme.surfaceContainerHighest,
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

/// Drop a trailing ".00" but keep ".25"/".50"/".75".
String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

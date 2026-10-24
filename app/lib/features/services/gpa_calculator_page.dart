import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/grading.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../academics/course_history_model.dart';
import '../common/course_names.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'gpa_widgets.dart';
import 'tool_scaffold.dart';

/// GPA Tool — Auto (computed from your live UCAM course history) + Manual
/// (hand-input). Both offer a CGPA calculator and a target-CGPA planner; Auto
/// adds running-course projection and retake impact from real data.
class GpaCalculatorPage extends ConsumerStatefulWidget {
  const GpaCalculatorPage({super.key});

  @override
  ConsumerState<GpaCalculatorPage> createState() => _GpaCalculatorPageState();
}

class _GpaCalculatorPageState extends ConsumerState<GpaCalculatorPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(courseHistoryProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'GPA Tool',
      builder: (context, mode) =>
          mode == ToolMode.auto ? const _AutoGpa() : const _ManualGpa(),
    );
  }
}

// ===========================================================================
// AUTO — everything computed from live course history.
// ===========================================================================
class _AutoGpa extends ConsumerWidget {
  const _AutoGpa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseHistoryProvider);
    return ResourceBody<CourseHistoryData>(
      state: state,
      loadingLabel: 'Loading your course history…',
      errorTitle: 'Couldn’t load your course history',
      onRetry: () => ref.read(courseHistoryProvider.notifier).load(force: true),
      builder: (d) => _AutoGpaBody(d),
    );
  }
}

class _AutoGpaBody extends ConsumerWidget {
  final CourseHistoryData data;
  const _AutoGpaBody(this.data);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The CGPA stays masked here too until it's revealed with the eye toggle.
    final cgpaShown = ref.watch(revealedSecretsProvider).contains(Secrets.cgpa);
    final cgpa = data.cgpa;
    final completed = data.completedCredits;
    final degreeReq = data.degreeRequirement;

    if (cgpa == null || completed == null) {
      return const EmptyState(
        icon: AppIcons.results,
        title: 'No standing data yet',
        message:
            'Open Course Grades once so we can read your CGPA and credits.',
      );
    }

    final running = data.courses.where((c) => c.isRunning).toList();
    final retakes = _detectRetakes(data.courses);

    final standing = _CurrentStanding(
        cgpa: cgpa, completed: completed, degreeReq: degreeReq);
    final planner = TargetPlannerCard(
      currentCgpa: cgpa,
      completedCredits: completed,
      degreeRequirement: degreeReq,
      autoFilled: true,
    );

    final sections = <Widget>[
      standing,
      DataUsedPanel(rows: [
        ('Current CGPA', cgpaShown ? cgpa.toStringAsFixed(2) : '••••'),
        ('Completed credits', completed.toStringAsFixed(1)),
        if (degreeReq != null)
          ('Degree requirement', degreeReq.toStringAsFixed(0)),
        ('Courses on record', '${data.courses.length}'),
        ('Running (ungraded) now', '${running.length}'),
        if (retakes.isNotEmpty) ('Repeated courses found', '${retakes.length}'),
      ]),
      if (running.isNotEmpty)
        _RunningProjection(running: running, cgpa: cgpa, completed: completed),
      planner,
      if (retakes.isNotEmpty) _RetakeImpact(retakes),
    ];
    return Stacked(children: [
      for (var i = 0; i < sections.length; i++)
        Reveal(index: i, child: sections[i]),
    ]);
  }

  /// Group graded attempts by course code; any code with 2+ graded attempts is a
  /// retake. Attempts are sorted old→new.
  List<_RetakeGroup> _detectRetakes(List<HistoryCourse> courses) {
    final byCode = <String, List<HistoryCourse>>{};
    for (final c in courses) {
      if (c.isRunning || c.courseCode == null || c.point == null) continue;
      (byCode[c.courseCode!] ??= []).add(c);
    }
    final out = <_RetakeGroup>[];
    byCode.forEach((code, attempts) {
      if (attempts.length < 2) return;
      attempts.sort(
          (a, b) => _trimCode(a.trimester).compareTo(_trimCode(b.trimester)));
      out.add(_RetakeGroup(
        code: code,
        name: attempts.first.courseName ?? code,
        attempts: attempts,
      ));
    });
    return out;
  }

  static int _trimCode(String? t) {
    if (t == null) return -1;
    final m = RegExp(r'\d+').firstMatch(t);
    return m != null ? (int.tryParse(m.group(0)!) ?? -1) : -1;
  }
}

class _RetakeGroup {
  final String code;
  final String name;
  final List<HistoryCourse> attempts;
  _RetakeGroup(
      {required this.code, required this.name, required this.attempts});
}

class _CurrentStanding extends StatelessWidget {
  final double cgpa;
  final double completed;
  final double? degreeReq;
  const _CurrentStanding(
      {required this.cgpa, required this.completed, required this.degreeReq});

  @override
  Widget build(BuildContext context) {
    final remaining = degreeReq != null
        ? (degreeReq! - completed).clamp(0, degreeReq!)
        : null;
    return Section(
      title: 'Your standing',
      child: StatStrip(items: [
        StatBlock(
          label: 'CGPA',
          value: cgpa.toStringAsFixed(2),
          large: true,
          secretId: Secrets.cgpa,
          hue: Hue.lavender,
        ),
        StatBlock(
          label: 'Completed',
          value: '${completed.toStringAsFixed(1)} cr',
          numeric: completed,
          format: (v) => '${v.toStringAsFixed(1)} cr',
          hue: Hue.mint,
        ),
        if (degreeReq != null)
          StatBlock(
            label: 'Degree requirement',
            value: '${degreeReq!.toStringAsFixed(0)} cr',
            hue: Hue.sky,
          ),
        if (remaining != null)
          StatBlock(
            label: 'Remaining',
            value: '${remaining.toStringAsFixed(0)} cr',
            numeric: remaining.toDouble(),
            format: (v) => '${v.toStringAsFixed(0)} cr',
            hue: Hue.peach,
          ),
      ]),
    );
  }
}

/// Lets the user assign expected grades to their in-progress courses and shows
/// the projected trimester GPA + new CGPA.
class _RunningProjection extends StatefulWidget {
  final List<HistoryCourse> running;
  final double cgpa;
  final double completed;
  const _RunningProjection(
      {required this.running, required this.cgpa, required this.completed});

  @override
  State<_RunningProjection> createState() => _RunningProjectionState();
}

class _RunningProjectionState extends State<_RunningProjection> {
  // Expected grade point per running course, keyed by LIST INDEX so duplicate
  // or blank codes never share an entry. null = not yet chosen.
  late final Map<int, double?> _expected = {
    for (var i = 0; i < widget.running.length; i++) i: 4.0,
  };

  @override
  Widget build(BuildContext context) {
    // Only project courses whose credit is known.
    var unknownCredits = 0;
    final picked = <({double credit, double? point})>[];
    for (var i = 0; i < widget.running.length; i++) {
      final c = widget.running[i];
      if (c.credit == null) {
        unknownCredits++;
        continue;
      }
      picked.add((credit: c.credit!, point: _expected[i]));
    }
    final trim = weightedGpaWithCredits(picked);
    final trimGpa = trim.gpa;
    final trimCredits = trim.credits;
    final newCgpa = trimGpa == null
        ? widget.cgpa
        : projectedCgpa(
            currentCgpa: widget.cgpa,
            completedCredits: widget.completed,
            trimesterGpa: trimGpa,
            trimesterCredits: trimCredits,
          );

    return Section(
      title: 'This trimester’s projection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Set the grade you expect in each in-progress course:',
              style: context.text.bodySmall),
          const SizedBox(height: Spacing.sm),
          RowGroup(
            children: [
              for (var i = 0; i < widget.running.length; i++)
                _RunningRow(
                  course: widget.running[i],
                  value: _expected[i],
                  onChanged: (v) => setState(() => _expected[i] = v),
                ),
            ],
          ),
          if (unknownCredits > 0)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                  '$unknownCredits course${unknownCredits == 1 ? '' : 's'} with an '
                  'unknown credit ${unknownCredits == 1 ? 'is' : 'are'} excluded '
                  'from this projection.',
                  style: context.text.bodySmall),
            ),
          const SizedBox(height: Spacing.md),
          StatStrip(bordered: false, items: [
            StatBlock(
                label: 'Projected GPA',
                value: trimGpa?.toStringAsFixed(2) ?? '—'),
            StatBlock(
                label: 'New CGPA',
                value: newCgpa.toStringAsFixed(2),
                valueColor: context.palette.accentInk),
          ]),
        ],
      ),
    );
  }
}

class _RunningRow extends StatelessWidget {
  final HistoryCourse course;
  final double? value;
  final ValueChanged<double?> onChanged;
  const _RunningRow(
      {required this.course, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final credit = course.credit != null
        ? '${course.credit!.toStringAsFixed(1)} cr'
        : null;
    return _CourseRowFrame(
      course: CourseName(
        code: course.courseCode ?? course.courseName ?? 'Course',
        title: course.courseName,
        extra: credit,
        titleStyle:
            context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: GradeDropdown(value: value, onChanged: onChanged),
    );
  }
}

class _RetakeImpact extends StatelessWidget {
  final List<_RetakeGroup> retakes;
  const _RetakeImpact(this.retakes);

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Retake impact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              'UIU counts the higher grade for a repeated course. Here’s how '
              'your retakes moved your quality points:',
              style: context.text.bodySmall),
          const SizedBox(height: Spacing.sm),
          RowGroup(children: [for (final g in retakes) _retakeRow(context, g)]),
        ],
      ),
    );
  }

  Widget _retakeRow(BuildContext context, _RetakeGroup g) {
    final p = context.palette;
    final first = g.attempts.first;
    final best =
        g.attempts.reduce((a, b) => (a.point ?? 0) >= (b.point ?? 0) ? a : b);
    // Retakes almost always carry a credit; assume the common 3-credit default
    // only as a last resort.
    const kAssumedCredit = 3.0;
    final credit = best.credit ?? first.credit ?? kAssumedCredit;
    final impact = retakeImpact(
      previousPoint: first.point ?? 0,
      newPoint: best.point ?? 0,
      credit: credit,
    );
    final improved = impact.improved;
    return _CourseRowFrame(
      course: CourseName(
        code: g.code,
        title: g.name == g.code ? null : g.name,
        extra: '${first.grade ?? '?'} → ${best.grade ?? '?'} '
            '(${g.attempts.length} attempts)',
        titleStyle:
            context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        improved
            ? '+${impact.countedImprovement.toStringAsFixed(2)} qp'
            : 'no loss',
        style: context.text.labelLarge?.copyWith(
            color: improved ? p.successInk : context.scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontFeatures: tabularFigures),
      ),
    );
  }
}

/// A list row whose main content is a [CourseName] (title over code).
class _CourseRowFrame extends StatelessWidget {
  final Widget course;
  final Widget trailing;
  const _CourseRowFrame({required this.course, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg + 4, vertical: 10),
        child: Row(
          children: [
            Expanded(child: course),
            const SizedBox(width: Spacing.md),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// MANUAL — hand input.
// ===========================================================================
class _ManualGpa extends StatelessWidget {
  const _ManualGpa();

  @override
  Widget build(BuildContext context) {
    return const Stacked(
      children: [
        Reveal(child: ManualCgpaCard()),
        Reveal(index: 1, child: PlannerCard()),
        Reveal(index: 2, child: ManualTargetCard()),
        Reveal(index: 3, child: GradeChartCard()),
      ],
    );
  }
}

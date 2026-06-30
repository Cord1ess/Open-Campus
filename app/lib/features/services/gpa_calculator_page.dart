import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/grading.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../academics/course_history_model.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'gpa_widgets.dart';
import 'tool_scaffold.dart';

/// GPA Tool — Auto (computed from your live UCAM course history) + Manual
/// (hand-input, ported from the reference calculator). Both offer a CGPA
/// calculator and a target-CGPA planner; Auto adds running-course projection and
/// retake impact from real data.
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
    return switch (state) {
      ResLoading() => const CardSkeleton(lines: 8),
      ResError(:final message) => StateMessage(
          icon: Icons.cloud_off,
          title: 'Couldn’t load your course history',
          subtitle: message,
          actionLabel: 'Try again',
          onAction: () =>
              ref.read(courseHistoryProvider.notifier).load(force: true),
        ),
      ResData(:final loaded) => _AutoGpaBody(loaded.data),
    };
  }
}

class _AutoGpaBody extends StatelessWidget {
  final CourseHistoryData data;
  const _AutoGpaBody(this.data);

  @override
  Widget build(BuildContext context) {
    final cgpa = data.cgpa;
    final completed = data.completedCredits;
    final degreeReq = data.degreeRequirement;

    if (cgpa == null || completed == null) {
      return const StateMessage(
        icon: Icons.school_outlined,
        title: 'No standing data yet',
        subtitle: 'Open Course History once so we can read your CGPA and credits.',
      );
    }

    // Running (in-progress, ungraded) courses for the projection.
    final running = data.courses.where((c) => c.isRunning).toList();
    // Retake detection: course codes that appear more than once.
    final retakes = _detectRetakes(data.courses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataUsedPanel(rows: [
          ('Current CGPA', cgpa.toStringAsFixed(2)),
          ('Completed credits', completed.toStringAsFixed(1)),
          if (degreeReq != null)
            ('Degree requirement', degreeReq.toStringAsFixed(0)),
          ('Courses on record', '${data.courses.length}'),
          ('Running (ungraded) now', '${running.length}'),
          if (retakes.isNotEmpty) ('Repeated courses found', '${retakes.length}'),
        ]),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          child: _CurrentStandingCard(
              cgpa: cgpa, completed: completed, degreeReq: degreeReq),
        ),
        if (running.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 60,
            child: _RunningProjectionCard(
                running: running, cgpa: cgpa, completed: completed),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          delayMs: 120,
          child: TargetPlannerCard(
            currentCgpa: cgpa,
            completedCredits: completed,
            degreeRequirement: degreeReq,
            autoFilled: true,
          ),
        ),
        if (retakes.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          FadeSlideIn(delayMs: 160, child: _RetakeImpactCard(retakes)),
        ],
      ],
    );
  }

  /// Group graded attempts by course code; any code with 2+ graded attempts is a
  /// retake. Returns [(code, name, attempts-sorted-old→new)].
  List<_RetakeGroup> _detectRetakes(List<HistoryCourse> courses) {
    final byCode = <String, List<HistoryCourse>>{};
    for (final c in courses) {
      if (c.isRunning || c.courseCode == null || c.point == null) continue;
      (byCode[c.courseCode!] ??= []).add(c);
    }
    final out = <_RetakeGroup>[];
    byCode.forEach((code, attempts) {
      if (attempts.length < 2) return;
      out.add(_RetakeGroup(
        code: code,
        name: attempts.first.courseName ?? code,
        attempts: attempts,
      ));
    });
    return out;
  }
}

class _RetakeGroup {
  final String code;
  final String name;
  final List<HistoryCourse> attempts;
  _RetakeGroup({required this.code, required this.name, required this.attempts});
}

class _CurrentStandingCard extends StatelessWidget {
  final double cgpa;
  final double completed;
  final double? degreeReq;
  const _CurrentStandingCard(
      {required this.cgpa, required this.completed, required this.degreeReq});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final remaining =
        degreeReq != null ? (degreeReq! - completed).clamp(0, degreeReq!) : null;
    return SectionCard(
      title: 'Your standing',
      icon: Icons.school_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('CGPA ${cgpa.toStringAsFixed(2)}',
            style: context.text.labelLarge?.copyWith(
                color: onAccent(scheme.primary), fontWeight: FontWeight.w800)),
      ),
      child: Column(
        children: [
          _kv(context, 'Completed credits', completed.toStringAsFixed(1)),
          if (degreeReq != null)
            _kv(context, 'Degree requirement', degreeReq!.toStringAsFixed(0)),
          if (remaining != null)
            _kv(context, 'Remaining', '${remaining.toStringAsFixed(0)} cr'),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant))),
          Text(v,
              style: context.text.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Lets the user assign expected grades to their in-progress courses and shows
/// the projected trimester GPA + new CGPA.
class _RunningProjectionCard extends StatefulWidget {
  final List<HistoryCourse> running;
  final double cgpa;
  final double completed;
  const _RunningProjectionCard(
      {required this.running, required this.cgpa, required this.completed});

  @override
  State<_RunningProjectionCard> createState() => _RunningProjectionCardState();
}

class _RunningProjectionCardState extends State<_RunningProjectionCard> {
  // Expected grade point per running course (null = not yet chosen).
  late final Map<String, double?> _expected = {
    for (final c in widget.running) (c.courseCode ?? c.courseName ?? ''): 4.0,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final picked = widget.running
        .map((c) => (
              credit: c.credit ?? 3,
              point: _expected[c.courseCode ?? c.courseName ?? ''],
            ))
        .toList();
    final trimGpa = weightedGpa(picked);
    final trimCredits = picked
        .where((p) => p.point != null)
        .fold<double>(0, (s, p) => s + p.credit);
    final newCgpa = trimGpa == null
        ? widget.cgpa
        : projectedCgpa(
            currentCgpa: widget.cgpa,
            completedCredits: widget.completed,
            trimesterGpa: trimGpa,
            trimesterCredits: trimCredits,
          );

    return SectionCard(
      title: 'This trimester’s projection',
      icon: Icons.trending_up_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set the grade you expect in each in-progress course:',
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.sm),
          for (final c in widget.running) ...[
            _RunningRow(
              course: c,
              value: _expected[c.courseCode ?? c.courseName ?? ''],
              onChanged: (v) => setState(
                  () => _expected[c.courseCode ?? c.courseName ?? ''] = v),
            ),
            Divider(height: Spacing.lg, color: scheme.outlineVariant),
          ],
          Row(
            children: [
              Expanded(
                child: _stat(context, 'Projected GPA',
                    trimGpa?.toStringAsFixed(2) ?? '—'),
              ),
              Expanded(
                child: _stat(context, 'New CGPA', newCgpa.toStringAsFixed(2),
                    accent: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value,
      {bool accent = false}) {
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.text.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        Text(value,
            style: context.text.headlineSmall?.copyWith(
                color: accent ? scheme.primary : scheme.onSurface,
                fontWeight: FontWeight.w800)),
      ],
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
    final scheme = context.scheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.courseName ?? course.courseCode ?? 'Course',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                  '${course.courseCode ?? ''}'
                  '${course.credit != null ? ' · ${course.credit!.toStringAsFixed(1)} cr' : ''}',
                  style: context.text.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        GradeDropdown(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _RetakeImpactCard extends StatelessWidget {
  final List<_RetakeGroup> retakes;
  const _RetakeImpactCard(this.retakes);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: 'Retake impact',
      icon: Icons.replay_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'UIU counts the higher grade for a repeated course. Here’s how '
              'your retakes moved your quality points:',
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.sm),
          for (var i = 0; i < retakes.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _retakeRow(context, retakes[i]),
          ],
        ],
      ),
    );
  }

  Widget _retakeRow(BuildContext context, _RetakeGroup g) {
    final scheme = context.scheme;
    // Best vs. first attempt (chronological order as returned).
    final first = g.attempts.first;
    final best = g.attempts.reduce((a, b) => (a.point ?? 0) >= (b.point ?? 0) ? a : b);
    final credit = best.credit ?? first.credit ?? 3;
    final impact = retakeImpact(
      previousPoint: first.point ?? 0,
      newPoint: best.point ?? 0,
      credit: credit,
    );
    final improved = impact.improved;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                  '${g.code} · ${first.grade ?? '?'} → ${best.grade ?? '?'} '
                  '(${g.attempts.length} attempts)',
                  style: context.text.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Text(
          improved
              ? '+${impact.countedImprovement.toStringAsFixed(2)} qp'
              : 'no loss',
          style: context.text.bodyMedium?.copyWith(
              color: improved ? context.status.good : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ===========================================================================
// MANUAL — ported reference calculator (hand input).
// ===========================================================================
class _ManualGpa extends StatelessWidget {
  const _ManualGpa();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(child: ManualCgpaCard()),
        SizedBox(height: Spacing.lg),
        FadeSlideIn(delayMs: 60, child: PlannerCard()),
        SizedBox(height: Spacing.lg),
        FadeSlideIn(delayMs: 120, child: ManualTargetCard()),
        SizedBox(height: Spacing.lg),
        FadeSlideIn(delayMs: 160, child: GradeChartCard()),
      ],
    );
  }
}

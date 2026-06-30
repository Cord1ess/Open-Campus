import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/grading.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../academics/course_history_model.dart';
import '../dashboard/dashboard_controller.dart';
import '../common/collapsing_title.dart';

/// GPA tools: a goal projection (what you need to reach a target CGPA), a
/// course-by-course trimester planner, and the UIU grade reference chart.
class GpaCalculatorPage extends ConsumerStatefulWidget {
  const GpaCalculatorPage({super.key});

  @override
  ConsumerState<GpaCalculatorPage> createState() => _GpaCalculatorPageState();
}

class _GpaCalculatorPageState extends ConsumerState<GpaCalculatorPage> {
  @override
  void initState() {
    super.initState();
    // Load course history once, after mount — not in build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(courseHistoryProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(courseHistoryProvider);
    final data =
        history is ResData<CourseHistoryData> ? history.loaded.data : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverCollapsingAppBar(title: 'GPA Tools'),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              FadeSlideIn(child: _GoalCard(data: data)),
              const SizedBox(height: Spacing.lg),
              const FadeSlideIn(delayMs: 60, child: _PlannerCard()),
              const SizedBox(height: Spacing.lg),
              const FadeSlideIn(delayMs: 120, child: _GradeChartCard()),
              const SizedBox(height: 96),
            ]),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatefulWidget {
  final CourseHistoryData? data;
  const _GoalCard({required this.data});

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  double _goal = 3.50;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final cgpa = d?.cgpa;
    final completed = d?.completedCredits;
    final degreeReq = d?.degreeRequirement;
    final scheme = context.scheme;

    if (cgpa == null || completed == null || degreeReq == null) {
      return SectionCard(
        title: 'Goal projection',
        icon: Icons.flag_outlined,
        child: const StateMessage(
          icon: Icons.school_outlined,
          title: 'Need your course history',
          subtitle: 'Open Course History once so we know your standing.',
        ),
      );
    }

    final remaining = (degreeReq - completed).clamp(0, degreeReq).toDouble();
    // The goal can never be below the current CGPA (you already have that), and
    // the slider's min is the current CGPA — so keep the goal in [cgpa, 4.0].
    // Without this, a student with CGPA > 3.50 (the default) would feed the
    // Slider a value below its min and trip an assertion / crash the page.
    final sliderMin = cgpa.clamp(0, 4).toDouble();
    final goal = _goal.clamp(sliderMin, 4.0);
    // Already at a perfect 4.00 — no goal to set; a min==max slider would assert.
    final atMax = sliderMin >= 4.0;
    final proj = projectGoal(
      goalCgpa: goal,
      currentCgpa: cgpa,
      completedCredits: completed,
      remainingCredits: remaining,
    );

    return SectionCard(
      title: 'Goal projection',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (atMax)
            _resultBanner(
              context,
              icon: Icons.workspace_premium,
              color: context.status.good,
              title: 'Perfect CGPA',
              body: 'You\'re already at a 4.00 — keep it up!',
            )
          else ...[
            Row(
              children: [
                Text('Target CGPA',
                    style: context.text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const Spacer(),
                Text(goal.toStringAsFixed(2),
                    style: context.text.titleMedium?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w800)),
              ],
            ),
            Slider(
              value: goal,
              min: sliderMin,
              max: 4.0,
              divisions: ((4.0 - sliderMin) * 20).clamp(1, 80).toInt(),
              label: goal.toStringAsFixed(2),
              onChanged: (v) => setState(() => _goal = v),
            ),
          ],
          const SizedBox(height: Spacing.sm),
          _line(
              context,
              'Current',
              '${cgpa.toStringAsFixed(2)} CGPA · '
                  '${completed.toStringAsFixed(0)} cr done'),
          _line(
              context,
              'Remaining',
              '${remaining.toStringAsFixed(0)} cr to '
                  '${degreeReq.toStringAsFixed(0)}'),
          if (!atMax) ...[
            const SizedBox(height: Spacing.md),
            if (proj.reachable && proj.neededAvg <= cgpa)
              // Goal already at/below current standing — no lift required.
              _resultBanner(
                context,
                icon: Icons.check_circle_outline,
                color: context.status.good,
                title: 'Already on track',
                body: 'Maintaining around your current ${cgpa.toStringAsFixed(2)} '
                    'keeps you at or above this goal.',
              )
            else if (proj.reachable)
              _resultBanner(
                context,
                icon: Icons.check_circle_outline,
                color: context.status.good,
                title: 'Reachable',
                body: 'Average ${proj.neededAvg.toStringAsFixed(2)} '
                    '(${nearestGradeAtOrAbove(proj.neededAvg).letter}) across your '
                    'remaining ${remaining.toStringAsFixed(0)} credits.',
              )
            else
              _resultBanner(
                context,
                icon: Icons.info_outline,
                color: context.status.warn,
                title: 'Out of reach',
                body: 'Even with all A\'s the most you can reach is '
                    '${proj.maxReachableCgpa.toStringAsFixed(2)}. '
                    'Set a goal at or below that.',
              ),
          ],
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 84,
                child: Text(label,
                    style: context.text.labelMedium
                        ?.copyWith(color: context.scheme.onSurfaceVariant))),
            Expanded(
                child: Text(value,
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _resultBanner(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String body}) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.text.titleSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerCard extends StatefulWidget {
  const _PlannerCard();

  @override
  State<_PlannerCard> createState() => _PlannerCardState();
}

class _PlannerCardState extends State<_PlannerCard> {
  final List<PlannedCourse> _courses = [
    PlannedCourse(label: 'Course 1', credit: 3),
    PlannedCourse(label: 'Course 2', credit: 3),
    PlannedCourse(label: 'Course 3', credit: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final gpa = weightedGpa(
        _courses.map((c) => (credit: c.credit, point: c.gradePoint)));
    final scheme = context.scheme;
    return SectionCard(
      title: 'Trimester planner',
      icon: Icons.calculate_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          gpa == null ? 'GPA —' : 'GPA ${gpa.toStringAsFixed(2)}',
          style: context.text.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _courses.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _PlannerRow(
              course: _courses[i],
              onChanged: () => setState(() {}),
              onRemove: _courses.length > 1
                  ? () => setState(() => _courses.removeAt(i))
                  : null,
            ),
          ],
          const SizedBox(height: Spacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: SpringTap(
              onTap: () => setState(() => _courses.add(PlannedCourse(
                  label: 'Course ${_courses.length + 1}', credit: 3))),
              borderRadius: BorderRadius.circular(Radii.full),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.sm),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add,
                        size: 18, color: scheme.onSecondaryContainer),
                    const SizedBox(width: 4),
                    Text('Add course',
                        style: context.text.labelLarge?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerRow extends StatelessWidget {
  final PlannedCourse course;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  const _PlannerRow({
    required this.course,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      children: [
        _CreditStepper(
          credit: course.credit,
          onChanged: (c) {
            course.credit = c;
            onChanged();
          },
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: DropdownButtonFormField<double?>(
            initialValue: course.gradePoint,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.sm),
                borderSide: BorderSide.none,
              ),
              hintText: 'Grade',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('— grade —')),
              for (final g in uiuGrades)
                DropdownMenuItem(
                  value: g.point,
                  child: Text('${g.letter}  (${g.point.toStringAsFixed(2)})'),
                ),
            ],
            onChanged: (v) {
              course.gradePoint = v;
              onChanged();
            },
          ),
        ),
        if (onRemove != null)
          IconButton(
            icon: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
            onPressed: onRemove,
          ),
      ],
    );
  }
}

class _CreditStepper extends StatelessWidget {
  final double credit;
  final ValueChanged<double> onChanged;
  const _CreditStepper({required this.credit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(context, Icons.remove,
              () => onChanged((credit - 1).clamp(0, 6).toDouble())),
          Text('${credit.toStringAsFixed(0)} cr',
              style: context.text.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          _stepBtn(context, Icons.add,
              () => onChanged((credit + 1).clamp(0, 6).toDouble())),
        ],
      ),
    );
  }

  Widget _stepBtn(BuildContext context, IconData icon, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: context.scheme.onSurfaceVariant),
        ),
      );
}

class _GradeChartCard extends StatelessWidget {
  const _GradeChartCard();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: 'UIU grade scale',
      icon: Icons.table_chart_outlined,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                _hcell(context, 'Grade', 2),
                _hcell(context, 'Point', 2),
                _hcell(context, 'Marks', 3),
                _hcell(context, 'Assessment', 4),
              ],
            ),
          ),
          for (final g in uiuGrades)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(g.letter,
                        style: context.text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Expanded(
                      flex: 2,
                      child: Text(g.point.toStringAsFixed(2),
                          style: context.text.bodyMedium)),
                  Expanded(
                      flex: 3,
                      child: Text('${g.minMark}–${g.maxMark}',
                          style: context.text.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant))),
                  Expanded(
                      flex: 4,
                      child: Text(g.assessment,
                          style: context.text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hcell(BuildContext context, String t, int flex) => Expanded(
        flex: flex,
        child: Text(t.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
                color: context.scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );
}

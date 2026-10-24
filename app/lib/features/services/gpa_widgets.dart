import 'package:flutter/material.dart';

import '../../core/domain/grading.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import 'numeric_input.dart';

/// A compact UIU-grade dropdown used across the GPA tool.
class GradeDropdown extends StatelessWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  final String hint;
  const GradeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Grade',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<double?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          hintText: hint,
        ),
        items: [
          DropdownMenuItem(value: null, child: Text('— $hint —')),
          for (final g in uiuGrades)
            DropdownMenuItem(
              value: g.point,
              child: Text('${g.letter}  (${g.point.toStringAsFixed(2)})'),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Two side-by-side numeric fields (current CGPA + completed credits).
class _StandingFields extends StatelessWidget {
  final TextEditingController cgpa;
  final TextEditingController completed;
  final VoidCallback onChanged;
  const _StandingFields(
      {required this.cgpa, required this.completed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FormWidth(
      maxWidth: 560,
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: cgpa,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: decimalInput,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Current CGPA'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: TextField(
            controller: completed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: decimalInput,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Completed credits'),
          ),
        ),
      ]),
    );
  }
}

// ===========================================================================
// MANUAL CGPA CALCULATOR.
// ===========================================================================
class ManualCgpaCard extends StatefulWidget {
  const ManualCgpaCard({super.key});

  @override
  State<ManualCgpaCard> createState() => _ManualCgpaCardState();
}

class _ManualCgpaCardState extends State<ManualCgpaCard> {
  final _completed = TextEditingController();
  final _currentCgpa = TextEditingController();
  final List<PlannedCourse> _courses = [
    PlannedCourse(label: 'Course 1', credit: 3, gradePoint: 4.0),
  ];

  @override
  void dispose() {
    _completed.dispose();
    _currentCgpa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clamp inputs to valid ranges before they reach the projection math.
    final completed = clampNonNeg(_completed.text);
    final currentCgpa = clampCgpa(_currentCgpa.text);

    // GPA and its credit base come from ONE computation so they can't diverge.
    final trim = weightedGpaWithCredits(
        _courses.map((c) => (credit: c.credit, point: c.gradePoint)));
    final trimGpa = trim.gpa;
    final trimCredits = trim.credits;
    final canProject =
        completed != null && currentCgpa != null && trimGpa != null;
    final newCgpa = canProject
        ? projectedCgpa(
            currentCgpa: currentCgpa,
            completedCredits: completed,
            trimesterGpa: trimGpa,
            trimesterCredits: trimCredits,
          )
        : null;

    return Section(
      title: 'CGPA calculator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StandingFields(
            cgpa: _currentCgpa,
            completed: _completed,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: Spacing.lg),
          Text('This trimester’s courses', style: context.text.titleSmall),
          const SizedBox(height: Spacing.sm),
          RowGroup(
            children: [
              for (var i = 0; i < _courses.length; i++)
                CourseInputRow(
                  course: _courses[i],
                  onChanged: () => setState(() {}),
                  onRemove: _courses.length > 1
                      ? () => setState(() => _courses.removeAt(i))
                      : null,
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          AddCourseButton(
            onTap: () => setState(() => _courses.add(PlannedCourse(
                label: 'Course ${_courses.length + 1}',
                credit: 3,
                gradePoint: 4.0))),
          ),
          const SizedBox(height: Spacing.lg),
          StatStrip(bordered: false, items: [
            StatBlock(
                label: 'Trimester GPA',
                value: trimGpa?.toStringAsFixed(2) ?? '—'),
            StatBlock(
                label: 'Projected CGPA',
                value: newCgpa?.toStringAsFixed(2) ?? '—',
                valueColor: newCgpa != null ? context.palette.accentInk : null),
          ]),
          if (!canProject)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                  'Enter your current CGPA, completed credits, and grades to '
                  'project your new CGPA.',
                  style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// TRIMESTER PLANNER.
// ===========================================================================
class PlannerCard extends StatefulWidget {
  const PlannerCard({super.key});

  @override
  State<PlannerCard> createState() => _PlannerCardState();
}

class _PlannerCardState extends State<PlannerCard> {
  final List<PlannedCourse> _courses = [
    PlannedCourse(label: 'Course 1', credit: 3),
    PlannedCourse(label: 'Course 2', credit: 3),
    PlannedCourse(label: 'Course 3', credit: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final gpa = weightedGpa(
        _courses.map((c) => (credit: c.credit, point: c.gradePoint)));
    return Section(
      title: 'Trimester planner',
      trailing: StatusBadge(
        gpa == null ? 'GPA —' : 'GPA ${gpa.toStringAsFixed(2)}',
        tone: gpa == null ? StatusTone.neutral : StatusTone.accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RowGroup(
            children: [
              for (var i = 0; i < _courses.length; i++)
                CourseInputRow(
                  course: _courses[i],
                  onChanged: () => setState(() {}),
                  onRemove: _courses.length > 1
                      ? () => setState(() => _courses.removeAt(i))
                      : null,
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          AddCourseButton(
            onTap: () => setState(() => _courses.add(
                PlannedCourse(label: 'Course ${_courses.length + 1}', credit: 3))),
          ),
        ],
      ),
    );
  }
}

/// One editable course line: credit stepper, grade dropdown, remove.
class CourseInputRow extends StatelessWidget {
  final PlannedCourse course;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  const CourseInputRow(
      {super.key, required this.course, required this.onChanged, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Row(
        children: [
          CreditStepper(
            credit: course.credit,
            onChanged: (c) {
              course.credit = c;
              onChanged();
            },
          ),
          const Spacer(),
          GradeDropdown(
            value: course.gradePoint,
            onChanged: (v) {
              course.gradePoint = v;
              onChanged();
            },
          ),
          if (onRemove != null) ...[
            const SizedBox(width: Spacing.xs),
            IconButton(
              icon: const Icon(AppIcons.clear, size: 18),
              tooltip: 'Remove course',
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact −/+ stepper for a course's credit hours (0–6).
class CreditStepper extends StatelessWidget {
  final double credit;
  final ValueChanged<double> onChanged;
  const CreditStepper({super.key, required this.credit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    Widget btn(IconData icon, String tip, VoidCallback onTap) => IconButton(
          icon: Icon(icon, size: 18),
          tooltip: tip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(AppIcons.remove, 'Fewer credits',
              () => onChanged((credit - 1).clamp(0, 6).toDouble())),
          SizedBox(
            width: 40,
            child: Text('${credit.toStringAsFixed(0)} cr',
                textAlign: TextAlign.center,
                style: context.text.labelLarge
                    ?.copyWith(fontFeatures: tabularFigures)),
          ),
          btn(AppIcons.add, 'More credits',
              () => onChanged((credit + 1).clamp(0, 6).toDouble())),
        ],
      ),
    );
  }
}

class AddCourseButton extends StatelessWidget {
  final VoidCallback onTap;
  const AddCourseButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(AppIcons.add, size: 18),
        label: const Text('Add course'),
      ),
    );
  }
}

// ===========================================================================
// TARGET-CGPA PLANNER — shared by Auto (auto-filled) and Manual.
// ===========================================================================

/// Auto variant: current CGPA + completed credits come from live data; the user
/// only sets the target and next-trimester credits.
class TargetPlannerCard extends StatefulWidget {
  final double currentCgpa;
  final double completedCredits;
  final double? degreeRequirement;
  final bool autoFilled;
  const TargetPlannerCard({
    super.key,
    required this.currentCgpa,
    required this.completedCredits,
    required this.degreeRequirement,
    this.autoFilled = false,
  });

  @override
  State<TargetPlannerCard> createState() => _TargetPlannerCardState();
}

class _TargetPlannerCardState extends State<TargetPlannerCard> {
  late double _target =
      (widget.currentCgpa + 0.25).clamp(widget.currentCgpa, 4.0).toDouble();
  final _nextCredits = TextEditingController(text: '15');

  @override
  void dispose() {
    _nextCredits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = clampNonNeg(_nextCredits.text) ?? 0;
    final plan = planNextTrimester(
      currentCgpa: widget.currentCgpa,
      completedCredits: widget.completedCredits,
      nextCredits: next,
      targetCgpa: _target,
    );
    return Section(
      title: 'Target CGPA planner',
      child: _TargetPlannerBody(
        currentCgpa: widget.currentCgpa,
        target: _target,
        nextCredits: _nextCredits,
        sliderMin: widget.currentCgpa.clamp(0, 4).toDouble(),
        onTarget: (v) => setState(() => _target = v.clamp(0.0, 4.0)),
        onCreditsChanged: () => setState(() {}),
        plan: plan,
        autoFilled: widget.autoFilled,
      ),
    );
  }
}

/// Manual variant: the user types current CGPA + completed credits too.
class ManualTargetCard extends StatefulWidget {
  const ManualTargetCard({super.key});

  @override
  State<ManualTargetCard> createState() => _ManualTargetCardState();
}

class _ManualTargetCardState extends State<ManualTargetCard> {
  final _current = TextEditingController();
  final _completed = TextEditingController();
  final _nextCredits = TextEditingController(text: '15');
  double _target = 3.50;

  @override
  void dispose() {
    _current.dispose();
    _completed.dispose();
    _nextCredits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = clampCgpa(_current.text);
    final completed = clampNonNeg(_completed.text);
    final next = clampNonNeg(_nextCredits.text) ?? 0;
    final ready = current != null && completed != null;
    final sliderMin = (current ?? 0).clamp(0, 4).toDouble();
    final target = _target.clamp(sliderMin, 4.0);
    final plan = ready
        ? planNextTrimester(
            currentCgpa: current,
            completedCredits: completed,
            nextCredits: next,
            targetCgpa: target,
          )
        : null;

    return Section(
      title: 'Target CGPA planner',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StandingFields(
            cgpa: _current,
            completed: _completed,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          if (!ready)
            Text('Enter your current CGPA and completed credits to plan.',
                style: context.text.bodySmall)
          else
            _TargetPlannerBody(
              currentCgpa: current,
              target: target,
              nextCredits: _nextCredits,
              sliderMin: sliderMin,
              onTarget: (v) => setState(() => _target = v.clamp(0.0, 4.0)),
              onCreditsChanged: () => setState(() {}),
              plan: plan!,
              autoFilled: false,
            ),
        ],
      ),
    );
  }
}

/// Shared target-planner body (slider + credits + result).
class _TargetPlannerBody extends StatelessWidget {
  final double currentCgpa;
  final double target;
  final TextEditingController nextCredits;
  final double sliderMin;
  final ValueChanged<double> onTarget;
  final VoidCallback onCreditsChanged;
  final NextTrimesterPlan plan;
  final bool autoFilled;
  const _TargetPlannerBody({
    required this.currentCgpa,
    required this.target,
    required this.nextCredits,
    required this.sliderMin,
    required this.onTarget,
    required this.onCreditsChanged,
    required this.plan,
    required this.autoFilled,
  });

  @override
  Widget build(BuildContext context) {
    final atMax = sliderMin >= 4.0;
    return FormWidth(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (autoFilled) ...[
            Text(
                'Using your live CGPA ${currentCgpa.toStringAsFixed(2)} — set a '
                'goal and how many credits you’ll take next.',
                style: context.text.bodySmall),
            const SizedBox(height: Spacing.md),
          ],
          Row(
            children: [
              Text('Target CGPA',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant)),
              const Spacer(),
              Text(target.toStringAsFixed(2),
                  style: context.text.titleMedium?.copyWith(
                      color: context.palette.accentInk,
                      fontFeatures: tabularFigures)),
            ],
          ),
          if (!atMax)
            Slider(
              value: target,
              min: sliderMin,
              max: 4.0,
              divisions: ((4.0 - sliderMin) * 20).clamp(1, 80).toInt(),
              label: target.toStringAsFixed(2),
              onChanged: onTarget,
            ),
          const SizedBox(height: Spacing.sm),
          TextField(
            controller: nextCredits,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: decimalInput,
            onChanged: (_) => onCreditsChanged(),
            decoration:
                const InputDecoration(labelText: 'Next trimester credits'),
          ),
          const SizedBox(height: Spacing.md),
          _result(context),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    if (plan.alreadyAchieved) {
      return InfoNote(
        tone: StatusTone.success,
        icon: AppIcons.success,
        title: 'Already achieved',
        text:
            'Your current ${currentCgpa.toStringAsFixed(2)} already meets this target.',
      );
    }
    if (!plan.achievable) {
      return InfoNote(
        tone: StatusTone.warning,
        icon: AppIcons.warning,
        title: 'Out of reach next trimester',
        text: 'You’d need ${plan.requiredGpa.toStringAsFixed(2)} GPA — above 4.00. '
            'The most you can reach next trimester is '
            '${plan.maxReachableCgpa.toStringAsFixed(2)}. Spread it over more trimesters.',
      );
    }
    final needed = nearestGradeAtOrAbove(plan.requiredGpa);
    return InfoNote(
      tone: StatusTone.success,
      icon: AppIcons.success,
      title: 'Reachable — ${difficultyLabel(plan.requiredGpa)}',
      text: 'You need a ${plan.requiredGpa.toStringAsFixed(2)} GPA '
          '(around ${needed.letter}) next trimester.',
    );
  }
}

// ===========================================================================
// GRADE REFERENCE CHART.
// ===========================================================================
class GradeChartCard extends StatelessWidget {
  const GradeChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'UIU grade scale',
      child: SimpleTable(
        columns: const ['Grade', 'Point', 'Marks', 'Assessment'],
        numeric: const [false, true, false, false],
        rows: [
          for (final g in uiuGrades)
            [
              g.letter,
              g.point.toStringAsFixed(2),
              '${g.minMark}–${g.maxMark}',
              g.assessment,
            ],
        ],
      ),
    );
  }
}

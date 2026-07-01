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
    final scheme = context.scheme;
    return SizedBox(
      width: 132,
      child: DropdownButtonFormField<double?>(
        initialValue: value,
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

// ===========================================================================
// MANUAL CGPA CALCULATOR (ported from the reference app).
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
    final scheme = context.scheme;
    // Clamp inputs to valid ranges before they reach the projection math: a CGPA
    // is 0–4, completed credits are non-negative. Prevents nonsense projections
    // from out-of-range typing (e.g. "9.9" CGPA, "-50" credits).
    final completed = clampNonNeg(_completed.text);
    final currentCgpa = clampCgpa(_currentCgpa.text);

    // Projected CGPA: current standing + this trimester's planned courses. GPA
    // and its credit base come from ONE computation so they can't diverge.
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

    return SectionCard(
      title: 'CGPA calculator',
      icon: Icons.calculate_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _currentCgpa,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalInput,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Current CGPA', isDense: true),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: TextField(
                controller: _completed,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalInput,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Completed credits', isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: Spacing.lg),
          Text('This trimester’s courses',
              style: context.text.labelMedium?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: Spacing.sm),
          for (var i = 0; i < _courses.length; i++) ...[
            if (i > 0) Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _CourseRow(
              course: _courses[i],
              onChanged: () => setState(() {}),
              onRemove: _courses.length > 1
                  ? () => setState(() => _courses.removeAt(i))
                  : null,
            ),
          ],
          const SizedBox(height: Spacing.md),
          _AddCourseButton(
            onTap: () => setState(() => _courses.add(PlannedCourse(
                label: 'Course ${_courses.length + 1}',
                credit: 3,
                gradePoint: 4.0))),
          ),
          const SizedBox(height: Spacing.lg),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _stat(context, 'Trimester GPA',
                      trimGpa?.toStringAsFixed(2) ?? '—'),
                ),
                Expanded(
                  child: _stat(context, 'Projected CGPA',
                      newCgpa?.toStringAsFixed(2) ?? '—',
                      accent: true),
                ),
              ],
            ),
          ),
          if (!canProject)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                  'Enter your current CGPA, completed credits, and grades to '
                  'project your new CGPA.',
                  style: context.text.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
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

// ===========================================================================
// TRIMESTER PLANNER (kept from the existing GPA tool).
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
    final scheme = context.scheme;
    return SectionCard(
      title: 'Trimester planner',
      icon: Icons.tune_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          gpa == null ? 'GPA —' : 'GPA ${gpa.toStringAsFixed(2)}',
          style: context.text.labelLarge?.copyWith(
              color: onAccent(scheme.primary), fontWeight: FontWeight.w800),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _courses.length; i++) ...[
            if (i > 0) Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _CourseRow(
              course: _courses[i],
              onChanged: () => setState(() {}),
              onRemove: _courses.length > 1
                  ? () => setState(() => _courses.removeAt(i))
                  : null,
            ),
          ],
          const SizedBox(height: Spacing.md),
          _AddCourseButton(
            onTap: () => setState(() => _courses.add(
                PlannedCourse(label: 'Course ${_courses.length + 1}', credit: 3))),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final PlannedCourse course;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  const _CourseRow(
      {required this.course, required this.onChanged, this.onRemove});

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
          child: Align(
            alignment: Alignment.centerRight,
            child: GradeDropdown(
              value: course.gradePoint,
              onChanged: (v) {
                course.gradePoint = v;
                onChanged();
              },
            ),
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

class _AddCourseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCourseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: SpringTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: scheme.primary),
              const SizedBox(width: 4),
              Text('Add course',
                  style: context.text.labelLarge?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
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
    return _TargetPlannerBody(
      currentCgpa: widget.currentCgpa,
      target: _target,
      nextCredits: _nextCredits,
      sliderMin: widget.currentCgpa.clamp(0, 4).toDouble(),
      onTarget: (v) => setState(() => _target = v.clamp(0.0, 4.0)),
      onCreditsChanged: () => setState(() {}),
      plan: plan,
      autoFilled: widget.autoFilled,
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
    final scheme = context.scheme;
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

    return SectionCard(
      title: 'Target CGPA planner',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _current,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalInput,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Current CGPA', isDense: true),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: TextField(
                controller: _completed,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalInput,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Completed credits', isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: Spacing.md),
          if (!ready)
            Text('Enter your current CGPA and completed credits to plan.',
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant))
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
              embedded: true,
            ),
        ],
      ),
    );
  }
}

/// Shared target-planner body (slider + credits + result), used by both variants.
class _TargetPlannerBody extends StatelessWidget {
  final double currentCgpa;
  final double target;
  final TextEditingController nextCredits;
  final double sliderMin;
  final ValueChanged<double> onTarget;
  final VoidCallback onCreditsChanged;
  final NextTrimesterPlan plan;
  final bool autoFilled;
  final bool embedded; // true when nested inside ManualTargetCard's SectionCard
  const _TargetPlannerBody({
    required this.currentCgpa,
    required this.target,
    required this.nextCredits,
    required this.sliderMin,
    required this.onTarget,
    required this.onCreditsChanged,
    required this.plan,
    required this.autoFilled,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final atMax = sliderMin >= 4.0;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (autoFilled)
          Text('Using your live CGPA ${currentCgpa.toStringAsFixed(2)} — set a '
              'goal and how many credits you’ll take next.',
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant)),
        if (autoFilled) const SizedBox(height: Spacing.md),
        Row(
          children: [
            Text('Target CGPA',
                style: context.text.bodyMedium
                    ?.copyWith(color: context.scheme.onSurfaceVariant)),
            const Spacer(),
            Text(target.toStringAsFixed(2),
                style: context.text.titleMedium?.copyWith(
                    color: context.scheme.primary, fontWeight: FontWeight.w800)),
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
          decoration: const InputDecoration(
              labelText: 'Next trimester credits', isDense: true),
        ),
        const SizedBox(height: Spacing.md),
        _resultBanner(context),
      ],
    );
    if (embedded) return body;
    return SectionCard(
      title: 'Target CGPA planner',
      icon: Icons.flag_outlined,
      child: body,
    );
  }

  Widget _resultBanner(BuildContext context) {
    if (plan.alreadyAchieved) {
      return _banner(context, Icons.check_circle_outline, context.status.good,
          'Already achieved',
          'Your current ${currentCgpa.toStringAsFixed(2)} already meets this target.');
    }
    if (!plan.achievable) {
      return _banner(context, Icons.info_outline, context.status.warn,
          'Out of reach next trimester',
          'You’d need ${plan.requiredGpa.toStringAsFixed(2)} GPA — above 4.00. '
          'The most you can reach next trimester is '
          '${plan.maxReachableCgpa.toStringAsFixed(2)}. Spread it over more trimesters.');
    }
    final needed = nearestGradeAtOrAbove(plan.requiredGpa);
    return _banner(context, Icons.flag_outlined, context.status.good,
        'Reachable — ${difficultyLabel(plan.requiredGpa)}',
        'You need a ${plan.requiredGpa.toStringAsFixed(2)} GPA '
        '(around ${needed.letter}) next trimester.');
  }

  Widget _banner(BuildContext context, IconData icon, Color color, String title,
      String body) {
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

// ===========================================================================
// GRADE REFERENCE CHART (kept from the existing GPA tool).
// ===========================================================================
class GradeChartCard extends StatelessWidget {
  const GradeChartCard({super.key});

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

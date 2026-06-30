import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/trend_chart.dart';
import '../../shared/widgets.dart';
import 'models.dart';

/// Helpers shared by the dashboard, results, and attendance pages.
double? overallAttendancePct(AttendanceData a) {
  if (a.courses.isEmpty) return null;
  final held = a.courses.fold<int>(0, (s, c) => s + c.totalHeld);
  final present = a.courses.fold<int>(0, (s, c) => s + c.present);
  return held == 0 ? null : present / held * 100;
}

/// Total classes attended across all courses.
int attendedClasses(AttendanceData a) =>
    a.courses.fold<int>(0, (s, c) => s + c.present);

/// Total classes held across all courses.
int totalClasses(AttendanceData a) =>
    a.courses.fold<int>(0, (s, c) => s + c.totalHeld);

/// Attendance band → THEME color (not the fixed green/amber/red status set), so
/// the card follows the active seed/theme. Healthy attendance uses the brand
/// BLUE accent (scheme.secondary); at-risk stays the theme's error red as a
/// clear warning.
Color attendanceColor(BuildContext context, double pct) {
  final scheme = context.scheme;
  if (pct >= 70) return scheme.secondary; // brand blue
  return scheme.error;
}

class ResultsContent extends StatefulWidget {
  final ResultsData data;
  final bool showChart;
  /// The big CGPA + latest-GPA header row. Hidden on the full Results page (which
  /// has its own Overview card) so it isn't shown twice.
  final bool showHeader;
  const ResultsContent(this.data,
      {super.key, this.showChart = true, this.showHeader = true});

  @override
  State<ResultsContent> createState() => _ResultsContentState();
}

class _ResultsContentState extends State<ResultsContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final scheme = context.scheme;
    if (data.semesters.isEmpty) {
      return const StateMessage(
          icon: Icons.school_outlined, title: 'No results yet');
    }
    final ordered = data.semesters.reversed.toList();
    final cgpa = data.latestCgpa ?? data.semesters.first.cgpa;
    final latestGpa = data.semesters.first.gpa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CGPA + latest GPA side by side, both theme-colored.
        if (widget.showHeader)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUp(cgpa,
                  style: context.text.displaySmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w800)),
              const SizedBox(width: Spacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('CGPA',
                    style: context.text.titleMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              const Spacer(),
              // Latest-term GPA chip in the secondary theme color.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text('GPA ${latestGpa.toStringAsFixed(2)}',
                    style: context.text.labelLarge?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        if (widget.showChart && ordered.length >= 2) ...[
          if (widget.showHeader) const SizedBox(height: Spacing.lg),
          _GpaCgpaChart(ordered),
        ],
        // Accordion: the per-semester breakdown is hidden until expanded.
        const SizedBox(height: Spacing.sm),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Row(
              children: [
                Text(
                    _expanded
                        ? 'Hide Semesterwise Breakdown'
                        : 'Semesterwise Breakdown (${data.semesters.length})',
                    style: context.text.labelLarge?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: Motion.fast,
                  child: Icon(Icons.expand_more, color: scheme.primary),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: Motion.medium,
          sizeCurve: Motion.emphasized,
          crossFadeState:
              _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
              ...data.semesters.map((s) => _ResultRow(s)),
            ],
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// GPA (per trimester) + CGPA (cumulative) trend, like UCAM's chart but with a
/// tight Y-range, full term labels, toggleable series, and a readable tooltip.
class _GpaCgpaChart extends StatelessWidget {
  final List<SemesterResult> ordered; // oldest -> newest
  const _GpaCgpaChart(this.ordered);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final labels = [for (final s in ordered) '${s.semester} ${s.year}'];
    return TrendChart(
      labels: labels,
      series: [
        ChartSeries(
          name: 'CGPA',
          color: scheme.primary,
          values: [for (final s in ordered) s.cgpa],
        ),
        ChartSeries(
          name: 'GPA',
          color: scheme.tertiary,
          values: [for (final s in ordered) s.gpa],
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final SemesterResult s;
  const _ResultRow(this.s);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text('${s.semester} ${s.year}',
                style: context.text.bodyMedium),
          ),
          _MiniStat('GPA', s.gpa.toStringAsFixed(2), context.scheme.tertiary),
          const SizedBox(width: Spacing.lg),
          _MiniStat('CGPA', s.cgpa.toStringAsFixed(2), context.scheme.primary),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label ',
            style: context.text.labelSmall
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
        Text(value,
            style: context.text.titleSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

enum _AttFilter { all, atRisk, strong }

class AttendanceContent extends StatefulWidget {
  final AttendanceData data;
  const AttendanceContent(this.data, {super.key});

  @override
  State<AttendanceContent> createState() => _AttendanceContentState();
}

class _AttendanceContentState extends State<AttendanceContent> {
  _AttFilter _filter = _AttFilter.all;

  // Sort + counts are derived once per data change, not per build — so tapping a
  // filter chip (a setState) doesn't re-sort the whole course list every time.
  late List<CourseAttendance> _sorted;
  late int _atRiskCount;
  late int _strongCount;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(AttendanceContent old) {
    super.didUpdateWidget(old);
    if (!identical(old.data, widget.data)) _recompute();
  }

  void _recompute() {
    _sorted = [...widget.data.courses]..sort((a, b) => a.pct.compareTo(b.pct));
    _atRiskCount = _sorted.where((c) => c.pct < 70).length;
    _strongCount = _sorted.where((c) => c.pct >= 85).length;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.courses.isEmpty) {
      return const StateMessage(
          icon: Icons.event_busy_outlined, title: 'No attendance data');
    }
    final scheme = context.scheme;
    final sorted = _sorted;
    final atRiskCount = _atRiskCount;
    final strongCount = _strongCount;
    final shown = switch (_filter) {
      _AttFilter.all => sorted,
      _AttFilter.atRisk => sorted.where((c) => c.pct < 70).toList(),
      _AttFilter.strong => sorted.where((c) => c.pct >= 85).toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips.
        Wrap(
          spacing: Spacing.sm,
          children: [
            _FilterChip(
              label: 'All ${sorted.length}',
              selected: _filter == _AttFilter.all,
              onTap: () => setState(() => _filter = _AttFilter.all),
            ),
            _FilterChip(
              label: 'At risk $atRiskCount',
              color: scheme.error,
              selected: _filter == _AttFilter.atRisk,
              onTap: () => setState(() => _filter = _AttFilter.atRisk),
            ),
            _FilterChip(
              label: 'Strong $strongCount',
              color: scheme.secondary,
              selected: _filter == _AttFilter.strong,
              onTap: () => setState(() => _filter = _AttFilter.strong),
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Text('No courses in this filter.',
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          )
        else
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : Spacing.lg),
              child: AttendanceRow(shown[i]),
            ),
      ],
    );
  }
}


/// A selectable filter chip for the attendance list.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final accent = color ?? scheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.full),
      child: AnimatedContainer(
        duration: Motion.fast,
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Text(label,
            style: context.text.labelMedium?.copyWith(
                color: selected ? onAccent(accent) : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class AttendanceRow extends StatelessWidget {
  final CourseAttendance c;
  const AttendanceRow(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    final pct = c.pct;
    final color = attendanceColor(context, pct);
    final atRisk = pct < 70;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${c.courseCode} · ${c.section}',
                  style: context.text.titleSmall),
            ),
            if (atRisk)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.warning_amber_rounded,
                    size: 15, color: context.scheme.error),
              ),
            Text('${pct.toStringAsFixed(0)}%',
                style: context.text.titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 2),
        Text(c.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        // RepaintBoundary isolates the per-frame bar animation so it doesn't
        // force the surrounding list/card to repaint during scroll.
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (pct / 100).clamp(0, 1)),
              duration: Motion.slow,
              curve: Motion.emphasized,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: context.scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('${c.present}/${c.totalHeld} classes · ${c.absent} absent',
            style: context.text.labelSmall
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
      ],
    );
  }
}

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

Color attendanceColor(BuildContext context, double pct) {
  if (pct >= 85) return context.status.good;
  if (pct >= 70) return context.status.warn;
  return context.status.bad;
}

class ResultsContent extends StatelessWidget {
  final ResultsData data;
  final bool showChart;
  const ResultsContent(this.data, {super.key, this.showChart = true});

  @override
  Widget build(BuildContext context) {
    if (data.semesters.isEmpty) {
      return const StateMessage(
          icon: Icons.school_outlined, title: 'No results yet');
    }
    final ordered = data.semesters.reversed.toList();
    final cgpa = data.latestCgpa ?? data.semesters.first.cgpa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CountUp(cgpa,
                style: context.text.displaySmall
                    ?.copyWith(color: context.scheme.primary)),
            const SizedBox(width: Spacing.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('CGPA',
                  style: context.text.titleMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant)),
            ),
          ],
        ),
        if (showChart && ordered.length >= 2) ...[
          const SizedBox(height: Spacing.lg),
          _GpaCgpaChart(ordered),
        ],
        const SizedBox(height: Spacing.sm),
        ...data.semesters.map((s) => _ResultRow(s)),
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
          color: context.status.good,
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
          _MiniStat('GPA', s.gpa.toStringAsFixed(2),
              context.scheme.onSurfaceVariant),
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

class AttendanceContent extends StatelessWidget {
  final AttendanceData data;
  const AttendanceContent(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    if (data.courses.isEmpty) {
      return const StateMessage(
          icon: Icons.event_busy_outlined, title: 'No attendance data');
    }
    final sorted = [...data.courses]..sort((a, b) => a.pct.compareTo(b.pct));
    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : Spacing.lg),
            child: AttendanceRow(sorted[i]),
          ),
      ],
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
                    size: 15, color: context.status.bad),
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
        ClipRRect(
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
        const SizedBox(height: 4),
        Text('${c.present}/${c.totalHeld} classes · ${c.absent} absent',
            style: context.text.labelSmall
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
      ],
    );
  }
}

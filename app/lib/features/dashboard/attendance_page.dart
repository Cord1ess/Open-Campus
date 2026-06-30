import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'models.dart';
import 'resource_view.dart';

/// Full Attendance page — richer than the dashboard card: an overall summary
/// (overall %, present/held/absent, at-risk/strong counts) and a classes-left
/// estimate, then the per-course list. All theme-coloured.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(child: _SummaryCard(data)),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          delayMs: 80,
          child: SectionCard(
            title: 'By course',
            icon: Icons.list_alt_outlined,
            child: AttendanceContent(data),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AttendanceData data;
  const _SummaryCard(this.data);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final overall = overallAttendancePct(data) ?? 0;
    final present = attendedClasses(data);
    final held = totalClasses(data);
    final absent = held - present;
    final atRisk = data.courses.where((c) => c.pct < 70).length;
    final color = attendanceColor(context, overall);

    return SectionCard(
      title: 'Overall',
      icon: Icons.event_available_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('${overall.toStringAsFixed(0)}%',
            style: context.text.labelLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall progress bar.
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (overall / 100).clamp(0, 1)),
                duration: Motion.slow,
                curve: Motion.emphasized,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(child: _stat(context, 'Present', '$present', scheme.secondary)),
              Expanded(child: _stat(context, 'Absent', '$absent',
                  absent > 0 ? scheme.error : scheme.onSurfaceVariant)),
              Expanded(child: _stat(context, 'Held', '$held', scheme.onSurface)),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                  child: _stat(context, 'Courses', '${data.courses.length}',
                      scheme.primary)),
              Expanded(
                  child: _stat(context, 'At risk (<70%)', '$atRisk',
                      atRisk > 0 ? scheme.error : scheme.onSurfaceVariant)),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';
import '../dashboard/resource_view.dart';

const _dayOrder = [
  'Saturday',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];

/// Weekly class routine, grouped by day. Data is part of /student/home.
class ClassRoutinePage extends ConsumerWidget {
  const ClassRoutinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.large(title: Text('Class Routine')),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (state) {
                  ResLoading() => const CardSkeleton(lines: 6),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn\'t load',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () => ref.read(homeProvider.notifier).load(),
                    ),
                  ResData(:final loaded) => _Content(loaded.data.routine),
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

class _Content extends StatelessWidget {
  final List<ClassSession> routine;
  const _Content(this.routine);

  @override
  Widget build(BuildContext context) {
    if (routine.isEmpty) {
      return const StateMessage(
          icon: Icons.event_busy_outlined,
          title: 'No routine',
          subtitle: 'No class schedule is published yet.');
    }
    final byDay = <String, List<ClassSession>>{};
    for (final s in routine) {
      (byDay[s.day] ??= []).add(s);
    }
    final days = _dayOrder.where(byDay.containsKey).toList();
    final todayName = _weekdayName(DateTime.now().weekday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 40 + i * 40,
            child: _DayCard(
              day: day,
              sessions: byDay[day]!,
              isToday: day == todayName,
            ),
          ),
        ],
      ],
    );
  }

  static String _weekdayName(int weekday) => const {
        DateTime.saturday: 'Saturday',
        DateTime.sunday: 'Sunday',
        DateTime.monday: 'Monday',
        DateTime.tuesday: 'Tuesday',
        DateTime.wednesday: 'Wednesday',
        DateTime.thursday: 'Thursday',
        DateTime.friday: 'Friday',
      }[weekday]!;
}

class _DayCard extends StatelessWidget {
  final String day;
  final List<ClassSession> sessions;
  final bool isToday;
  const _DayCard({
    required this.day,
    required this.sessions,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: day,
      icon: Icons.today_outlined,
      trailing: isToday
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Today',
                  style: context.text.labelSmall?.copyWith(
                      color: scheme.onPrimary, fontWeight: FontWeight.w800)),
            )
          : null,
      child: Column(
        children: [
          for (var i = 0; i < sessions.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            ClassSessionRow(sessions[i]),
          ],
        ],
      ),
    );
  }
}

/// One class session row — reused by the home "Today" card too.
class ClassSessionRow extends StatelessWidget {
  final ClassSession s;
  const ClassSessionRow(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${s.courseCode}${s.section != null ? ' (${s.section})' : ''}',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (s.start != null && s.end != null)
                Text('${s.start} – ${s.end}',
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';
import '../dashboard/resource_view.dart';
import '../common/collapsing_title.dart';
import 'ics_export.dart';
import 'routine_schedule.dart';

const _dayOrder = [
  'Saturday',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];

/// Weekly class routine, grouped by day, with a live "next class" countdown and
/// an .ics export. Routine data is part of /student/home.
class ClassRoutinePage extends ConsumerWidget {
  const ClassRoutinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeProvider.notifier).load(force: true),
        child: CustomScrollView(
          slivers: [
            const SliverCollapsingAppBar(title: 'Class Routine'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (state) {
                  ResLoading() => const SectionCard(
                      title: 'Class Routine',
                      icon: Icons.calendar_view_week_outlined,
                      child: CardSkeleton(label: 'Loading your routine…')),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn’t load',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.read(homeProvider.notifier).load(force: true),
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
      return const SectionCard(
        title: 'Class Routine',
        icon: Icons.calendar_view_week_outlined,
        child: StateMessage(
            icon: Icons.event_busy_outlined,
            title: 'No routine',
            subtitle: 'No class schedule is published yet.'),
      );
    }
    final byDay = <String, List<ClassSession>>{};
    for (final s in routine) {
      (byDay[s.day] ??= []).add(s);
    }
    // Sort each day's sessions by start time.
    for (final list in byDay.values) {
      list.sort((a, b) {
        final pa = parseClock(a.start), pb = parseClock(b.start);
        if (pa == null || pb == null) return 0;
        return (pa.$1 * 60 + pa.$2).compareTo(pb.$1 * 60 + pb.$2);
      });
    }
    final days = _dayOrder.where(byDay.containsKey).toList();
    final todayName = _weekdayName(DateTime.now().weekday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(child: _NextClassHero(routine)),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(delayMs: 60, child: _ExportRow(routine)),
        const SizedBox(height: Spacing.lg),
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 100 + i * 40,
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

/// Gradient hero showing the next class with a live countdown (or an "in class
/// now" state). Ticks every second.
class _NextClassHero extends StatefulWidget {
  final List<ClassSession> routine;
  const _NextClassHero(this.routine);

  @override
  State<_NextClassHero> createState() => _NextClassHeroState();
}

class _NextClassHeroState extends State<_NextClassHero> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final accent = scheme.primary;
    final onAcc = scheme.onPrimary;
    final now = DateTime.now();

    // Is a class happening right now?
    final ongoing = widget.routine.where((s) => isOngoing(s, now)).toList();
    final next = nextClass(widget.routine, now);

    Widget body;
    if (ongoing.isNotEmpty) {
      final s = ongoing.first;
      body = _heroBody(
        context,
        onAcc,
        kicker: 'In class now',
        title: '${s.courseCode}${s.section != null ? ' (${s.section})' : ''}',
        sub: s.start != null && s.end != null ? '${s.start} – ${s.end}' : null,
        big: 'LIVE',
      );
    } else if (next != null) {
      final s = next.session;
      final left = next.start.difference(now);
      body = _heroBody(
        context,
        onAcc,
        kicker: 'Next class · ${_dayLabel(next.start, now)}',
        title: '${s.courseCode}${s.section != null ? ' (${s.section})' : ''}',
        sub: s.start != null && s.end != null ? '${s.start} – ${s.end}' : null,
        big: _fmtCountdown(left),
      );
    } else {
      body = _heroBody(context, onAcc,
          kicker: 'Class routine', title: 'No upcoming classes', sub: null, big: null);
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: body,
    );
  }

  Widget _heroBody(BuildContext context, Color onAcc,
      {required String kicker,
      required String title,
      String? sub,
      String? big}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kicker.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                      color: onAcc.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(title,
                  style: context.text.titleLarge
                      ?.copyWith(color: onAcc, fontWeight: FontWeight.w800)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub,
                    style: context.text.bodySmall
                        ?.copyWith(color: onAcc.withValues(alpha: 0.85))),
              ],
            ],
          ),
        ),
        if (big != null) ...[
          const SizedBox(width: Spacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(big,
                  style: context.text.headlineSmall?.copyWith(
                      color: onAcc,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              if (big != 'LIVE')
                Text('remaining',
                    style: context.text.labelSmall
                        ?.copyWith(color: onAcc.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ],
    );
  }

  String _dayLabel(DateTime when, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(when.year, when.month, when.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return _Content._weekdayName(when.weekday);
  }

  String _fmtCountdown(Duration d) {
    if (d.inDays >= 1) {
      return '${d.inDays}d ${d.inHours % 24}h';
    }
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

/// Export-the-routine action row.
class _ExportRow extends StatefulWidget {
  final List<ClassSession> routine;
  const _ExportRow(this.routine);

  @override
  State<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends State<_ExportRow> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final ics = routineIcs(widget.routine, calendarName: 'UIU Class Routine');
    final ok = await exportRawIcs(ics, calendarName: 'class-routine');
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Routine exported — open the .ics to add your weekly classes.'
          : 'Couldn’t export here. Try again on the mobile app.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _export,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text(_busy ? 'Exporting…' : 'Export routine (.ics)'),
      ),
    );
  }
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
    final now = DateTime.now();
    return SectionCard(
      title: day,
      icon: Icons.today_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${sessions.length} class${sessions.length == 1 ? '' : 'es'}',
              style: context.text.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          if (isToday) ...[
            const SizedBox(width: Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Today',
                  style: context.text.labelSmall?.copyWith(
                      color: scheme.onPrimary, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < sessions.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _SessionRow(sessions[i],
                ongoing: isToday && isOngoing(sessions[i], now)),
          ],
        ],
      ),
    );
  }
}

/// One class session in the routine. Highlights the live class.
class _SessionRow extends StatelessWidget {
  final ClassSession s;
  final bool ongoing;
  const _SessionRow(this.s, {this.ongoing = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final accent = ongoing ? scheme.secondary : scheme.primary;
    return Container(
      padding: ongoing ? const EdgeInsets.all(Spacing.sm) : EdgeInsets.zero,
      decoration: ongoing
          ? BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.sm),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: accent,
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
          if (ongoing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.secondary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('NOW',
                  style: context.text.labelSmall?.copyWith(
                      color: scheme.onSecondary, fontWeight: FontWeight.w800)),
            ),
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

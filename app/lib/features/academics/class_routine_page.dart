import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';
import '../dashboard/resource_view.dart';
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

String _weekdayName(int weekday) => const {
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
    }[weekday]!;

String _sessionTitle(ClassSession s) =>
    '${s.courseCode}${s.section != null ? ' (${s.section})' : ''}';

String? _sessionTime(ClassSession s) =>
    s.start != null && s.end != null ? '${s.start} – ${s.end}' : null;

/// Weekly class routine, grouped by day, with a live "next class" countdown and
/// an .ics export. Routine data is part of /student/home.
class ClassRoutinePage extends ConsumerWidget {
  const ClassRoutinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    return PageScaffold(
      title: 'Class Routine',
      onRefresh: () => ref.read(homeProvider.notifier).load(force: true),
      body: ResourceBody<HomeSummary>(
        state: state,
        loadingLabel: 'Loading your routine…',
        errorTitle: 'Couldn’t load your routine',
        onRetry: () => ref.read(homeProvider.notifier).load(force: true),
        builder: (d) => _Content(d.routine),
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
      return const EmptyState(
          icon: AppIcons.routine,
          title: 'No routine',
          message: 'No class schedule is published yet.');
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

    return Stacked(
      children: [
        _NextClassPanel(routine),
        Align(
          alignment: Alignment.centerLeft,
          child: _ExportButton(routine),
        ),
        ResponsiveGrid(
          maxColumns: 2,
          stretch: false,
          spacing: Spacing.xl,
          runSpacing: Spacing.xl,
          children: [
            for (final day in days)
              _DayGroup(
                day: day,
                sessions: byDay[day]!,
                isToday: day == todayName,
              ),
          ],
        ),
      ],
    );
  }
}

/// Next class with a live countdown (or an "in class now" state). Only the
/// countdown text listens to the per-second tick.
class _NextClassPanel extends StatefulWidget {
  final List<ClassSession> routine;
  const _NextClassPanel(this.routine);

  @override
  State<_NextClassPanel> createState() => _NextClassPanelState();
}

class _NextClassPanelState extends State<_NextClassPanel>
    with WidgetsBindingObserver {
  Timer? _ticker;
  final _now = ValueNotifier<DateTime>(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _now.value = DateTime.now();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause the per-second tick while the app is backgrounded.
    if (state == AppLifecycleState.resumed) {
      _now.value = DateTime.now();
      _startTicker();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stopTicker();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: ValueListenableBuilder<DateTime>(
        valueListenable: _now,
        builder: (context, now, _) {
          final ongoing =
              widget.routine.where((s) => isOngoing(s, now)).toList();
          final next = nextClass(widget.routine, now);
          if (ongoing.isNotEmpty) {
            final s = ongoing.first;
            return _body(context,
                kicker: 'In class now',
                title: _sessionTitle(s),
                sub: _sessionTime(s),
                trailing: const StatusBadge('Now', tone: StatusTone.success));
          }
          if (next != null) {
            final s = next.session;
            return _body(context,
                kicker: 'Next class · ${_dayLabel(next.start, now)}',
                title: _sessionTitle(s),
                sub: _sessionTime(s),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_fmtCountdown(next.start.difference(now)),
                        style: context.text.titleLarge
                            ?.copyWith(fontFeatures: tabularFigures)),
                    Text('remaining', style: context.text.bodySmall),
                  ],
                ));
          }
          return _body(context,
              kicker: 'Class routine',
              title: 'No upcoming classes',
              sub: null,
              trailing: null);
        },
      ),
    );
  }

  Widget _body(BuildContext context,
      {required String kicker,
      required String title,
      String? sub,
      Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kicker,
                  style: context.text.labelMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant)),
              const SizedBox(height: Spacing.xxs),
              Text(title, style: context.text.titleMedium),
              if (sub != null) Text(sub, style: context.text.bodySmall),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Spacing.lg),
          trailing,
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
    return _weekdayName(when.weekday);
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

/// Export-the-routine action.
class _ExportButton extends StatefulWidget {
  final List<ClassSession> routine;
  const _ExportButton(this.routine);

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
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
    return OutlinedButton.icon(
      onPressed: _busy ? null : _export,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(AppIcons.download, size: 18),
      label: Text(_busy ? 'Exporting…' : 'Export routine (.ics)'),
    );
  }
}

class _DayGroup extends StatelessWidget {
  final String day;
  final List<ClassSession> sessions;
  final bool isToday;
  const _DayGroup({
    required this.day,
    required this.sessions,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return RowGroup(
      title: day,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${sessions.length} class${sessions.length == 1 ? '' : 'es'}'),
          if (isToday) ...[
            const SizedBox(width: Spacing.sm),
            const StatusBadge('Today', tone: StatusTone.accent),
          ],
        ],
      ),
      children: [
        for (final s in sessions)
          ClassSessionRow(s, ongoing: isToday && isOngoing(s, now)),
      ],
    );
  }
}

/// One class session row — also used by the home "Today" card.
class ClassSessionRow extends StatelessWidget {
  final ClassSession s;
  final bool ongoing;
  const ClassSessionRow(this.s, {super.key, this.ongoing = false});

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: _sessionTitle(s),
      value: _sessionTime(s),
      chevron: false,
      trailing:
          ongoing ? const StatusBadge('Now', tone: StatusTone.success) : null,
    );
  }
}

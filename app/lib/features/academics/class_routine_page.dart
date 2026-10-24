import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/course_names.dart';
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

String? _section(ClassSession s) =>
    s.section != null && s.section!.isNotEmpty ? 'Section ${s.section}' : null;

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
        Reveal(index: 0, child: _NextClassPanel(routine)),
        Reveal(
          index: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _ExportButton(routine),
          ),
        ),
        ResponsiveGrid(
          maxColumns: 2,
          stretch: false,
          spacing: Spacing.xl,
          runSpacing: Spacing.xl,
          children: [
            for (final (i, day) in days.indexed)
              Reveal(
                index: i + 2,
                child: _DayGroup(
                  day: day,
                  sessions: byDay[day]!,
                  isToday: day == todayName,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The focal block: the next class (or the one in progress) with a live
/// HH:MM:SS countdown. Only the countdown pill listens to the per-second tick.
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
    final p = context.palette;
    return Panel(
      hue: Hue.lavender,
      radius: Radii.xl,
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 180),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -20,
              child: ExcludeSemantics(
                child: IdleSpin(
                  period: const Duration(seconds: 30),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: ShapeDecoration(
                      color: p.container(Hue.peach),
                      shape: const ExpressiveShapeBorder(
                          ExpressiveShapeKind.cookie),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 56,
              bottom: -14,
              child: ExcludeSemantics(
                child: IdleSpin(
                  period: const Duration(seconds: 20),
                  reverse: true,
                  bob: 3,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: ShapeDecoration(
                      color: p.container(Hue.sky),
                      shape: const ExpressiveShapeBorder(
                          ExpressiveShapeKind.clover),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, Spacing.xl, 96, Spacing.xl),
              child: _content(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final ongoing = widget.routine.where((s) => isOngoing(s, now)).toList();
    final next = nextClass(widget.routine, now);

    ClassSession? session;
    String kicker;
    DateTime? target;
    var live = false;
    if (ongoing.isNotEmpty) {
      session = ongoing.first;
      kicker = 'In class now';
      live = true;
      final end = parseClock(session.end);
      if (end != null) {
        target = DateTime(now.year, now.month, now.day, end.$1, end.$2);
      }
    } else if (next != null) {
      session = next.session;
      kicker = 'Next class · ${_dayLabel(next.start, now)}';
      target = next.start;
    } else {
      kicker = 'Class routine';
    }

    final titleStyle =
        context.text.headlineSmall?.copyWith(color: p.onContainer);
    final countdownTarget = target;
    final extra = session == null
        ? null
        : [
            if (_sessionTime(session) != null) _sessionTime(session)!,
            if (_section(session) != null) _section(session)!,
          ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live) ...[
              LiveDot(color: p.onContainer, size: 7),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Text(kicker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge
                      ?.copyWith(color: p.onContainer.withValues(alpha: 0.75))),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        if (session != null)
          CourseName(
            code: session.courseCode,
            extra: extra,
            color: p.onContainer,
            titleStyle: titleStyle,
            codeStyle: context.text.bodyMedium,
          )
        else
          Text('No upcoming classes', style: titleStyle),
        if (countdownTarget != null) ...[
          const SizedBox(height: Spacing.lg),
          ValueListenableBuilder<DateTime>(
            valueListenable: _now,
            builder: (context, t, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: p.ink,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.time, size: 16, color: p.onInk),
                    const SizedBox(width: 6),
                    Text(live ? 'Ends in ' : 'Starts in ',
                        style:
                            context.text.labelMedium?.copyWith(color: p.onInk)),
                    Text(_hms(countdownTarget.difference(t)),
                        style: context.text.labelLarge?.copyWith(
                            color: p.onInk,
                            fontWeight: FontWeight.w700,
                            fontFeatures: tabularFigures)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _dayLabel(DateTime when, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(when.year, when.month, when.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return _weekdayName(when.weekday);
  }

  /// "HH:MM:SS", or "Xd HH:MM:SS" when a day or more away.
  static String _hms(Duration d) {
    if (d.isNegative) d = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours % 24, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return d.inDays > 0
        ? '${d.inDays}d ${two(h)}:${two(m)}:${two(s)}'
        : '${two(d.inHours)}:${two(m)}:${two(s)}';
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

/// One class session row: course title (code and section below) with the time
/// on the right; a live "Now" marker while the class is in progress.
class ClassSessionRow extends StatelessWidget {
  final ClassSession s;
  final bool ongoing;
  const ClassSessionRow(this.s, {super.key, this.ongoing = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = context.scheme;
    final time = _sessionTime(s);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg + 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: CourseName(
                code: s.courseCode,
                extra: _section(s),
                titleStyle: context.text.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ongoing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LiveDot(color: p.successInk, size: 6),
                        Text('Now',
                            style: context.text.labelMedium?.copyWith(
                                color: p.successInk,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  if (time != null)
                    Text(time,
                        textAlign: TextAlign.right,
                        style: context.text.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: tabularFigures)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

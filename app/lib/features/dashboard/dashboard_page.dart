import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/avatar.dart';
import '../../shared/widgets.dart';
import '../academics/calendar_model.dart';
import '../academics/calendar_page.dart';
import '../academics/class_routine_page.dart';
import '../academics/routine_schedule.dart';
import '../auth/auth_controller.dart';
import '../finance/bill_page.dart';
import '../profile/profile_page.dart';
import 'attendance_page.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'home_model.dart';
import 'models.dart';
import 'notices_model.dart';
import 'results_page.dart';

/// Thousands separator, compiled once.
final _thousandsSep = RegExp(r'(\d)(?=(\d{3})+$)');

/// Strips non-dial characters from a phone number for a `tel:` link.
final _phoneClean = RegExp(r'[^0-9+]');

String _bdt(double? v) {
  if (v == null) return '—';
  final s = v
      .abs()
      .toStringAsFixed(0)
      .replaceAllMapped(_thousandsSep, (m) => '${m[1]},');
  return '৳ $s';
}

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _dayName(DateTime d) => _weekdays[d.weekday - 1];

/// Days from today (midnight) to [date]; negative when past.
int _daysUntil(DateTime date) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  return DateTime(date.year, date.month, date.day).difference(today).inDays;
}

String _relativeDay(int days) {
  if (days < 0) return 'Past';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}

String _until(Duration d) {
  if (d.inMinutes < 1) return 'starting now';
  if (d.inHours < 1) return 'in ${d.inMinutes} min';
  if (d.inDays < 1) {
    final m = d.inMinutes % 60;
    return 'in ${d.inHours}h${m > 0 ? ' ${m}m' : ''}';
  }
  return 'in ${d.inDays} day${d.inDays == 1 ? '' : 's'}';
}

/// Sessions for a weekday name, sorted by start time.
List<ClassSession> _sessionsOn(HomeSummary? home, String day) {
  final list = (home?.routine ?? const <ClassSession>[])
      .where((s) => s.day == day)
      .toList();
  int key(ClassSession s) {
    final c = parseClock(s.start);
    return c == null ? 9999 : c.$1 * 60 + c.$2;
  }
  return list..sort((a, b) => key(a).compareTo(key(b)));
}

const _classHues = [Hue.peach, Hue.sky, Hue.pink, Hue.mint, Hue.lemon, Hue.lavender];

/// Home: greeting, the next class as the focal block, this week's days, the
/// selected day's classes as colour cards, headline figures, payment, upcoming
/// dates, notices and the advisor.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _refreshing = false;
  late DateTime _selectedDay = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await Future.wait([
        ref.read(homeProvider.notifier).load(force: true),
        ref.read(noticesProvider.notifier).load(force: true),
        ref.read(resultsProvider.notifier).load(force: true),
        ref.read(attendanceProvider.notifier).load(force: true),
      ]);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final results = ref.watch(resultsProvider);
    final attendance = ref.watch(attendanceProvider);
    final auth = ref.watch(authControllerProvider);
    final roll = auth is AuthSignedIn && auth.roll.isNotEmpty ? auth.roll : null;

    // Centralized token-expiry handling: a 401 from ANY core provider means
    // our token died — log out once (logout() is idempotent).
    void onUnauthorized(ResourceState next) {
      if (next case ResError(unauthorized: true)) {
        ref
            .read(authControllerProvider.notifier)
            .logout(message: 'Your session ended. Please log in again.');
      }
    }

    ref.listen(resultsProvider, (_, next) => onUnauthorized(next));
    ref.listen(attendanceProvider, (_, next) => onUnauthorized(next));
    ref.listen(homeProvider, (_, next) => onUnauthorized(next));

    final homeData = home is ResData<HomeSummary> ? home.loaded.data : null;
    final r = results is ResData<ResultsData> ? results.loaded.data : null;
    final a =
        attendance is ResData<AttendanceData> ? attendance.loaded.data : null;

    final left = <Widget>[
      _NextClassHero(home: homeData),
      _DayStrip(
        home: homeData,
        selected: _selectedDay,
        onSelect: (d) => setState(() => _selectedDay = d),
      ),
      _ClassesForDay(home: homeData, day: _selectedDay),
    ];
    final right = <Widget>[
      _Figures(home: homeData, results: r, attendance: a),
      _PaymentSection(home: homeData),
      const _UpcomingSection(),
      const _NoticesSection(),
      if (homeData?.advisor?.name != null) _AdvisorSection(homeData!.advisor!),
    ];

    return PageScaffold(
      title: 'Home',
      showBack: false,
      titleWidget: _Header(home: homeData, roll: roll),
      actions: [
        CircleButton(
          icon: AppIcons.refresh,
          tooltip: 'Reload data',
          onPressed: _refreshing ? null : _refresh,
          child: _refreshing
              ? const ExpressiveLoader(size: 20)
              : null,
        ),
      ],
      onRefresh: _refresh,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (home case ResData<HomeSummary>(:final loaded, :final staleReason)
              when loaded.freshness == Freshness.cached)
            FreshnessLine(
              at: loaded.syncedAt,
              error: staleReason,
              onRetry: staleReason != null ? _refresh : null,
            ),
          if (Breakpoints.isExpanded(context))
            TwoColumn(
              ratio: 0.58,
              spacing: Spacing.xl,
              left: Stacked(children: left),
              right: Stacked(children: right),
            )
          else
            Stacked(children: [...left, ...right]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  final HomeSummary? home;
  final String? roll;
  const _Header({required this.home, required this.roll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(avatarProvider).value;
    final name = home?.name?.trim();
    final first =
        (name != null && name.isNotEmpty) ? name.split(' ').first : null;
    final now = DateTime.now();
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Profile and settings',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () =>
                Navigator.of(context).push(appRoute(const ProfilePage())),
            child: Avatar(bytes: avatar, radius: 22),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(first != null ? 'Hello, $first' : 'Hello',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge),
              Text('Today, ${now.day} ${_months[now.month - 1]}',
                  style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Next class hero
// ---------------------------------------------------------------------------

class _NextClassHero extends StatelessWidget {
  final HomeSummary? home;
  const _NextClassHero({required this.home});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final routine = home?.routine ?? const <ClassSession>[];
    final now = DateTime.now();
    final ongoing = routine.where((s) => isOngoing(s, now)).toList();
    final next = nextClass(routine, now);

    String kicker;
    String title;
    String? detail;
    String? badge;
    if (home == null) {
      kicker = 'Getting your day ready';
      title = 'Loading…';
    } else if (ongoing.isNotEmpty) {
      final s = ongoing.first;
      kicker = 'In class now';
      title = s.courseCode;
      detail = [
        if (s.start != null && s.end != null) '${s.start} – ${s.end}',
        if (s.section != null) 'Section ${s.section}',
      ].join(' · ');
      badge = 'Now';
    } else if (next != null) {
      final s = next.session;
      final d = _daysUntil(next.start);
      kicker = 'Next class · ${d == 0 ? 'Today' : d == 1 ? 'Tomorrow' : _dayName(next.start)}';
      title = s.courseCode;
      detail = [
        if (s.start != null && s.end != null) '${s.start} – ${s.end}',
        if (s.section != null) 'Section ${s.section}',
      ].join(' · ');
      badge = 'Starts ${_until(next.start.difference(now))}';
    } else {
      final term = home?.currentTerm?.name ?? home?.currentTerm?.code;
      kicker = 'This term';
      title = term ?? 'No classes scheduled';
      detail = home?.cgpa != null
          ? 'CGPA ${home!.cgpa!.toStringAsFixed(2)}'
          : null;
    }

    return Panel(
      hue: Hue.lavender,
      radius: Radii.xl,
      padding: EdgeInsets.zero,
      onTap: () =>
          Navigator.of(context).push(appRoute(const ClassRoutinePage())),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 188),
        child: Stack(
          children: [
            // Expressive shape cluster (brand peach + sky + white).
            Positioned(
              right: -18,
              top: 18,
              child: _ShapeCluster(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, Spacing.xl, 132, Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(kicker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(
                          color: p.onContainer.withValues(alpha: 0.75))),
                  const SizedBox(height: Spacing.xs),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineMedium
                          ?.copyWith(color: p.onContainer)),
                  if (detail != null && detail.isNotEmpty) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium
                            ?.copyWith(color: p.onContainer)),
                  ],
                  if (badge != null) ...[
                    const SizedBox(height: Spacing.lg),
                    StatusBadge(badge, onColored: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapeCluster extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: SizedBox(
        width: 156,
        height: 156,
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 104,
                height: 104,
                decoration: ShapeDecoration(
                  color: p.accent,
                  shape: const ExpressiveShapeBorder(ExpressiveShapeKind.cookie),
                ),
                child: Icon(AppIcons.course,
                    size: 40, color: p.onAccent),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                width: 64,
                height: 64,
                decoration: ShapeDecoration(
                  color: p.container(Hue.sky),
                  shape: const ExpressiveShapeBorder(ExpressiveShapeKind.clover,
                      rotation: 0.4),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week day strip
// ---------------------------------------------------------------------------

class _DayStrip extends StatelessWidget {
  final HomeSummary? home;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  const _DayStrip(
      {required this.home, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    // UIU weeks start on Saturday.
    final start = today.subtract(Duration(days: (today.weekday - 6) % 7));
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];

    return LayoutBuilder(builder: (context, c) {
      const gap = 6.0;
      final w = ((c.maxWidth - gap * 6) / 7).clamp(36.0, 72.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final d in days)
            _DayChip(
              width: w,
              label: _dayName(d).substring(0, 3),
              date: d.day,
              selected: d == selected,
              isToday: d == today,
              hasClasses: _sessionsOn(home, _dayName(d)).isNotEmpty,
              onTap: () => onSelect(d),
              ink: p.ink,
              onInk: p.onInk,
              surface: scheme.surface,
            ),
        ],
      );
    });
  }
}

class _DayChip extends StatelessWidget {
  final double width;
  final String label;
  final int date;
  final bool selected;
  final bool isToday;
  final bool hasClasses;
  final VoidCallback onTap;
  final Color ink, onInk, surface;
  const _DayChip({
    required this.width,
    required this.label,
    required this.date,
    required this.selected,
    required this.isToday,
    required this.hasClasses,
    required this.onTap,
    required this.ink,
    required this.onInk,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = selected ? onInk : scheme.onSurface;
    final sub = selected ? onInk.withValues(alpha: 0.75) : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $date${hasClasses ? ', has classes' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: Motion.fast,
          width: width,
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: selected ? ink : surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: isToday && !selected
                ? Border.all(color: ink, width: 1.5)
                : null,
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: hasClasses ? (selected ? onInk : ink) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: context.text.labelSmall?.copyWith(color: sub)),
                const SizedBox(height: 2),
                Text('$date',
                    style: context.text.titleMedium?.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Classes for the selected day (colour bento)
// ---------------------------------------------------------------------------

class _ClassesForDay extends StatelessWidget {
  final HomeSummary? home;
  final DateTime day;
  const _ClassesForDay({required this.home, required this.day});

  @override
  Widget build(BuildContext context) {
    final name = _dayName(day);
    final sessions = _sessionsOn(home, name);
    final isToday = _daysUntil(day) == 0;
    final now = DateTime.now();

    Widget card(int i, {required bool tall}) {
      final s = sessions[i];
      return _ClassCard(
        session: s,
        hue: _classHues[i % _classHues.length],
        tall: tall,
        live: isToday && isOngoing(s, now),
      );
    }

    Widget body;
    if (home == null) {
      body = const LoadingState(verticalPadding: Spacing.lg);
    } else if (sessions.isEmpty) {
      body = Panel(
        child: Row(
          children: [
            const ShapeIcon(AppIcons.today,
                hue: Hue.mint, shape: ExpressiveShapeKind.flower, size: 52),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No classes', style: context.text.titleMedium),
                  Text('Nothing scheduled on $name.',
                      style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (sessions.length == 1) {
      body = card(0, tall: false);
    } else if (sessions.length == 2) {
      body = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: card(0, tall: true)),
            const SizedBox(width: Spacing.md),
            Expanded(child: card(1, tall: true)),
          ],
        ),
      );
    } else {
      final rest = [for (var i = 3; i < sessions.length; i++) i];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card(0, tall: true)),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: card(1, tall: false)),
                      const SizedBox(height: Spacing.md),
                      Expanded(child: card(2, tall: false)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            ResponsiveGrid(
              columns: 2,
              spacing: Spacing.md,
              runSpacing: Spacing.md,
              children: [for (final i in rest) card(i, tall: false)],
            ),
          ],
        ],
      );
    }

    return Section(
      title: isToday ? 'Your classes today' : 'Classes on $name',
      trailing: TextButton(
        onPressed: () =>
            Navigator.of(context).push(appRoute(const ClassRoutinePage())),
        child: const Text('Routine'),
      ),
      child: body,
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassSession session;
  final Hue hue;
  final bool tall;
  final bool live;
  const _ClassCard({
    required this.session,
    required this.hue,
    required this.tall,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = session;
    final time =
        s.start != null && s.end != null ? '${s.start}\n${s.end}' : null;
    return Panel(
      hue: hue,
      radius: Radii.lg,
      padding: const EdgeInsets.all(Spacing.lg + 2),
      onTap: () =>
          Navigator.of(context).push(appRoute(const ClassRoutinePage())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: tall ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: [
              if (s.section != null)
                StatusBadge('Sec ${s.section}', onColored: true),
              if (live) const StatusBadge('Now', onColored: true),
            ],
          ),
          SizedBox(height: tall ? Spacing.lg : Spacing.md),
          Text(s.courseCode,
              maxLines: tall ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: (tall ? context.text.titleLarge : context.text.titleMedium)
                  ?.copyWith(color: p.onContainer)),
          if (tall) const Spacer() else const SizedBox(height: Spacing.sm),
          if (time != null)
            Text(time,
                style: context.text.bodyMedium?.copyWith(
                    color: p.onContainer, fontFeatures: tabularFigures)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Headline figures
// ---------------------------------------------------------------------------

class _Figures extends StatelessWidget {
  final HomeSummary? home;
  final ResultsData? results;
  final AttendanceData? attendance;
  const _Figures({
    required this.home,
    required this.results,
    required this.attendance,
  });

  @override
  Widget build(BuildContext context) {
    final r = results;
    final cgpa = home?.cgpa ??
        r?.latestCgpa ??
        (r != null && r.semesters.isNotEmpty ? r.semesters.first.cgpa : null);
    final att = attendance != null ? overallAttendancePct(attendance!) : null;
    final credits = home?.completedCredits;

    void go(Widget page) => Navigator.of(context).push(appRoute(page));

    return Section(
      title: 'At a glance',
      child: StatStrip(items: [
        StatBlock(
          label: 'CGPA',
          value: cgpa?.toStringAsFixed(2) ?? '—',
          hue: Hue.mint,
          onTap: () => go(const ResultsPage()),
        ),
        StatBlock(
          label: 'Attendance',
          value: att != null ? '${att.toStringAsFixed(0)}%' : '—',
          hue: att != null && att < 70 ? Hue.rose : Hue.sky,
          onTap: () => go(const AttendancePage()),
        ),
        StatBlock(
          label: 'Credits',
          value: credits?.toStringAsFixed(0) ?? '—',
          hue: Hue.peach,
          onTap: () => go(const ResultsPage()),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

class _PaymentSection extends ConsumerWidget {
  final HomeSummary? home;
  const _PaymentSection({required this.home});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final hasDue = home?.hasDue ?? false;
    final cal =
        ref.watch(academicCalendarProvider).asData?.value.defaultCalendar;
    final next = cal?.activeInstallment;
    final days = next != null ? _daysUntil(next.deadline) : null;
    final deadlineSoon = days != null && days <= 14;

    void openBill() =>
        Navigator.of(context).push(appRoute(const BillPage()));

    if (home == null) return const SizedBox.shrink();

    if (!hasDue && !deadlineSoon) {
      return RowGroup(
        children: [
          ListRow(
            icon: AppIcons.dues,
            hue: Hue.mint,
            title: 'No dues',
            subtitle: next != null
                ? '${next.ordinalLabel} installment due ${next.dateText}'
                : 'Your tuition account is clear',
            onTap: openBill,
          ),
        ],
      );
    }

    final badge = days == null
        ? null
        : days < 0
            ? 'Overdue'
            : days == 0
                ? 'Due today'
                : 'Due in $days day${days == 1 ? '' : 's'}';

    return Panel(
      hue: days != null && days < 0 ? Hue.rose : Hue.lemon,
      radius: Radii.xl,
      onTap: openBill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Payment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium
                        ?.copyWith(color: p.onContainer)),
              ),
              if (badge != null)
                Flexible(child: StatusBadge(badge, onColored: true)),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(hasDue ? 'Amount due' : 'Next installment',
              style: context.text.labelMedium?.copyWith(
                  color: p.onContainer.withValues(alpha: 0.75))),
          Text(hasDue ? _bdt(home!.dueAmount) : (next?.dateText ?? '—'),
              style: context.text.headlineMedium?.copyWith(
                  color: p.onContainer, fontFeatures: tabularFigures)),
          if (next != null && hasDue) ...[
            const SizedBox(height: Spacing.xs),
            Text('${next.ordinalLabel} installment · ${next.dateText}',
                style:
                    context.text.bodySmall?.copyWith(color: p.onContainer)),
          ],
          const SizedBox(height: Spacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.ink,
              foregroundColor: p.onInk,
              minimumSize: const Size(0, 44),
            ),
            onPressed: openBill,
            child: const Text('View bill'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming academic-calendar events
// ---------------------------------------------------------------------------

Hue _eventHue(CalendarEventType t) => switch (t) {
      CalendarEventType.exam => Hue.rose,
      CalendarEventType.payment => Hue.lemon,
      CalendarEventType.holiday => Hue.mint,
      CalendarEventType.registration => Hue.peach,
      CalendarEventType.classDay => Hue.sky,
      CalendarEventType.other => Hue.lavender,
    };

class DateTile extends StatelessWidget {
  final DateTime date;
  final Hue hue;
  const DateTile({super.key, required this.date, required this.hue});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 48,
      height: 52,
      decoration: BoxDecoration(
        color: p.container(hue),
        borderRadius: BorderRadius.circular(Radii.sm + 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${date.day}',
              style: context.text.titleMedium
                  ?.copyWith(color: p.onContainer, height: 1.05)),
          Text(_months[date.month - 1],
              style: context.text.labelSmall?.copyWith(color: p.onContainer)),
        ],
      ),
    );
  }
}

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(academicCalendarProvider);
    final cal = async.asData?.value.defaultCalendar;
    final events = cal?.nextEvents(3) ?? const <CalendarEvent>[];

    void openCalendar() =>
        Navigator.of(context).push(appRoute(const CalendarPage()));

    final Widget body;
    if (async.isLoading) {
      body = const LoadingState(verticalPadding: Spacing.lg);
    } else if (async.hasError) {
      body = const InfoNote(
          icon: AppIcons.offline,
          text: 'Couldn’t load the academic calendar.');
    } else if (events.isEmpty) {
      body = const InfoNote(text: 'No upcoming events.');
    } else {
      body = RowGroup(
        children: [
          for (final e in events)
            ListRow(
              leading: DateTile(date: e.date, hue: _eventHue(e.type)),
              title: e.title,
              subtitle: _relativeDay(_daysUntil(e.date)),
              onTap: openCalendar,
            ),
        ],
      );
    }

    return Section(
      title: 'Upcoming',
      trailing:
          TextButton(onPressed: openCalendar, child: const Text('Calendar')),
      child: body,
    );
  }
}

// ---------------------------------------------------------------------------
// Notices (UCAM student notices)
// ---------------------------------------------------------------------------

class _NoticesSection extends ConsumerWidget {
  const _NoticesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticesProvider);
    if (state is ResLoading<NoticesData>) {
      return const Section(
          title: 'Notices', child: LoadingState(verticalPadding: Spacing.lg));
    }
    final notices = state is ResData<NoticesData>
        ? state.loaded.data.notices
        : const <Notice>[];
    if (notices.isEmpty) return const SizedBox.shrink();

    return Section(
      title: 'Notices',
      child: RowGroup(
        children: [
          for (final n in notices.take(4))
            ListRow(
              icon: AppIcons.notices,
              hue: Hue.lavender,
              title: n.title ?? 'Notice',
              subtitle: [n.postedBy ?? '', n.when]
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              chevron: false,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Academic advisor
// ---------------------------------------------------------------------------

class _AdvisorSection extends StatelessWidget {
  final Advisor advisor;
  const _AdvisorSection(this.advisor);

  Future<void> _email(BuildContext context, String address) async {
    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query: 'subject=${Uri.encodeComponent('Advising')}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open your email app.')),
      );
    }
  }

  Future<void> _call(BuildContext context, String number) async {
    final cleaned = number.replaceAll(_phoneClean, '');
    final ok = await launchUrl(Uri(scheme: 'tel', path: cleaned),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open the phone app.')),
      );
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = context.scheme;
    final email = advisor.email;
    final phone = advisor.phone;
    final hasEmail = email != null && email.isNotEmpty;
    final hasPhone = phone != null && phone.isNotEmpty;
    final room = advisor.room;
    return Section(
      title: 'Academic advisor',
      child: RowGroup(
        children: [
          ListRow(
            leading: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: p.container(Hue.aqua),
                shape: const ExpressiveShapeBorder(ExpressiveShapeKind.cookie),
              ),
              child: Text(advisor.initial ?? _initials(advisor.name!),
                  style: context.text.labelLarge?.copyWith(
                      color: p.onContainer, fontWeight: FontWeight.w700)),
            ),
            title: advisor.name!,
            subtitle: room != null && room.isNotEmpty ? 'Room $room' : null,
            chevron: false,
            trailing: (hasEmail || hasPhone)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasEmail)
                        CircleButton(
                          icon: AppIcons.email,
                          tooltip: 'Email $email',
                          color: scheme.surfaceContainer,
                          onPressed: () => _email(context, email),
                        ),
                      if (hasEmail && hasPhone)
                        const SizedBox(width: Spacing.sm),
                      if (hasPhone)
                        CircleButton(
                          icon: AppIcons.phone,
                          tooltip: 'Call $phone',
                          color: scheme.surfaceContainer,
                          onPressed: () => _call(context, phone),
                        ),
                    ],
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

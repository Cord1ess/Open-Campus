import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/brand_logo.dart';
import '../../shared/widgets.dart';
import '../academics/calendar_model.dart';
import '../academics/calendar_page.dart';
import '../academics/class_routine_page.dart';
import '../auth/auth_controller.dart';
import '../finance/bill_page.dart';
import '../profile/profile_button.dart';
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

/// "Monday, 30 June 2026" — formatted without the intl package.
String _formatToday(DateTime d) {
  const days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

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

/// Home: a short greeting, then the day's time-sensitive items (classes,
/// payment, upcoming dates), the headline figures, notices and the advisor.
/// Detail lives on the full pages; the home page only summarises and links.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _refreshing = false;

  // Pull-to-refresh / reload always bypass the freshness throttle.
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
      _TodaySection(home: homeData),
      _PaymentSection(home: homeData),
      const _UpcomingSection(),
    ];
    final right = <Widget>[
      _Figures(home: homeData, results: r, attendance: a),
      const _NoticesSection(),
      if (homeData?.advisor?.name != null) _AdvisorSection(homeData!.advisor!),
    ];

    return PageScaffold(
      title: 'Open Campus',
      showBack: false,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandIcon(size: 22),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Text('Open Campus',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge),
          ),
        ],
      ),
      actions: [
        _refreshing
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 13),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                onPressed: _refresh,
                tooltip: 'Reload data',
                icon: const Icon(AppIcons.refresh),
              ),
        const ProfileButton(),
      ],
      onRefresh: _refresh,
      body: Stacked(
        children: [
          _Greeting(home: home, roll: roll, onRetry: _refresh),
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

class _Greeting extends StatelessWidget {
  final ResourceState<HomeSummary> home;
  final String? roll;
  final VoidCallback onRetry;
  const _Greeting({required this.home, required this.roll, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final data = home is ResData<HomeSummary>
        ? (home as ResData<HomeSummary>).loaded.data
        : null;
    final name = data?.name?.trim();
    final hasName = name != null && name.isNotEmpty;
    final greeting = hasName ? 'Welcome back, ${name.split(' ').first}' : 'Welcome';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (home case ResData<HomeSummary>(:final loaded, :final staleReason)
            when loaded.freshness == Freshness.cached)
          FreshnessLine(
            at: loaded.syncedAt,
            error: staleReason,
            onRetry: staleReason != null ? onRetry : null,
          ),
        Text(greeting, style: context.text.titleMedium),
        const SizedBox(height: Spacing.xxs),
        Text(_formatToday(DateTime.now()), style: context.text.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Today's classes
// ---------------------------------------------------------------------------

const _dayNames = {
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
};

class _TodaySection extends StatelessWidget {
  final HomeSummary? home;
  const _TodaySection({required this.home});

  @override
  Widget build(BuildContext context) {
    final today = _dayNames[DateTime.now().weekday];
    final sessions = (home?.routine ?? const <ClassSession>[])
        .where((s) => s.day == today)
        .toList();

    return Section(
      title: 'Today',
      trailing: TextButton(
        onPressed: () =>
            Navigator.of(context).push(appRoute(const ClassRoutinePage())),
        child: const Text('Show routine'),
      ),
      child: home == null
          ? const LoadingState(verticalPadding: Spacing.lg)
          : sessions.isEmpty
              ? const Panel(
                  padding: EdgeInsets.zero,
                  child: EmptyState(
                    icon: AppIcons.today,
                    title: 'No classes today',
                    compact: true,
                  ),
                )
              : RowGroup(
                  children: [
                    for (final s in sessions)
                      ListRow(
                        icon: AppIcons.course,
                        title:
                            '${s.courseCode}${s.section != null ? ' · ${s.section}' : ''}',
                        value: s.start != null && s.end != null
                            ? '${s.start} – ${s.end}'
                            : null,
                        chevron: false,
                      ),
                  ],
                ),
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
            title: 'Tuition: no dues',
            subtitle: next != null
                ? '${next.ordinalLabel} installment due ${next.dateText}'
                : null,
            onTap: openBill,
          ),
        ],
      );
    }

    final tone = days == null
        ? StatusTone.neutral
        : days < 0
            ? StatusTone.danger
            : days <= 7
                ? StatusTone.warning
                : StatusTone.neutral;
    final badge = days == null
        ? null
        : days < 0
            ? 'Overdue'
            : days == 0
                ? 'Due today'
                : 'Due in $days day${days == 1 ? '' : 's'}';

    return Section(
      title: 'Payment',
      trailing: TextButton(onPressed: openBill, child: const Text('View bill')),
      child: Panel(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.sm),
        onTap: openBill,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyValueRow(
              label: 'Amount due',
              value: hasDue ? _bdt(home!.dueAmount) : 'No dues',
              emphasize: true,
              valueColor: hasDue ? p.warningInk : p.successInk,
            ),
            if (next != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${next.ordinalLabel} installment',
                              style: context.text.bodyMedium?.copyWith(
                                  color: context.scheme.onSurfaceVariant)),
                          Text(next.dateText, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    if (badge != null) StatusBadge(badge, tone: tone),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming academic-calendar events
// ---------------------------------------------------------------------------

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
      body = Text('Couldn’t load the academic calendar.',
          style: context.text.bodySmall);
    } else if (events.isEmpty) {
      body = Text('No upcoming events.', style: context.text.bodySmall);
    } else {
      body = RowGroup(
        children: [
          for (final e in events)
            ListRow(
              icon: e.icon,
              title: e.title,
              subtitle: e.dateText,
              value: _relativeDay(_daysUntil(e.date)),
              onTap: openCalendar,
              chevron: false,
            ),
        ],
      );
    }

    return Section(
      title: 'Upcoming',
      trailing: TextButton(
          onPressed: openCalendar, child: const Text('Show calendar')),
      child: body,
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

    return StatStrip(items: [
      StatBlock(
        label: 'CGPA',
        value: cgpa?.toStringAsFixed(2) ?? '—',
        onTap: () => go(const ResultsPage()),
      ),
      StatBlock(
        label: 'Credits',
        value: credits?.toStringAsFixed(0) ?? '—',
        onTap: () => go(const ResultsPage()),
      ),
      StatBlock(
        label: 'Attendance',
        value: att != null ? '${att.toStringAsFixed(0)}%' : '—',
        onTap: () => go(const AttendancePage()),
      ),
    ]);
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
          title: 'Notices',
          child: LoadingState(verticalPadding: Spacing.lg));
    }
    final notices = state is ResData<NoticesData>
        ? state.loaded.data.notices
        : const <Notice>[];
    if (notices.isEmpty) return const SizedBox.shrink();

    final shown = notices.take(4).toList();
    return Section(
      title: 'Notices',
      child: RowGroup(
        children: [
          for (final n in shown)
            ListRow(
              icon: AppIcons.notices,
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

  @override
  Widget build(BuildContext context) {
    final email = advisor.email;
    final phone = advisor.phone;
    final hasEmail = email != null && email.isNotEmpty;
    final hasPhone = phone != null && phone.isNotEmpty;
    final room = advisor.room;
    return RowGroup(
      title: 'Academic advisor',
      children: [
        ListRow(
          icon: AppIcons.advisor,
          title: advisor.name!,
          subtitle: room != null && room.isNotEmpty ? 'Room $room' : null,
          chevron: false,
          trailing: (hasEmail || hasPhone)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasEmail)
                      IconButton(
                        tooltip: 'Email $email',
                        onPressed: () => _email(context, email),
                        icon: const Icon(AppIcons.email, size: 20),
                      ),
                    if (hasPhone)
                      IconButton(
                        tooltip: 'Call $phone',
                        onPressed: () => _call(context, phone),
                        icon: const Icon(AppIcons.phone, size: 20),
                      ),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}

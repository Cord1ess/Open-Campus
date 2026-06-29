import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/avatar.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../academics/calendar_model.dart';
import '../academics/calendar_page.dart';
import '../academics/class_routine_page.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_page.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'home_model.dart';
import 'models.dart';
import 'notices_model.dart';
import 'resource_view.dart';

/// Home / overview page: greeting + quick stats hero, then result & attendance
/// summary cards.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> _refresh(WidgetRef ref) => Future.wait([
        ref.read(homeProvider.notifier).load(),
        ref.read(noticesProvider.notifier).load(),
        ref.read(resultsProvider.notifier).load(),
        ref.read(attendanceProvider.notifier).load(),
      ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final results = ref.watch(resultsProvider);
    final attendance = ref.watch(attendanceProvider);
    final auth = ref.watch(authControllerProvider);
    final roll = auth is AuthSignedIn && auth.roll.isNotEmpty ? auth.roll : null;

    final homeData =
        home is ResData<HomeSummary> ? home.loaded.data : null;
    final avatarBytes = ref.watch(avatarProvider).value;

    ref.listen(resultsProvider, (_, next) {
      if (next case ResError(unauthorized: true)) {
        ref
            .read(authControllerProvider.notifier)
            .logout(message: 'Your session ended. Please log in again.');
      }
    });

    final expired = (results is ResData<ResultsData> && results.sessionExpired) ||
        (attendance is ResData<AttendanceData> && attendance.sessionExpired);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            // Sticky header: logo + reload + profile. Stays pinned on scroll.
            _StickyHeaderBar(
              avatarBytes: avatarBytes,
              onProfile: () => Navigator.of(context)
                  .push(sharedAxisRoute(const ProfilePage())),
              onReload: () => _refresh(ref),
            ),
            SliverToBoxAdapter(
              child: _Hero(
                roll: roll,
                home: homeData,
                results: results,
                attendance: attendance,
              ),
            ),
            if (expired)
              SliverToBoxAdapter(
                child: ReloginBanner(
                  onRelogin: () => ref
                      .read(authControllerProvider.notifier)
                      .logout(message: 'Please log in again for live data.'),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                _DashboardBody(
                  home: homeData,
                  results: results,
                  attendance: attendance,
                  onRetryResults: () =>
                      ref.read(resultsProvider.notifier).load(),
                  onRetryAttendance: () =>
                      ref.read(attendanceProvider.notifier).load(),
                ),
                const SizedBox(height: Spacing.xl),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 13,
                          color: context.scheme.onSurfaceVariant
                              .withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Live from UCAM · nothing stored on our servers',
                          textAlign: TextAlign.center,
                          style: context.text.labelSmall?.copyWith(
                              color: context.scheme.onSurfaceVariant
                                  .withValues(alpha: 0.85)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 96), // clear the floating nav bar
              ]),
            ),
          ],
        ),
      ),
    );
  }
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

/// The semester card's big title — prefer the human name ("Spring 2026"); fall
/// back to the code, then a dash.
String _termTitle(Term? t) {
  final name = t?.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  final code = t?.code?.trim();
  if (code != null && code.isNotEmpty) return code;
  return '—';
}

/// The sticky top bar (logo + reload + profile) pinned above the dashboard.
/// Built on a pinned SliverAppBar so height/clipping are handled correctly
/// (a hand-rolled SliverPersistentHeader delegate is error-prone to size).
class _StickyHeaderBar extends StatelessWidget {
  final List<int>? avatarBytes;
  final VoidCallback onProfile;
  final Future<void> Function() onReload;
  const _StickyHeaderBar({
    required this.avatarBytes,
    required this.onProfile,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SliverAppBar(
      pinned: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: Spacing.lg,
      toolbarHeight: 64,
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child:
                Icon(Icons.school_rounded, size: 18, color: scheme.onPrimary),
          ),
          const SizedBox(width: Spacing.sm),
          Text('Open Campus',
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const Spacer(),
          _ReloadButton(onReload: onReload),
          const SizedBox(width: Spacing.sm),
          SpringTap(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(999),
            child: Avatar(bytes: avatarBytes, radius: 22),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String? roll;
  final HomeSummary? home;
  final ResourceState<ResultsData> results;
  final ResourceState<AttendanceData> attendance;

  const _Hero({
    required this.roll,
    required this.home,
    required this.results,
    required this.attendance,
  });

  ResultsData? get _r => results is ResData<ResultsData>
      ? (results as ResData<ResultsData>).loaded.data
      : null;
  AttendanceData? get _a => attendance is ResData<AttendanceData>
      ? (attendance as ResData<AttendanceData>).loaded.data
      : null;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final r = _r;
    final a = _a;
    // Prefer the live home summary's CGPA; fall back to results.
    final cgpa = home?.cgpa ??
        r?.latestCgpa ??
        (r != null && r.semesters.isNotEmpty ? r.semesters.first.cgpa : null);
    final att = a != null ? overallAttendancePct(a) : null;
    final attended = a != null ? attendedClasses(a) : null;
    final totalCls = a != null ? totalClasses(a) : null;
    final credits = home?.completedCredits;
    final currentTerm = home?.currentTerm;
    final nextTerm = home?.nextTerms.isNotEmpty == true
        ? home!.nextTerms.first
        : null;

    // Real name from /student/home; greeting falls back gracefully while
    // loading or if the backend sends an empty name (treat blank as absent).
    final realName = home?.name?.trim();
    final hasName = realName != null && realName.isNotEmpty;
    final firstName =
        hasName ? realName.split(' ').first : (roll != null ? 'Student' : 'Welcome');

    return Container(
      color: scheme.surface,
      // The sticky header occupies the top; start the greeting just below it.
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hasName ? 'Welcome back,' : 'Welcome',
              style: context.text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          Text(firstName,
              style: context.text.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          // Today's date in the accent color (blue on the default theme).
          Text(_formatToday(DateTime.now()),
              style: context.text.titleSmall?.copyWith(
                  color: scheme.secondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: Spacing.xl),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card 1 — current semester (filled blue).
                Expanded(
                  child: _HeroCard(
                    icon: Icons.calendar_today_rounded,
                    caption: 'Current term',
                    bigValue: _termTitle(currentTerm),
                    subLabel: 'Next',
                    subValue: nextTerm?.code ?? nextTerm?.name ?? '—',
                    filled: true,
                    accent: scheme.secondary,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                // Card 2 — CGPA (filled orange).
                Expanded(
                  child: _HeroCard(
                    icon: Icons.workspace_premium,
                    caption: 'CGPA',
                    bigValue: cgpa?.toStringAsFixed(2) ?? '—',
                    subLabel: 'Credits',
                    subValue: credits?.toStringAsFixed(0) ?? '—',
                    filled: true,
                    accent: scheme.primary,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                // Card 3 — attendance (clean white card).
                Expanded(
                  child: _HeroCard(
                    icon: Icons.event_available,
                    caption: 'Attendance',
                    bigValue:
                        att != null ? '${att.toStringAsFixed(0)}%' : '—',
                    subLabel: 'Classes',
                    subValue: (attended != null && totalCls != null)
                        ? '$attended/$totalCls'
                        : '—',
                    filled: false,
                    accent: scheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular reload button beside the profile avatar. Spins while a refresh is
/// in flight and is disabled meanwhile, so a tap can't stack duplicate fetches.
/// Read-only — it only re-pulls the same data the page already shows.
class _ReloadButton extends StatefulWidget {
  final Future<void> Function() onReload;
  const _ReloadButton({required this.onReload});

  @override
  State<_ReloadButton> createState() => _ReloadButtonState();
}

class _ReloadButtonState extends State<_ReloadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));
  bool _busy = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    setState(() => _busy = true);
    _spin.repeat();
    HapticFeedback.lightImpact();
    try {
      await widget.onReload();
    } finally {
      if (mounted) {
        _spin.stop();
        _spin.animateTo(_spin.value.ceilToDouble(),
            duration: const Duration(milliseconds: 200));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Tooltip(
      message: 'Reload data',
      child: SpringTap(
        onTap: _busy ? null : _go,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: RotationTransition(
            turns: _spin,
            child: Icon(Icons.refresh_rounded,
                size: 20, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// The scrollable card stack below the hero. On phones it's a single staggered
/// column (original order); on wide screens it splits into two balanced columns
/// so the dashboard fills desktop width instead of running as one long strip.
class _DashboardBody extends StatelessWidget {
  final HomeSummary? home;
  final ResourceState<ResultsData> results;
  final ResourceState<AttendanceData> attendance;
  final VoidCallback onRetryResults;
  final VoidCallback onRetryAttendance;
  const _DashboardBody({
    required this.home,
    required this.results,
    required this.attendance,
    required this.onRetryResults,
    required this.onRetryAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final today = _TodayCard(home: home);
    final payment = _PaymentCard(home: home);
    final advisor = _AdvisorCard(home: home);
    const notices = _NoticesCard();
    final resultsCard = ResourceSection<ResultsData>(
      title: 'Results',
      icon: Icons.school_outlined,
      state: results,
      loadingSkeleton: const CardSkeleton(chart: true),
      builder: (d) => ResultsContent(d),
      onRetry: onRetryResults,
    );
    final attendanceCard = ResourceSection<AttendanceData>(
      title: 'Attendance',
      icon: Icons.event_available_outlined,
      state: attendance,
      loadingSkeleton: const CardSkeleton(lines: 4),
      builder: (d) => AttendanceContent(d),
      onRetry: onRetryAttendance,
    );

    final body = Breakpoints.isDesktop(context)
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _StaggerColumn(
                      children: [today, payment, resultsCard])),
              const SizedBox(width: Spacing.lg),
              Expanded(
                  child: _StaggerColumn(
                      baseDelay: 60,
                      children: [notices, advisor, attendanceCard])),
            ],
          )
        : _StaggerColumn(children: [
            today,
            payment,
            advisor,
            notices,
            resultsCard,
            attendanceCard,
          ]);

    // Upcoming spans full width, above the rest of the dashboard cards.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FadeSlideIn(child: _UpcomingCard()),
        const SizedBox(height: Spacing.lg),
        body,
      ],
    );
  }
}

/// Wide "Upcoming" card: shows the next academic-calendar event computed from
/// today's date, and links to the full calendar.
class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final async = ref.watch(academicCalendarProvider);

    void openCalendar() => Navigator.of(context)
        .push(sharedAxisRoute(const CalendarPage()));

    final cal = async.asData?.value.defaultCalendar;
    final next = cal?.nextEvent;

    return SpringTap(
      onTap: openCalendar,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Text('Upcoming', style: context.text.titleMedium),
                const Spacer(),
                if (cal != null)
                  Text(cal.term,
                      style: context.text.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            if (async.isLoading)
              const CardSkeleton(lines: 2)
            else if (next != null)
              _UpcomingEvent(next)
            else
              Text(
                async.hasError
                    ? 'Couldn\'t load the academic calendar.'
                    : 'No upcoming events.',
                style: context.text.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Text('Show academic calendar',
                    style: context.text.labelLarge?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right, size: 20, color: scheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingEvent extends StatelessWidget {
  final CalendarEvent e;
  const _UpcomingEvent(this.e);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final n = DateTime.now();
    final days = e.date.difference(DateTime(n.year, n.month, n.day)).inDays;
    final when = days <= 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : 'In $days days';

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.secondary,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(e.icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${e.dateText}  ·  $when',
                  style: context.text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaggerColumn extends StatelessWidget {
  final List<Widget> children;
  final int baseDelay;
  const _StaggerColumn({required this.children, this.baseDelay = 0});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: baseDelay + i * 70,
            child: children[i],
          ),
        ],
      ],
    );
  }
}

/// A hero stat card with a big title (+ optional big value) and a small
/// subtitle line (label : value). [filled] = solid accent background with white
/// text; otherwise a clean white card with a hairline border and accent chips.
/// A uniform hero stat card. Every card has the same vertical rhythm — an icon
/// chip up top, a big focal area in the middle (either [bigValue] text or a
/// custom [center] widget like a ring), and a small caption line at the bottom
/// — so the three sit balanced side by side.
class _HeroCard extends StatelessWidget {
  final IconData icon;
  final String caption; // small top label, e.g. "Current term" / "CGPA"
  final String? bigValue; // big focal text (term name / CGPA / attendance %)
  final String subLabel;
  final String subValue;
  final bool filled;
  final Color accent;
  const _HeroCard({
    required this.icon,
    required this.caption,
    required this.subLabel,
    required this.subValue,
    required this.filled,
    required this.accent,
    this.bigValue,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = filled ? accent : scheme.surface;
    final fg = filled ? Colors.white : scheme.onSurface;
    final dim = filled
        ? Colors.white.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = filled ? Colors.white.withValues(alpha: 0.20) : accent;

    return SpringTap(
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: filled ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top: icon chip + caption.
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration:
                      BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, size: 14, color: Colors.white),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                          color: dim, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            // Big focal value, left-aligned.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(bigValue ?? '—',
                  maxLines: 1,
                  style: context.text.headlineSmall?.copyWith(
                      color: fg, fontWeight: FontWeight.w800, height: 1.05)),
            ),
            const SizedBox(height: Spacing.sm),
            // Bottom: small caption line.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('$subLabel: $subValue',
                  maxLines: 1,
                  style: context.text.labelSmall?.copyWith(
                      color: dim, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wide payment card: total paid + balance/due side by side. Real data from
/// /student/home (negative UCAM balance = advance, so no due).
class _PaymentCard extends StatelessWidget {
  final HomeSummary? home;
  const _PaymentCard({this.home});

  String _bdt(double? v) {
    if (v == null) return '—';
    final n = v.abs();
    // Group thousands with commas.
    final s = n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '৳ $s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final paid = home?.totalPaid;
    final due = home?.dueAmount ?? 0;
    final hasDue = home?.hasDue ?? false;

    return SpringTap(
      child: Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 20, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Text('Payment', style: context.text.titleMedium),
                const Spacer(),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: _BalanceTile(
                    label: 'Total Paid',
                    value: _bdt(paid),
                    color: scheme.onSurface,
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: scheme.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                ),
                Expanded(
                  child: _BalanceTile(
                    label: hasDue ? 'Due' : 'Balance',
                    value: hasDue ? _bdt(due) : 'Clear',
                    color: hasDue ? context.status.bad : context.status.good,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BalanceTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.text.labelMedium
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: context.text.titleLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

/// Today's classes, pulled from the home routine. Hidden if there are none.
class _TodayCard extends StatelessWidget {
  final HomeSummary? home;
  const _TodayCard({this.home});

  static const _names = {
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
  };

  @override
  Widget build(BuildContext context) {
    final routine = home?.routine ?? const [];
    final today = _names[DateTime.now().weekday];
    final todays = routine.where((s) => s.day == today).toList();

    return SectionCard(
      title: 'Today’s classes',
      icon: Icons.today_outlined,
      trailing: SpringTap(
        onTap: () => Navigator.of(context)
            .push(sharedAxisRoute(const ClassRoutinePage())),
        borderRadius: BorderRadius.circular(999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Full routine',
                style: context.text.labelMedium?.copyWith(
                    color: context.scheme.primary,
                    fontWeight: FontWeight.w700)),
            Icon(Icons.chevron_right, size: 18, color: context.scheme.primary),
          ],
        ),
      ),
      child: todays.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Row(
                children: [
                  Icon(Icons.free_breakfast_outlined,
                      size: 18, color: context.scheme.onSurfaceVariant),
                  const SizedBox(width: Spacing.sm),
                  Text('No classes today',
                      style: context.text.bodyMedium
                          ?.copyWith(color: context.scheme.onSurfaceVariant)),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < todays.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: Spacing.lg,
                        color: context.scheme.outlineVariant),
                  ClassSessionRow(todays[i]),
                ],
              ],
            ),
    );
  }
}

/// Academic advisor contact card, from the home summary.
class _AdvisorCard extends StatelessWidget {
  final HomeSummary? home;
  const _AdvisorCard({this.home});

  @override
  Widget build(BuildContext context) {
    final advisor = home?.advisor;
    if (advisor == null || advisor.name == null) {
      return const SizedBox.shrink();
    }
    final scheme = context.scheme;
    return SectionCard(
      title: 'Academic advisor',
      icon: Icons.support_agent_outlined,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.secondaryContainer,
            child: Text(
              advisor.initial ?? '?',
              style: context.text.titleMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(advisor.name!,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (advisor.room != null)
                  Text('Room ${advisor.room}',
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                if (advisor.email != null)
                  Text(advisor.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent notices preview — real data from /student/notices. Hidden if empty.
class _NoticesCard extends ConsumerWidget {
  const _NoticesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final state = ref.watch(noticesProvider);
    final notices = state is ResData<NoticesData>
        ? state.loaded.data.notices
        : const <Notice>[];

    // While loading, show a slim skeleton; if there are genuinely no notices,
    // hide the card entirely rather than show an empty box.
    if (state is ResLoading) {
      return const SectionCard(
        title: 'Notices',
        icon: Icons.campaign_outlined,
        child: CardSkeleton(lines: 3),
      );
    }
    if (notices.isEmpty) return const SizedBox.shrink();

    final shown = notices.take(4).toList();
    return SectionCard(
      title: 'Notices',
      icon: Icons.campaign_outlined,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, right: Spacing.md),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shown[i].title ?? 'Notice',
                          style: context.text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                          [shown[i].postedBy ?? '', shown[i].when]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: context.text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

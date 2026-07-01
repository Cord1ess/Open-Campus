import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/avatar.dart';
import '../../shared/brand_logo.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../academics/calendar_model.dart';
import '../academics/calendar_page.dart';
import '../academics/class_routine_page.dart';
import '../auth/auth_controller.dart';
import '../finance/bill_page.dart';
import '../profile/profile_page.dart';
import 'attendance_page.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'home_model.dart';
import 'models.dart';
import 'notices_model.dart';
import 'resource_view.dart';
import 'results_page.dart';

part 'dashboard_cards.dart';

/// Thousands separator, compiled once and reused (the formatter runs many times
/// per dashboard render).
final _thousandsSep = RegExp(r'(\d)(?=(\d{3})+$)');

/// Strips non-dial characters from a phone number for a `tel:` link.
final _phoneClean = RegExp(r'[^0-9+]');

/// Home / overview page: greeting + quick stats hero, then result & attendance
/// summary cards.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  // Pull-to-refresh always bypasses the freshness throttle and fetches live.
  Future<void> _refresh(WidgetRef ref) => Future.wait([
        ref.read(homeProvider.notifier).load(force: true),
        ref.read(noticesProvider.notifier).load(force: true),
        ref.read(resultsProvider.notifier).load(force: true),
        ref.read(attendanceProvider.notifier).load(force: true),
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

    // Centralized token-expiry handling: an unauthorized (401) result from ANY
    // of the core data providers means our token died — log out once. Listening
    // to only one provider before meant an expiry surfaced via a different
    // provider was handled inconsistently. logout() is idempotent (it just
    // clears state), so overlapping triggers are harmless.
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

    final expired = (results is ResData<ResultsData> && results.sessionExpired) ||
        (attendance is ResData<AttendanceData> && attendance.sessionExpired);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            // Sticky header: logo + reload + profile. Stays pinned on scroll.
            _StickyHeaderBar(
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
                      ref.read(resultsProvider.notifier).load(force: true),
                  onRetryAttendance: () =>
                      ref.read(attendanceProvider.notifier).load(force: true),
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
class _StickyHeaderBar extends ConsumerWidget {
  final VoidCallback onProfile;
  final Future<void> Function() onReload;
  const _StickyHeaderBar({
    required this.onProfile,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    // Watch the avatar HERE (not in DashboardPage.build) so an avatar
    // load/refresh rebuilds only this bar, not the whole page.
    final avatarBytes = ref.watch(avatarProvider).value;
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
          // The brand icon on the neutral app-bar surface (never on a colored
          // tile), with the wordmark as text beside it.
          const BrandIcon(size: 28),
          const SizedBox(width: Spacing.sm),
          Text('Open Campus',
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const Spacer(),
          _ReloadButton(onReload: onReload),
          const SizedBox(width: Spacing.sm),
          Semantics(
            button: true,
            label: 'Profile',
            child: Tooltip(
              message: 'Profile',
              child: SpringTap(
                onTap: onProfile,
                borderRadius: BorderRadius.circular(999),
                child: Avatar(bytes: avatarBytes, radius: 22),
              ),
            ),
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
    const notices = _NoticesCard();
    final resultsCard = Builder(builder: (context) {
      return ResourceSection<ResultsData>(
        title: 'Results',
        icon: Icons.school_outlined,
        state: results,
        loadingSkeleton: const CardSkeleton(chart: true),
        builder: (d) => ResultsContent(d),
        onRetry: onRetryResults,
        onOpen: () =>
            Navigator.of(context).push(sharedAxisRoute(const ResultsPage())),
      );
    });
    final attendanceCard = Builder(builder: (context) {
      return ResourceSection<AttendanceData>(
        title: 'Attendance',
        icon: Icons.event_available_outlined,
        state: attendance,
        loadingSkeleton: const CardSkeleton(lines: 4),
        builder: (d) => AttendanceContent(d),
        onRetry: onRetryAttendance,
        onOpen: () => Navigator.of(context)
            .push(sharedAxisRoute(const AttendancePage())),
      );
    });

    if (Breakpoints.isDesktop(context)) {
      // Upcoming is paired equal-height with Today's classes. Today shows ALL of
      // today's classes (1..n), so match Upcoming's event count to it — otherwise
      // a day with 3-4 classes leaves Upcoming (fixed at 2) with empty space.
      // At least 2 so a light class day doesn't shrink Upcoming below its norm.
      final todayCount = _TodayCard.todaysClasses(home).length;
      final upcomingCount = todayCount > 2 ? todayCount : 2;

      // The top four summary cards share ONE height so the 2×2 block is even;
      // Each ROW is equal-height (so its two cards align), but rows size to
      // their own content — Payment/Advisor (less info) sit shorter than
      // Upcoming/Today rather than all four sharing one tall height.
      return _StaggerColumn(children: [
        _Pair(
          equalHeight: true,
          left: _UpcomingCard(fill: true, count: upcomingCount),
          right: _TodayCard(home: home, fill: true),
        ),
        _Pair(
          equalHeight: true,
          left: _PaymentCard(home: home, fill: true),
          right: _AdvisorCard(home: home, fill: true),
        ),
        _Pair(left: resultsCard, right: attendanceCard),
        notices,
      ]);
    }

    // Mobile: single stacked column (cards shrink-wrap their content).
    return _StaggerColumn(children: [
      const _UpcomingCard(),
      _TodayCard(home: home),
      _PaymentCard(home: home),
      _AdvisorCard(home: home),
      notices,
      resultsCard,
      attendanceCard,
    ]);
  }
}


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/avatar.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../academics/calendar_model.dart';
import '../academics/calendar_page.dart';
import '../academics/class_routine_page.dart';
import '../auth/auth_controller.dart';
import '../finance/bill_page.dart';
import '../profile/profile_page.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'home_model.dart';
import 'models.dart';
import 'notices_model.dart';
import 'resource_view.dart';

/// Thousands separator, compiled once and reused (the formatter runs many times
/// per dashboard render).
final _thousandsSep = RegExp(r'(\d)(?=(\d{3})+$)');

/// Strips non-dial characters from a phone number for a `tel:` link.
final _phoneClean = RegExp(r'[^0-9+]');

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

    if (Breakpoints.isDesktop(context)) {
      // The top four summary cards share ONE height so the 2×2 block is even;
      // Each ROW is equal-height (so its two cards align), but rows size to
      // their own content — Payment/Advisor (less info) sit shorter than
      // Upcoming/Today rather than all four sharing one tall height.
      return _StaggerColumn(children: [
        _Pair(
          equalHeight: true,
          left: const _UpcomingCard(fill: true),
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

/// Wide "Upcoming" card: shows the next academic-calendar event computed from
/// today's date, and links to the full calendar.
class _UpcomingCard extends ConsumerWidget {
  final bool fill;
  const _UpcomingCard({this.fill = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final async = ref.watch(academicCalendarProvider);

    void openCalendar() => Navigator.of(context)
        .push(sharedAxisRoute(const CalendarPage()));

    final cal = async.asData?.value.defaultCalendar;
    final events = cal?.nextEvents(2) ?? const [];

    return _DashCard(
      fill: fill,
      onTap: openCalendar,
      icon: Icons.event_note_outlined,
      title: 'Upcoming',
      trailing: cal != null
          ? Text(cal.term,
              style: context.text.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant))
          : null,
      footer: 'Show academic calendar',
      body: async.isLoading
          ? const CardSkeleton(lines: 2)
          : events.isNotEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < events.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: Spacing.lg, color: scheme.outlineVariant),
                      _UpcomingEvent(events[i]),
                    ],
                  ],
                )
              : Text(
                  async.hasError
                      ? 'Couldn\'t load the academic calendar.'
                      : 'No upcoming events.',
                  style: context.text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondary,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(e.icon, color: scheme.onSecondary, size: 20),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
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

/// Shared scaffold for the four summary cards (Upcoming, Today, Payment,
/// Advisor) so they look identical and fill their (equal) height cleanly:
/// header pinned top, [body] vertically centered in the freed space, and the
/// [footer] action pinned to the bottom. The Column fills its height (no
/// MainAxisSize.min) so a stretched cell is used instead of leaving dead space.
class _DashCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget body;
  final String? footer;
  final VoidCallback? onTap;

  /// True in the desktop 2×2 grid (cells have bounded, equal height): the body
  /// expands to fill and the footer pins to the bottom. False on mobile (the
  /// card sits in an unbounded scroll list): shrink-wrap to content.
  final bool fill;
  const _DashCard({
    required this.icon,
    required this.title,
    required this.body,
    this.trailing,
    this.footer,
    this.onTap,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final header = Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: Spacing.sm),
        Text(title, style: context.text.titleMedium),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
    final footerRow = footer == null
        ? null
        : Row(
            children: [
              Text(footer!,
                  style: context.text.labelLarge?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w700)),
              Icon(Icons.chevron_right, size: 20, color: scheme.primary),
            ],
          );

    return SpringTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          children: [
            header,
            const SizedBox(height: Spacing.lg),
            if (fill)
              // Body sits directly under the header (top-aligned); extra height
              // from the equal-height grid becomes breathing room before the
              // footer (which keeps its own gap below).
              Expanded(
                child: Align(alignment: Alignment.topLeft, child: body),
              )
            else
              body,
            if (footerRow != null) ...[
              const SizedBox(height: Spacing.lg),
              footerRow,
            ],
          ],
        ),
      ),
    );
  }
}

class _StaggerColumn extends StatelessWidget {
  final List<Widget> children;
  const _StaggerColumn({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: i * 70,
            child: children[i],
          ),
        ],
      ],
    );
  }
}

/// Two cards side by side (desktop). With [equalHeight] the row is sized to the
/// taller card and both stretch to match (used for the summary-card pairs, whose
/// cards use fill:true to expand their body). Without it, the cards keep their
/// natural height — used for the Results/Attendance pair, since IntrinsicHeight
/// is fragile around the charts.
class _Pair extends StatelessWidget {
  final Widget left;
  final Widget right;
  final bool equalHeight;
  const _Pair({required this.left, required this.right, this.equalHeight = false});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment:
          equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: Spacing.lg),
        Expanded(child: right),
      ],
    );
    return equalHeight ? IntrinsicHeight(child: row) : row;
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
    final accentFg = onAccent(accent); // readable on the accent fill/chip
    final bg = filled ? accent : scheme.surface;
    final fg = filled ? accentFg : scheme.onSurface;
    final dim = filled ? accentFg.withValues(alpha: 0.85) : scheme.onSurfaceVariant;
    final iconBg = filled ? accentFg.withValues(alpha: 0.20) : accent;

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
                  // Filled: chip is translucent fg → use accentFg. Unfilled:
                  // chip is the solid accent → use its readable foreground.
                  child: Icon(icon,
                      size: 14, color: filled ? accentFg : onAccent(accent)),
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

String _bdt(double? v) {
  if (v == null) return '—';
  final n = v.abs();
  // Group thousands with commas (regex compiled once, see _thousandsSep).
  final s =
      n.toStringAsFixed(0).replaceAllMapped(_thousandsSep, (m) => '${m[1]},');
  return '৳ $s';
}

/// Payment card (matches Upcoming / Today's classes): the outstanding due plus a
/// live countdown to the next tuition installment deadline. The active
/// installment advances automatically (1st → 2nd → 3rd) as each date passes,
/// using deadlines read from the academic calendar.
class _PaymentCard extends ConsumerWidget {
  final HomeSummary? home;
  final bool fill;
  const _PaymentCard({this.home, this.fill = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final hasDue = home?.hasDue ?? false;
    final due = home?.dueAmount ?? 0;

    final cal = ref.watch(academicCalendarProvider).asData?.value.defaultCalendar;
    final next = cal?.activeInstallment;

    void openBill() =>
        Navigator.of(context).push(sharedAxisRoute(const BillPage()));

    return _DashCard(
      fill: fill,
      onTap: openBill,
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payment',
      trailing: home != null
          ? _StatusPill(
              label: hasDue ? 'Due' : 'Clear',
              fg: hasDue ? context.status.bad : context.status.good,
              bg: hasDue
                  ? context.status.badContainer
                  : context.status.goodContainer,
            )
          : null,
      footer: 'View bill & payments',
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hasDue ? 'Due amount' : 'Balance',
                    style: context.text.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hasDue ? _bdt(due) : 'No dues',
                    maxLines: 1,
                    style: context.text.headlineSmall?.copyWith(
                        color:
                            hasDue ? scheme.onSurface : context.status.good,
                        fontWeight: FontWeight.w800,
                        height: 1.0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          if (next != null)
            _InstallmentCountdown(next)
          else
            Flexible(
              child: Text('No installment\ndeadline',
                  textAlign: TextAlign.right,
                  style: context.text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

/// Live "time left" panel for the next installment deadline. Ticks every second
/// while mounted; the controller is disposed cleanly.
class _InstallmentCountdown extends StatefulWidget {
  final InstallmentDeadline installment;
  const _InstallmentCountdown(this.installment);

  @override
  State<_InstallmentCountdown> createState() => _InstallmentCountdownState();
}

class _InstallmentCountdownState extends State<_InstallmentCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Re-tick each second so the live timer counts down smoothly.
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
    final inst = widget.installment;
    // Deadline is end-of-day on the due date (you have until midnight).
    final end = DateTime(inst.deadline.year, inst.deadline.month,
        inst.deadline.day, 23, 59, 59);
    final remaining = end.difference(DateTime.now());
    final overdue = remaining.isNegative;
    final accent = overdue ? context.status.bad : scheme.primary;

    // Right-aligned plain-text block: label on top, the live timer below.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(overdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                size: 13, color: accent),
            const SizedBox(width: 4),
            Text('${inst.ordinalLabel} installment',
                style: context.text.labelSmall
                    ?.copyWith(color: accent, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          overdue ? 'Overdue' : _timer(remaining),
          style: context.text.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }

  /// Live timer with seconds: "Dd HH:MM:SS" when days remain, else "HH:MM:SS".
  static String _timer(Duration r) {
    final d = r.inDays;
    final h = r.inHours % 24;
    final m = r.inMinutes % 60;
    final s = r.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (d > 0) return '${d}d ${two(h)}:${two(m)}:${two(s)}';
    return '${two(h)}:${two(m)}:${two(s)}';
  }
}

/// Small tonal status pill (e.g. Due / Clear).
class _StatusPill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const _StatusPill({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(label,
          style: context.text.labelSmall
              ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

/// Today's classes, pulled from the home routine. Hidden if there are none.
class _TodayCard extends StatelessWidget {
  final HomeSummary? home;
  final bool fill;
  const _TodayCard({this.home, this.fill = false});

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
    final scheme = context.scheme;
    final routine = home?.routine ?? const [];
    final today = _names[DateTime.now().weekday];
    final todays = routine.where((s) => s.day == today).toList();

    void openRoutine() => Navigator.of(context)
        .push(sharedAxisRoute(const ClassRoutinePage()));

    return _DashCard(
      fill: fill,
      onTap: openRoutine,
      icon: Icons.today_outlined,
      title: 'Today’s classes',
      trailing: todays.isNotEmpty
          ? Text(todays.length == 1 ? '1 class' : '${todays.length} classes',
              style: context.text.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant))
          : null,
      footer: 'Show full routine',
      body: todays.isEmpty
          ? Row(
              children: [
                Icon(Icons.free_breakfast_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: Spacing.sm),
                Text('No classes today',
                    style: context.text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < todays.length; i++) ...[
                  if (i > 0)
                    Divider(height: Spacing.lg, color: scheme.outlineVariant),
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
  final bool fill;
  const _AdvisorCard({this.home, this.fill = false});

  Future<void> _email(BuildContext context, String address) async {
    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query: 'subject=${Uri.encodeComponent('Advising — ${home?.roll ?? ''}')}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open your email app.')),
      );
    }
  }

  /// Open the phone dialer with the number pre-filled (tel:). The dialer shows
  /// the number ready to call — the user can also long-press to copy it there.
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
    final advisor = home?.advisor;
    if (advisor == null || advisor.name == null) {
      return const SizedBox.shrink();
    }
    final scheme = context.scheme;
    final email = advisor.email;
    final hasEmail = email != null && email.isNotEmpty;
    final hasPhone = advisor.phone != null && advisor.phone!.isNotEmpty;

    return _DashCard(
      fill: fill,
      icon: Icons.support_agent_outlined,
      title: 'Academic Advisor',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity row: blue avatar + name/room, small Email action on right.
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.secondary, // brand blue
                ),
                child: Text(
                  advisor.initial ?? _initials(advisor.name!),
                  style: context.text.labelLarge?.copyWith(
                      color: scheme.onSecondary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(advisor.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (advisor.room != null && advisor.room!.isNotEmpty)
                      Text('Room ${advisor.room}',
                          style: context.text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (hasEmail) ...[
                const SizedBox(width: Spacing.sm),
                _ContactButton(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  color: scheme.secondary,
                  onTap: () => _email(context, email),
                ),
              ],
            ],
          ),
          if (hasPhone) ...[
            const SizedBox(height: Spacing.md),
            _ContactLine(
              icon: Icons.call_outlined,
              label: advisor.phone!,
              onTap: () => _call(context, advisor.phone!),
            ),
          ],
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

/// A compact icon + label contact row (email/phone). Tappable when [onTap] set.
class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ContactLine({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tappable = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Row(
        children: [
          Icon(icon,
              size: 14,
              color: tappable ? scheme.secondary : scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                    color: tappable ? scheme.secondary : scheme.onSurface,
                    fontWeight: tappable ? FontWeight.w600 : null)),
          ),
        ],
      ),
    );
  }
}

/// A small pill-shaped action button (icon + label) used in the advisor card.
class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.full),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.scheme.onSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: context.text.labelMedium?.copyWith(
                    color: context.scheme.onSecondary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
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

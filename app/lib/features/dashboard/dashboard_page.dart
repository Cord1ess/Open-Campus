import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/accents.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/avatar.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
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
            SliverToBoxAdapter(
              child: _Hero(
                roll: roll,
                home: homeData,
                avatarBytes: avatarBytes,
                results: results,
                attendance: attendance,
                onProfile: () => Navigator.of(context)
                    .push(sharedAxisRoute(const ProfilePage())),
                onReload: () => _refresh(ref),
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

class _Hero extends StatelessWidget {
  final String? roll;
  final HomeSummary? home;
  final List<int>? avatarBytes;
  final ResourceState<ResultsData> results;
  final ResourceState<AttendanceData> attendance;
  final VoidCallback onProfile;
  final Future<void> Function() onReload;

  const _Hero({
    required this.roll,
    required this.home,
    required this.avatarBytes,
    required this.results,
    required this.attendance,
    required this.onProfile,
    required this.onReload,
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

    // Real name from /student/home; greeting falls back gracefully while loading.
    final name = home?.name ?? (roll != null ? 'Student' : 'Welcome');
    final firstName = name.split(' ').first;
    final avatar = avatarBytes;
    // Distinct-but-harmonized accent tones derived from the seed, so the three
    // hero cards each get their own on-theme color (not the same two repeated).
    final accents = Accents.of(context);

    return Container(
      color: scheme.surface,
      padding: EdgeInsets.fromLTRB(Spacing.lg,
          MediaQuery.of(context).padding.top + Spacing.lg, Spacing.lg, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(Icons.school_rounded,
                    size: 18, color: scheme.onPrimary),
              ),
              const SizedBox(width: Spacing.sm),
              Text('Open Campus',
                  style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const Spacer(),
              // Reload: safely re-fetches all dashboard data (read-only).
              _ReloadButton(onReload: onReload),
              const SizedBox(width: Spacing.sm),
              SpringTap(
                onTap: onProfile,
                borderRadius: BorderRadius.circular(999),
                child: Avatar(bytes: avatar, radius: 22),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          Text(home?.name != null ? 'Welcome back,' : 'Welcome',
              style: context.text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          Text(firstName,
              style: context.text.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Spacing.xl),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: _SemesterCard(
                        tone: accents[0],
                        current: home?.currentTerm,
                        next: home?.nextTerms.isNotEmpty == true
                            ? home!.nextTerms.first
                            : null)),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _StatCard(
                  icon: Icons.workspace_premium,
                  label: 'CGPA',
                  value: cgpa?.toStringAsFixed(2) ?? '—',
                  tone: accents[2].background,
                  onTone: accents[2].foreground,
                ),
              ),
              const SizedBox(width: Spacing.md),
                Expanded(
                  child: _StatCard(
                    icon: Icons.event_available,
                    label: 'Attendance',
                    value: att != null ? '${att.toStringAsFixed(0)}%' : '—',
                    tone: accents[4].background,
                    onTone: accents[4].foreground,
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

    if (Breakpoints.isDesktop(context)) {
      // Two balanced columns. Heavier/visual cards on the left.
      final left = <Widget>[today, payment, resultsCard];
      final right = <Widget>[notices, advisor, attendanceCard];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _StaggerColumn(children: left)),
          const SizedBox(width: Spacing.lg),
          Expanded(child: _StaggerColumn(baseDelay: 60, children: right)),
        ],
      );
    }

    // Phone/tablet: single staggered column, original order.
    return _StaggerColumn(children: [
      today,
      payment,
      advisor,
      notices,
      resultsCard,
      attendanceCard,
    ]);
  }
}

/// A vertical stack of cards each fading/sliding in with an increasing delay.
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

/// Current trimester (big) + next registration trimester (small). Real data
/// from /student/home; shows em-dashes while loading.
class _SemesterCard extends StatelessWidget {
  final Term? current;
  final Term? next;
  final AccentTone tone;
  const _SemesterCard({required this.tone, this.current, this.next});

  @override
  Widget build(BuildContext context) {
    final bg = tone.background;
    final fg = tone.foreground;
    // Prefer the numeric code as the headline; if a user's term has no code,
    // fall back to showing the name big so the card is never just a dash.
    final hasCode = current?.code != null && current!.code!.isNotEmpty;
    final currentCode = hasCode ? current!.code! : (current?.name ?? '—');
    final currentName = hasCode ? (current?.name ?? 'Semester') : '';
    final nextCode = next?.code ?? next?.name;

    return SpringTap(
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today, size: 16, color: fg),
            ),
            const SizedBox(height: Spacing.lg),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(currentCode,
                  maxLines: 1,
                  style: context.text.headlineMedium?.copyWith(
                      color: fg, fontWeight: FontWeight.w800, height: 1.0)),
            ),
            const SizedBox(height: 2),
            Text(currentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium
                    ?.copyWith(color: fg.withValues(alpha: 0.85))),
            const SizedBox(height: 2),
            Text(nextCode != null ? 'Next: $nextCode' : ' ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall
                    ?.copyWith(color: fg.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final Color onTone;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.onTone,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: onTone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: onTone),
            ),
            const SizedBox(height: Spacing.lg),
            // Value scales to fit its card — never overflows on narrow screens.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: context.text.headlineMedium?.copyWith(
                      color: onTone,
                      fontWeight: FontWeight.w800,
                      height: 1.0)),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium
                    ?.copyWith(color: onTone.withValues(alpha: 0.85))),
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

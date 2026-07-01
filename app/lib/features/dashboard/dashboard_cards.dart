// Dashboard leaf cards (Upcoming, Today, Payment, Advisor, Notices, hero stat
// cards, and their small helpers). A `part` of dashboard_page.dart so these
// private widgets stay library-private while living in their own file — the
// page/layout orchestration stays in dashboard_page.dart.
part of 'dashboard_page.dart';

/// Wide "Upcoming" card: shows the next academic-calendar event computed from
/// today's date, and links to the full calendar.
class _UpcomingCard extends ConsumerWidget {
  final bool fill;
  /// How many upcoming events to show. Defaults to 2; the desktop pairing raises
  /// it to match Today's class count so the two equal-height cards line up.
  final int count;
  const _UpcomingCard({this.fill = false, this.count = 2});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final async = ref.watch(academicCalendarProvider);

    void openCalendar() => Navigator.of(context)
        .push(sharedAxisRoute(const CalendarPage()));

    final cal = async.asData?.value.defaultCalendar;
    final events = cal?.nextEvents(count) ?? const [];

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
              // Due stays red (it genuinely flags money owed); "Clear" uses the
              // theme accent rather than a clashing green.
              fg: hasDue ? context.status.bad : scheme.primary,
              bg: hasDue
                  ? context.status.badContainer
                  : scheme.primary.withValues(alpha: 0.14),
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
                        color: hasDue ? scheme.onSurface : scheme.primary,
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

class _InstallmentCountdownState extends State<_InstallmentCountdown>
    with WidgetsBindingObserver {
  Timer? _ticker;
  // Only the timer Text rebuilds each second — not the icon/label row. This
  // matters because this card lives on the Dashboard tab, which stays mounted in
  // the shell's IndexedStack even when another tab is showing.
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
    final scheme = context.scheme;
    final inst = widget.installment;
    // Deadline is end-of-day on the due date (you have until midnight).
    final end = DateTime(inst.deadline.year, inst.deadline.month,
        inst.deadline.day, 23, 59, 59);

    // Right-aligned plain-text block: label on top, the live timer below. Only
    // the timer Text listens to the per-second tick.
    return ValueListenableBuilder<DateTime>(
      valueListenable: _now,
      builder: (context, now, _) {
        final remaining = end.difference(now);
        final overdue = remaining.isNegative;
        final accent = overdue ? context.status.bad : scheme.primary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    overdue
                        ? Icons.warning_amber_rounded
                        : Icons.timer_outlined,
                    size: 13,
                    color: accent),
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
      },
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

  /// Today's class sessions from the home routine — the single source of truth
  /// for both this card and the count the Upcoming card matches against.
  static List<ClassSession> todaysClasses(HomeSummary? home) {
    final routine = home?.routine ?? const <ClassSession>[];
    final today = _names[DateTime.now().weekday];
    return routine.where((s) => s.day == today).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final todays = todaysClasses(home);

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

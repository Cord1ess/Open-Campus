import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'calendar_model.dart';
import 'google_calendar.dart';

/// Academic calendar — live from UIU (scraped server-side). Each term/program
/// has its own calendar; events render as Material date cards you can tap to
/// see details, set a reminder, or add to Google Calendar. A top action exports
/// the whole calendar as an .ics import.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  final Set<String> _reminders = {};
  static const _prefsKey = 'oc_calendar_reminders';
  int? _selected; // index into the calendars list; null = auto default

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _reminders.addAll(prefs.getStringList(_prefsKey) ?? []));
    }
  }

  Future<void> _toggle(CalendarEvent e, bool on) async {
    setState(() => on ? _reminders.add(e.id) : _reminders.remove(e.id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _reminders.toList());

    if (on) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enable notifications to get reminders.')));
      }
      final when = DateTime(e.date.year, e.date.month, e.date.day, 9);
      await NotificationService.instance.scheduleAt(
        id: e.notificationId,
        title: e.title,
        body:
            '${e.dateText}${e.detail != null && e.detail!.isNotEmpty ? ' · ${e.detail}' : ''}',
        when: when,
      );
    } else {
      await NotificationService.instance.cancel(e.notificationId);
    }
  }

  Future<void> _open(String url) async {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')));
    }
  }

  /// Bottom sheet with event details, reminder toggle, and add-to-Google.
  void _showEvent(CalendarEvent e, String calName) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final scheme = sheetCtx.scheme;
        final on = _reminders.contains(e.id);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xl, 0, Spacing.xl, Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _EventBadge(e),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title,
                              style: sheetCtx.text.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text('${e.dateText}  ·  ${e.detail ?? ''}',
                              style: sheetCtx.text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                if (!e.isPast)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: on,
                    title: const Text('Remind me'),
                    subtitle: const Text('Notification at 9am on the day'),
                    onChanged: (v) {
                      _toggle(e, v);
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                const SizedBox(height: Spacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _open(GoogleCalendar.eventUrl(e, calendarName: calName));
                    },
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Add to Google Calendar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(academicCalendarProvider);
    return Scaffold(
      body: async.when(
        loading: () => const CollapsingTitleScrollView(
          title: 'Academic Calendar',
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(Spacing.lg),
              sliver: SliverToBoxAdapter(child: CardSkeleton(lines: 6)),
            ),
          ],
        ),
        error: (e, _) => CollapsingTitleScrollView(
          title: 'Academic Calendar',
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverToBoxAdapter(
                child: StateMessage(
                  icon: Icons.error_outline,
                  title: 'Couldn\'t load the calendar',
                  subtitle: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(academicCalendarProvider),
                ),
              ),
            ),
          ],
        ),
        data: (data) => _body(context, data),
      ),
    );
  }

  Widget _body(BuildContext context, AcademicCalendarData data) {
    final cals = data.calendars;
    if (cals.isEmpty) {
      return const CollapsingTitleScrollView(
        title: 'Academic Calendar',
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(Spacing.lg),
            sliver: SliverToBoxAdapter(
              child: StateMessage(
                  icon: Icons.event_busy_outlined,
                  title: 'No calendars published yet'),
            ),
          ),
        ],
      );
    }

    final defaultCal = data.defaultCalendar;
    final idx = _selected ??
        (defaultCal != null ? cals.indexOf(defaultCal) : 0)
            .clamp(0, cals.length - 1);
    final cal = cals[idx];
    final calName = '${cal.term} · ${cal.program}';

    // Order: upcoming first (ascending), then past — flattened with headers so
    // we can render lazily via a sliver builder (no all-at-once layout lag).
    final upcoming = cal.events.where((e) => !e.isPast).toList();
    final past = cal.events.where((e) => e.isPast).toList();
    final rows = <_Row>[
      if (upcoming.isNotEmpty) const _Row.header('Upcoming'),
      for (final e in upcoming) _Row.event(e),
      if (past.isNotEmpty) const _Row.header('Past'),
      for (final e in past) _Row.event(e, past: true),
    ];

    return CollapsingTitleScrollView(
      title: 'Academic Calendar',
      slivers: [
        // Pinned controls: calendar picker + add-to-Google.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.sm, Spacing.lg, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _CalendarPicker(
                  calendars: cals,
                  selected: idx,
                  onSelect: (i) => setState(() => _selected = i),
                ),
                const SizedBox(height: Spacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _open(GoogleCalendar.icsDataUrl(
                        cal.events,
                        calendarName: calName)),
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Add all to Google Calendar'),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
              ],
            ),
          ),
        ),
        // Lazily-built event cards.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, 0, Spacing.lg, 96),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              if (row.header != null) {
                return Padding(
                  padding: EdgeInsets.only(
                      left: Spacing.xs,
                      top: i == 0 ? 0 : Spacing.lg,
                      bottom: Spacing.sm),
                  child: Text(row.header!.toUpperCase(),
                      style: context.text.labelMedium?.copyWith(
                          color: context.scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                );
              }
              final e = row.event!;
              return Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _EventCard(
                  event: e,
                  reminderOn: _reminders.contains(e.id),
                  past: row.past,
                  onTap: () => _showEvent(e, calName),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A flattened row: either a section header or an event.
class _Row {
  final String? header;
  final CalendarEvent? event;
  final bool past;
  const _Row.header(this.header)
      : event = null,
        past = false;
  const _Row.event(this.event, {this.past = false}) : header = null;
}

/// Dropdown to choose which calendar (term + program) to view.
class _CalendarPicker extends StatelessWidget {
  final List<AcademicCalendar> calendars;
  final int selected;
  final ValueChanged<int> onSelect;
  const _CalendarPicker({
    required this.calendars,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return DropdownButtonFormField<int>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.calendar_month_outlined),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        for (var i = 0; i < calendars.length; i++)
          DropdownMenuItem(
            value: i,
            child: Text(
              '${calendars[i].term} · ${calendars[i].program}'
              '${calendars[i].revised ? ' (Revised)' : ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (i) => i != null ? onSelect(i) : null,
    );
  }
}

/// Material event card: a date badge, the event text, and a reminder dot. The
/// whole card is tappable to open the detail sheet.
class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final bool reminderOn;
  final bool past;
  final VoidCallback onTap;
  const _EventCard({
    required this.event,
    required this.reminderOn,
    required this.past,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Opacity(
      opacity: past ? 0.6 : 1,
      child: SpringTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              _EventBadge(event),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        '${event.dateText}'
                        '${event.detail != null && event.detail!.isNotEmpty ? '  ·  ${event.detail}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (reminderOn)
                Icon(Icons.notifications_active,
                    size: 18, color: scheme.primary),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A square colored badge showing the start day + month, colored by event type.
class _EventBadge extends StatelessWidget {
  final CalendarEvent e;
  const _EventBadge(this.e);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  Color _color(BuildContext context) => switch (e.type) {
        CalendarEventType.payment => context.status.warn,
        CalendarEventType.exam => context.status.bad,
        CalendarEventType.holiday => context.status.good,
        CalendarEventType.registration => context.scheme.primary,
        CalendarEventType.classDay => context.scheme.secondary,
        CalendarEventType.other => context.scheme.secondary,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${e.date.day}',
              style: context.text.titleMedium?.copyWith(
                  color: color, fontWeight: FontWeight.w800, height: 1.0)),
          Text(_months[e.date.month - 1],
              style: context.text.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

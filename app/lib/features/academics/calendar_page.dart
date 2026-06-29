import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import 'calendar_model.dart';

/// Academic calendar — a timeline of term events. Each upcoming event can have a
/// reminder toggled on, which schedules an on-device notification the morning of
/// the event. Data is scaffolded; the plumbing is real.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late List<CalendarEvent> _events;
  final Set<String> _reminders = {};
  static const _prefsKey = 'oc_calendar_reminders';

  @override
  void initState() {
    super.initState();
    _events = sampleCalendar(DateTime.now())
      ..sort((a, b) => a.date.compareTo(b.date));
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _reminders.addAll(prefs.getStringList(_prefsKey) ?? []));
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
      // Remind at 9am on the event day.
      final when = DateTime(e.date.year, e.date.month, e.date.day, 9);
      await NotificationService.instance.scheduleAt(
        id: e.notificationId,
        title: e.title,
        body: e.detail ?? 'Academic calendar reminder',
        when: when,
      );
    } else {
      await NotificationService.instance.cancel(e.notificationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _events.where((e) => !e.isPast).toList();
    final past = _events.where((e) => e.isPast).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Academic Calendar')),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              const _ScaffoldNote(),
              const SizedBox(height: Spacing.lg),
              if (upcoming.isNotEmpty) ...[
                _sectionLabel(context, 'Upcoming'),
                const SizedBox(height: Spacing.sm),
                for (var i = 0; i < upcoming.length; i++)
                  FadeSlideIn(
                    delayMs: 30 * i,
                    child: _EventTile(
                      event: upcoming[i],
                      reminderOn: _reminders.contains(upcoming[i].id),
                      onReminder: (v) => _toggle(upcoming[i], v),
                      isFirst: i == 0,
                      isLast: i == upcoming.length - 1,
                    ),
                  ),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: Spacing.lg),
                _sectionLabel(context, 'Past'),
                const SizedBox(height: Spacing.sm),
                for (var i = 0; i < past.length; i++)
                  _EventTile(
                    event: past[i],
                    reminderOn: false,
                    onReminder: null,
                    isFirst: i == 0,
                    isLast: i == past.length - 1,
                    dimmed: true,
                  ),
              ],
              const SizedBox(height: 96),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(left: Spacing.xs),
        child: Text(t.toUpperCase(),
            style: context.text.labelMedium?.copyWith(
                color: context.scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      );
}

class _ScaffoldNote extends StatelessWidget {
  const _ScaffoldNote();
  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
                'Sample calendar — your term\'s real dates load here once '
                'connected. Reminders you set will still work.',
                style: context.text.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// A timeline tile: a connector rail with a node, the date, and the event.
class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final bool reminderOn;
  final ValueChanged<bool>? onReminder;
  final bool isFirst;
  final bool isLast;
  final bool dimmed;

  const _EventTile({
    required this.event,
    required this.reminderOn,
    required this.onReminder,
    required this.isFirst,
    required this.isLast,
    this.dimmed = false,
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  Color _typeColor(BuildContext context) => switch (event.type) {
        CalendarEventType.payment => context.status.warn,
        CalendarEventType.exam => context.status.bad,
        CalendarEventType.holiday => context.status.good,
        CalendarEventType.registration => context.scheme.primary,
        CalendarEventType.classDay => context.scheme.tertiary,
        CalendarEventType.other => context.scheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = _typeColor(context);
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Text('${event.date.day}',
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(_months[event.date.month - 1],
                      style: context.text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                    width: 2,
                    height: 14,
                    color:
                        isFirst ? Colors.transparent : scheme.outlineVariant),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                      width: 2,
                      color:
                          isLast ? Colors.transparent : scheme.outlineVariant),
                ),
              ],
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border(left: BorderSide(color: color, width: 3)),
                  ),
                  child: Row(
                    children: [
                      Icon(event.icon, size: 20, color: color),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title,
                                style: context.text.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            if (event.detail != null)
                              Text(event.detail!,
                                  style: context.text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      if (onReminder != null)
                        IconButton(
                          tooltip: reminderOn ? 'Reminder on' : 'Remind me',
                          icon: Icon(
                            reminderOn
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            color: reminderOn ? color : scheme.onSurfaceVariant,
                          ),
                          onPressed: () => onReminder!(!reminderOn),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

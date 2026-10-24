import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/notifications/web_notify.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import 'calendar_model.dart';
import 'google_calendar.dart';
import 'ics_export.dart';

const _title = 'Academic Calendar';

/// Academic calendar — live from UIU (scraped server-side). Each term/program
/// has its own calendar; events are listed upcoming-first. Tap an event to see
/// details, set a reminder, or add it to Google Calendar. The whole calendar can
/// be exported as an .ics file.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  final Set<String> _reminders = {};
  static const _prefsKey = 'oc_calendar_reminders';
  int? _selected; // index into the calendars list; null = auto default
  CalendarEvent? _selectedEvent; // desktop: event shown in the right panel

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

    if (!on) {
      await NotificationService.instance.cancel(e.notificationId);
      return;
    }

    final detail =
        e.detail != null && e.detail!.isNotEmpty ? ' · ${e.detail}' : '';

    if (kIsWeb) {
      // Web: request browser permission and fire an immediate confirmation.
      // (Day-of scheduled firing needs a service worker we don't ship; the
      // reminder is still tracked in the in-app list.)
      final shown = await showWebConfirmation(
          'Reminder set: ${e.title}', '${e.dateText}$detail');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(shown
              ? 'Reminder set — we’ll notify you in the browser.'
              : 'Allow notifications in your browser to get reminders.'),
        ));
      }
      return;
    }

    // Mobile/desktop: schedule a real local notification for 9am on the day.
    final granted = await NotificationService.instance.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enable notifications to get reminders.')));
    }
    final when = DateTime(e.date.year, e.date.month, e.date.day, 9);
    await NotificationService.instance.scheduleAt(
      id: e.notificationId,
      title: e.title,
      body: '${e.dateText}$detail',
      when: when,
    );
  }

  Future<void> _open(String url) async {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')));
    }
  }

  /// Export the whole calendar as an .ics (download on web, OS hand-off on
  /// mobile). The file is strictly RFC 5545–compliant.
  Future<void> _exportAll(List<CalendarEvent> events, String calName) async {
    final ok = await exportIcs(events, calendarName: calName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Calendar exported — open the .ics file to import it.'
          : 'Couldn’t export here. Tap an event and use '
              '“Add to Google Calendar” to add it directly.'),
    ));
  }

  /// Bottom sheet with event details, reminder toggle, and add-to-Google.
  void _showEvent(CalendarEvent e, String calName) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        final on = _reminders.contains(e.id);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, 0, Spacing.lg, Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventHeader(e),
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
                FormWidth(
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        _open(GoogleCalendar.eventUrl(e, calendarName: calName));
                      },
                      icon: const Icon(AppIcons.calendar, size: 18),
                      label: const Text('Add to Google Calendar'),
                    ),
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
    return async.when(
      loading: () => const PageScaffold(
        title: _title,
        body: LoadingState(label: 'Loading the academic calendar…'),
      ),
      error: (e, _) => PageScaffold(
        title: _title,
        body: ErrorState(
          title: 'Couldn’t load the calendar',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(academicCalendarProvider),
        ),
      ),
      data: (data) => _body(context, data),
    );
  }

  Widget _body(BuildContext context, AcademicCalendarData data) {
    final cals = data.calendars;
    if (cals.isEmpty) {
      return const PageScaffold(
        title: _title,
        body: EmptyState(
            icon: AppIcons.calendar, title: 'No calendars published yet'),
      );
    }

    final defaultCal = data.defaultCalendar;
    final idx = _selected ??
        (defaultCal != null ? cals.indexOf(defaultCal) : 0)
            .clamp(0, cals.length - 1);
    final cal = cals[idx];
    final calName = '${cal.term} · ${cal.program}';

    // Upcoming first (ascending), then past — flattened with headers so the
    // phone list can render lazily.
    final upcoming = cal.events.where((e) => !e.isPast).toList();
    final past = cal.events.where((e) => e.isPast).toList();
    final rows = <_Row>[
      if (upcoming.isNotEmpty) const _Row.header('Upcoming'),
      for (final e in upcoming) _Row.event(e),
      if (past.isNotEmpty) const _Row.header('Past'),
      for (final e in past) _Row.event(e, past: true),
    ];

    final wide = Breakpoints.isExpanded(context);

    final picker = _CalendarPicker(
      calendars: cals,
      selected: idx,
      onSelect: (i) => setState(() {
        _selected = i;
        _selectedEvent = null;
      }),
    );
    final export = OutlinedButton.icon(
      onPressed: () => _exportAll(cal.events, calName),
      icon: const Icon(AppIcons.download, size: 18),
      label: const Text('Export calendar (.ics)'),
    );
    final controls = wide
        ? Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: Breakpoints.formMaxWidth),
                    child: picker,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.lg),
              export,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormWidth(child: picker),
              const SizedBox(height: Spacing.md),
              export,
            ],
          );

    if (wide) {
      // Desktop: event list left, detail panel right.
      return PageScaffold(
        title: _title,
        body: Stacked(
          children: [
            controls,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        _rowWidget(rows, i, calName),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xl),
                Expanded(
                  flex: 2,
                  child: _DetailPanel(
                    event: _selectedEvent,
                    reminderOn: _selectedEvent != null &&
                        _reminders.contains(_selectedEvent!.id),
                    onToggleReminder: (on) => _toggle(_selectedEvent!, on),
                    onAddToGoogle: () => _open(GoogleCalendar.eventUrl(
                        _selectedEvent!,
                        calendarName: calName)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Phone: lazy list; detail opens in a bottom sheet.
    return PageScaffold(
      title: _title,
      slivers: [
        SliverToBoxAdapter(child: controls),
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) => _rowWidget(rows, i, calName),
        ),
      ],
    );
  }

  /// One row (section heading or event). Event rows are separated by hairlines;
  /// headings carry the section gap above them. On desktop, tapping selects the
  /// event into the right panel; on phones it opens the bottom sheet.
  Widget _rowWidget(List<_Row> rows, int i, String calName) {
    final row = rows[i];
    if (row.header != null) {
      return Padding(
        padding: EdgeInsets.only(top: i == 0 ? Spacing.xs : Spacing.xl),
        child: SectionHeading(title: row.header!),
      );
    }
    final e = row.event!;
    final wide = Breakpoints.isExpanded(context);
    final prevIsEvent = i > 0 && rows[i - 1].event != null;
    final selected = wide && _selectedEvent?.id == e.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prevIsEvent) const Divider(height: 1),
        ColoredBox(
          color: selected
              ? context.palette.accentTint
              : Colors.transparent,
          child: ListRow(
            leading: _DateColumn(e.date, muted: row.past),
            title: e.title,
            subtitle: _subtitle(e),
            muted: row.past,
            chevron: !wide,
            trailing: _reminders.contains(e.id)
                ? Icon(AppIcons.reminderOn,
                    size: 18, color: context.palette.accentInk)
                : null,
            onTap: () {
              if (wide) {
                setState(() => _selectedEvent = e);
              } else {
                _showEvent(e, calName);
              }
            },
          ),
        ),
      ],
    );
  }
}

String _subtitle(CalendarEvent e) {
  final detail = e.detail != null && e.detail!.isNotEmpty ? e.detail! : null;
  return [e.dateText, if (detail != null) detail].join(' · ');
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
    return DropdownButtonFormField<int>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Calendar',
        prefixIcon: Icon(AppIcons.calendar),
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

/// Day number over month, 44 wide — the row's leading date column.
class _DateColumn extends StatelessWidget {
  final DateTime date;
  final bool muted;
  const _DateColumn(this.date, {this.muted = false});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${date.day}',
              style: context.text.titleSmall?.copyWith(
                  color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                  fontFeatures: tabularFigures)),
          Text(_months[date.month - 1],
              style: context.text.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Date column + title + date line, shared by the sheet and the detail panel.
class _EventHeader extends StatelessWidget {
  final CalendarEvent e;
  const _EventHeader(this.e);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateColumn(e.date),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.title, style: context.text.titleMedium),
              const SizedBox(height: Spacing.xxs),
              Text(_subtitle(e), style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Desktop right-hand panel: details of the selected event with reminder +
/// add-to-Google actions. Shows an empty state until an event is picked.
class _DetailPanel extends StatelessWidget {
  final CalendarEvent? event;
  final bool reminderOn;
  final ValueChanged<bool> onToggleReminder;
  final VoidCallback onAddToGoogle;
  const _DetailPanel({
    required this.event,
    required this.reminderOn,
    required this.onToggleReminder,
    required this.onAddToGoogle,
  });

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Panel(
      child: e == null
          ? const EmptyState(
              icon: AppIcons.upcoming,
              title: 'Select an event',
              message: 'Pick an event to set a reminder or add it to your '
                  'calendar.',
              compact: true,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventHeader(e),
                const SizedBox(height: Spacing.lg),
                if (!e.isPast) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: reminderOn,
                    title: const Text('Remind me'),
                    // On native we schedule a real OS notification at 9am on
                    // the day; on web it's a browser confirmation only.
                    subtitle: const Text(kIsWeb
                        ? 'Browser notification'
                        : 'Notification at 9am on the day'),
                    onChanged: onToggleReminder,
                  ),
                  const SizedBox(height: Spacing.sm),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: onAddToGoogle,
                    icon: const Icon(AppIcons.calendar, size: 18),
                    label: const Text('Add to Google Calendar'),
                  ),
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/course_names.dart';
import 'image_export.dart';
import 'schedule_calendar.dart';
import 'section_catalog_model.dart';
import 'section_widgets.dart';
import 'simulator_engine.dart';

/// Full-screen detail for one built schedule: status, the weekly calendar grid
/// with a course legend, the per-class list, and any trade-offs. Exportable as
/// an image.
class ScheduleDetailPage extends StatefulWidget {
  final ScheduleCandidate candidate;
  final int rank;
  final String? trimester;

  const ScheduleDetailPage({
    super.key,
    required this.candidate,
    required this.rank,
    this.trimester,
  });

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  final _calKey = GlobalKey();
  bool _exporting = false;

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    var ok = false;
    final ctx = _calKey.currentContext;
    if (ctx != null && ctx.mounted) {
      final b = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (b != null) {
        ok = await exportBoundaryPng(b,
            filename:
                'open-campus-schedule-${widget.rank}-${widget.trimester ?? "cal"}.png');
      }
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Calendar image saved.'
          : 'Couldn’t export. Try a screenshot instead.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;

    // Course legend order = the calendar's first-seen colour assignment.
    final courseOrder = <String, String>{}; // code -> name
    for (final p in c.picks) {
      courseOrder.putIfAbsent(p.formalCode, () => p.courseName ?? p.formalCode);
    }

    return PageScaffold(
      title: 'Schedule ${widget.rank}',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exporting ? null : _export,
        icon: _exporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(AppIcons.export),
        label: const Text('Export'),
      ),
      body: Stacked(
        gap: Spacing.lg,
        children: [
          Reveal(child: _StatusHeader(c)),
          Reveal(
            index: 1,
            child: RepaintBoundary(
              key: _calKey,
              child: Panel(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 460,
                      child: ScheduleCalendarView(candidate: c),
                    ),
                    const SizedBox(height: Spacing.md),
                    _Legend(courseOrder: courseOrder),
                    const SizedBox(height: Spacing.xs),
                    Text('Open Campus · ${widget.trimester ?? "schedule"}',
                        style: context.text.labelSmall
                            ?.copyWith(color: context.scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Reveal(index: 2, child: _ClassList(c)),
          if (c.sacrifices.isNotEmpty)
            InfoNote(
              title: 'Trade-offs',
              tone: StatusTone.warning,
              icon: AppIcons.warning,
              text: c.sacrifices.join('\n'),
            ),
        ],
      ),
    );
  }
}

StatusTone scheduleTone(ScheduleCandidate c) => c.isPerfect
    ? StatusTone.accent
    : (c.conflictFree ? StatusTone.success : StatusTone.danger);

String scheduleLabel(ScheduleCandidate c) => c.isPerfect
    ? 'Perfect match'
    : (c.conflictFree ? 'Conflict-free' : 'Has a time clash');

class _StatusHeader extends StatelessWidget {
  final ScheduleCandidate c;
  const _StatusHeader(this.c);

  @override
  Widget build(BuildContext context) {
    final days = c.daysOnCampus.length;
    return Row(
      children: [
        StatusBadge(scheduleLabel(c), tone: scheduleTone(c)),
        const Spacer(),
        Text(
          days == 0 ? '—' : '$days day${days == 1 ? "" : "s"} / week',
          style: context.text.labelMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Map<String, String> courseOrder;
  const _Legend({required this.courseOrder});

  @override
  Widget build(BuildContext context) {
    final series = context.palette.series;
    var i = 0;
    return Wrap(
      spacing: Spacing.lg,
      runSpacing: Spacing.xs,
      children: [
        for (final entry in courseOrder.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(series[i++ % series.length], size: 10),
              const SizedBox(width: Spacing.xs + Spacing.xxs),
              Text(entry.value,
                  style: context.text.labelMedium
                      ?.copyWith(color: context.scheme.onSurface)),
            ],
          ),
      ],
    );
  }
}

class _ClassList extends StatelessWidget {
  final ScheduleCandidate c;
  const _ClassList(this.c);

  @override
  Widget build(BuildContext context) {
    return RowGroup(
      title: 'Your classes',
      children: [for (final p in c.picks) _ClassRow(p)],
    );
  }
}

class _ClassRow extends StatelessWidget {
  final PickedSection pick;
  const _ClassRow(this.pick);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final s = pick.section;
    final scheduled = s.section != null && s.schedule.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CourseName(
                      code: pick.formalCode,
                      title: pick.courseName,
                      extra: scheduled
                          ? (s.facultyName ?? s.facultyCode ?? 'Faculty TBA')
                          : null,
                    ),
                  ],
                ),
              ),
              if (s.section != null) ...[
                const SizedBox(width: Spacing.md),
                StatusBadge('Sec ${s.section}', tone: StatusTone.accent),
              ],
            ],
          ),
          const SizedBox(height: Spacing.xs),
          if (!scheduled)
            Text('No fitting section / no fixed time',
                style: context.text.bodySmall?.copyWith(color: p.dangerInk))
          else
            for (final slot in s.schedule)
              Text(
                '${shortDay(slot.day)} · ${to12h(slot.start)} – ${to12h(slot.end)}'
                '${s.room != null ? " · Room ${s.room}" : ""}',
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
        ],
      ),
    );
  }
}

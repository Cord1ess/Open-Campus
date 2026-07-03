import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import 'image_export.dart';
import 'schedule_calendar.dart';
import 'section_catalog_model.dart';
import 'simulator_engine.dart';

/// Full-screen detail for one built schedule: the weekly calendar grid, a
/// course legend, the per-class list, and any trade-offs. Exportable as an image.
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
    final scheme = context.scheme;
    final c = widget.candidate;

    // Course color legend, matching the calendar's per-course palette order.
    final courseOrder = <String, String>{}; // code -> name
    for (final p in c.picks) {
      courseOrder.putIfAbsent(p.formalCode, () => p.courseName ?? p.formalCode);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exporting ? null : _export,
        icon: _exporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.ios_share),
        label: const Text('Export'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverCollapsingAppBar(title: 'Schedule ${widget.rank}'),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              _StatusHeader(c),
              const SizedBox(height: Spacing.md),
              // The calendar itself, wrapped so export captures grid + legend.
              RepaintBoundary(
                key: _calKey,
                child: Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
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
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              _ClassList(c),
              if (c.sacrifices.isNotEmpty) ...[
                const SizedBox(height: Spacing.lg),
                _Tradeoffs(c.sacrifices),
              ],
              const SizedBox(height: 120),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final ScheduleCandidate c;
  const _StatusHeader(this.c);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final perfect = c.isPerfect;
    final accent = perfect
        ? scheme.primary
        : (c.conflictFree ? scheme.secondary : scheme.error);
    final label = perfect
        ? 'Perfect match'
        : c.conflictFree
            ? 'Conflict-free'
            : 'Has a time clash';
    return Row(
      children: [
        Icon(
            perfect
                ? Icons.verified
                : c.conflictFree
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
            color: accent,
            size: 20),
        const SizedBox(width: Spacing.sm),
        Text(label,
            style: context.text.titleMedium
                ?.copyWith(color: accent, fontWeight: FontWeight.w800)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            c.daysOnCampus.isEmpty
                ? '—'
                : '${c.daysOnCampus.length} day${c.daysOnCampus.length == 1 ? "" : "s"} / week',
            style: context.text.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
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
    final scheme = context.scheme;
    // Mirror the calendar palette order (first-seen course = first color).
    final palette = [
      scheme.primary,
      scheme.tertiary,
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    var i = 0;
    return Wrap(
      spacing: Spacing.md,
      runSpacing: Spacing.xs,
      children: [
        for (final entry in courseOrder.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: palette[i++ % palette.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(entry.value,
                  style: context.text.labelSmall?.copyWith(
                      color: scheme.onSurface, fontWeight: FontWeight.w600)),
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
    final scheme = context.scheme;
    return SectionCard(
      title: 'Your classes',
      icon: Icons.list_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < c.picks.length; i++) ...[
            if (i > 0) Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _ClassRow(c.picks[i]),
          ],
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  final PickedSection pick;
  const _ClassRow(this.pick);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final s = pick.section;
    final scheduled = s.section != null && s.schedule.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(pick.courseName ?? pick.formalCode,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (s.section != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Section ${s.section}',
                    style: context.text.labelSmall?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
        const SizedBox(height: 3),
        if (!scheduled)
          Text('No fitting section / no fixed time',
              style: context.text.bodySmall?.copyWith(color: scheme.error))
        else ...[
          Text(s.facultyName ?? s.facultyCode ?? 'Faculty TBA',
              style: context.text.bodyMedium),
          const SizedBox(height: 2),
          for (final slot in s.schedule)
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(
                  '${slot.day}  ·  ${to12h(slot.start)} – ${to12h(slot.end)}'
                  '${s.room != null ? "  ·  Room ${s.room}" : ""}',
                  style: context.text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _Tradeoffs extends StatelessWidget {
  final List<String> sacrifices;
  const _Tradeoffs(this.sacrifices);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: 'Trade-offs',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in sacrifices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.remove_circle_outline,
                      size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(s,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurface, height: 1.35)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

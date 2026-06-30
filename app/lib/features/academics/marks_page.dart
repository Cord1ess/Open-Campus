import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../common/collapsing_title.dart';
import 'marks_model.dart';

/// Strips a leading "[261] " term code from a trimester label. Compiled once.
final _termCodePrefix = RegExp(r'^\[(\d+)\]\s*');

/// Item-wise marks: pick a trimester, then each course loads INDEPENDENTLY and
/// pops in as its marks arrive (the course list comes first, then each course's
/// table fills in). Each course shows a UCAM-style marks table, not progress bars.
class MarksPage extends ConsumerStatefulWidget {
  const MarksPage({super.key});

  @override
  ConsumerState<MarksPage> createState() => _MarksPageState();
}

class _MarksPageState extends ConsumerState<MarksPage> {
  String? _trimester;

  @override
  Widget build(BuildContext context) {
    final trimesters = ref.watch(markTrimestersProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverCollapsingAppBar(title: 'Marks'),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              trimesters.when(
                loading: () =>
                    const Center(child: LoadingIndicator(label: 'Loading trimesters…')),
                error: (e, _) => StateMessage(
                  icon: Icons.cloud_off,
                  title: 'Couldn\'t load trimesters',
                  subtitle: '$e',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(markTrimestersProvider),
                ),
                data: (opts) => _TrimesterPicker(
                  options: opts,
                  selected: _trimester,
                  onPick: (v) => setState(() => _trimester = v),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              if (_trimester == null)
                const StateMessage(
                  icon: Icons.touch_app_outlined,
                  title: 'Pick a trimester',
                  subtitle: 'Choose a trimester above to see its marks.',
                )
              else
                _MarksList(trimester: _trimester!),
              const SizedBox(height: 96),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TrimesterPicker extends StatelessWidget {
  final List<TrimesterOption> options;
  final String? selected;
  final ValueChanged<String> onPick;
  const _TrimesterPicker({
    required this.options,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const StateMessage(
          icon: Icons.event_busy_outlined, title: 'No trimesters available');
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (_, i) {
          final o = options[i];
          final sel = o.value == selected;
          final scheme = context.scheme;
          return SpringTap(
            onTap: () => onPick(o.value),
            borderRadius: BorderRadius.circular(Radii.full),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: sel ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
              alignment: Alignment.center,
              child: Text(
                o.label.replaceFirst(_termCodePrefix, ''),
                style: context.text.labelLarge?.copyWith(
                  color: sel ? onAccent(scheme.primary) : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Loads the course LIST for the trimester, then renders one card per course
/// that independently fetches and pops in its own marks.
class _MarksList extends ConsumerWidget {
  final String trimester;
  const _MarksList({required this.trimester});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(markCoursesProvider(trimester));
    return courses.when(
      loading: () => const Center(
          child: LoadingIndicator(label: 'Finding your courses…')),
      error: (e, _) => StateMessage(
        icon: Icons.cloud_off,
        title: 'Couldn\'t load courses',
        subtitle: '$e',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(markCoursesProvider(trimester)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const StateMessage(
            icon: Icons.assignment_outlined,
            title: 'No courses',
            subtitle: 'No courses found for this trimester.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(height: Spacing.lg),
              _CourseCard(trimester: trimester, course: list[i]),
            ],
          ],
        );
      },
    );
  }
}

/// One course card — watches its own per-course provider and fills in when its
/// marks arrive, so courses pop in independently as they load.
class _CourseCard extends ConsumerWidget {
  final String trimester;
  final TrimesterOption course;
  const _CourseCard({required this.trimester, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final key = (trimester: trimester, course: course.value);
    final marks = ref.watch(markCourseProvider(key));
    // Course code/name from the dropdown label, e.g. "CSE 2217: Data Structure".
    final label = course.label;
    final codeMatch =
        RegExp(r'^([A-Z]{2,4}\s*\d{3,4})').firstMatch(label);
    final code = codeMatch?.group(1) ?? label;

    return SectionCard(
      title: code,
      icon: Icons.assignment_turned_in_outlined,
      trailing: marks.maybeWhen(
        data: (cm) => cm?.totalObtained != null
            ? _TotalChip(cm!.totalObtained!, cm.totalMax)
            : null,
        orElse: () => null,
      ),
      child: marks.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: Spacing.sm),
          child: LoadingIndicator(size: 28, pad: Spacing.sm),
        ),
        error: (e, _) => Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: scheme.error),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text('Couldn\'t load this course.',
                  style: context.text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () => ref.invalidate(markCourseProvider(key)),
              child: const Text('Retry'),
            ),
          ],
        ),
        data: (cm) {
          if (cm == null) {
            return Text('No marks entered yet for this course.',
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant));
          }
          return _CourseMarksView(cm, fallbackTitle: label);
        },
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  final double obtained;
  final double? max;
  const _TotalChip(this.obtained, this.max);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${obtained.toStringAsFixed(2)}'
        '${max != null ? ' / ${max!.toStringAsFixed(0)}' : ''}',
        style: context.text.labelMedium?.copyWith(
            color: onAccent(scheme.primary), fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// UCAM-style marks table: a row per component (name | obtained | max) and a
/// final Total row. No progress bars.
class _CourseMarksView extends StatelessWidget {
  final CourseMarks c;
  final String fallbackTitle;
  const _CourseMarksView(this.c, {required this.fallbackTitle});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final title = c.title.isNotEmpty ? c.title : fallbackTitle;
    final pct = (c.totalMax != null && c.totalMax! > 0 && c.totalObtained != null)
        ? c.totalObtained! / c.totalMax! * 100
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        if (c.totalClass != null) ...[
          const SizedBox(height: 4),
          Text(
            'Attendance: ${c.present ?? 0}/${c.totalClass} classes '
            '(${c.attendancePct.toStringAsFixed(0)}%)',
            style: context.text.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: Spacing.md),
        // Table.
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header row.
              const _TableRow(
                cells: ['Assessment', 'Marks', 'Out of'],
                header: true,
              ),
              for (final comp in c.components)
                _TableRow(cells: [
                  comp.name,
                  comp.obtained?.toStringAsFixed(2) ?? '—',
                  comp.max?.toStringAsFixed(2) ?? '—',
                ]),
              if (c.totalObtained != null)
                _TableRow(
                  cells: [
                    'Total',
                    c.totalObtained!.toStringAsFixed(2),
                    c.totalMax?.toStringAsFixed(2) ?? '—',
                  ],
                  total: true,
                ),
            ],
          ),
        ),
        if (pct != null) ...[
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Text('Percentage',
                  style: context.text.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text('${pct.toStringAsFixed(1)}%',
                  style: context.text.titleSmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ],
    );
  }
}

/// One table row: a wide left "Assessment" cell + two numeric columns. Styled by
/// [header]/[total]; all colours are theme-driven.
class _TableRow extends StatelessWidget {
  final List<String> cells; // [name, obtained, max]
  final bool header;
  final bool total;
  const _TableRow({required this.cells, this.header = false, this.total = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = header
        ? scheme.surfaceContainerHighest
        : total
            ? scheme.primary.withValues(alpha: 0.08)
            : Colors.transparent;
    final weight =
        header || total ? FontWeight.w800 : FontWeight.w500;
    final color = header
        ? scheme.onSurfaceVariant
        : total
            ? scheme.primary
            : scheme.onSurface;
    final style = (header ? context.text.labelSmall : context.text.bodyMedium)
        ?.copyWith(fontWeight: weight, color: color);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
            top: header
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant, width: 0.5)),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(header ? cells[0].toUpperCase() : cells[0], style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(cells[1],
                textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(cells[2],
                textAlign: TextAlign.right,
                style: style?.copyWith(
                    color: header || total
                        ? color
                        : scheme.onSurfaceVariant,
                    fontWeight: total ? FontWeight.w800 : FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

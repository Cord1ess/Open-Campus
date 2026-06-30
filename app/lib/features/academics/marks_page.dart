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
          const SliverCollapsingAppBar(title: 'Course Marks'),
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
            return Row(
              children: [
                Icon(Icons.hourglass_empty_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: Spacing.sm),
                Text('Marks not entered',
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            );
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

    // Total is conventionally out of 100. Show the obtained out of 100 (or the
    // reported max if UCAM gave a different denominator).
    final totalMax = c.totalMax ?? 100;

    // Each assessment becomes a COLUMN: (label, value). The last column is Total.
    final columns = <(String, String, bool)>[
      for (final comp in c.components)
        (
          comp.name,
          comp.obtained != null ? _fmt(comp.obtained!) : '—',
          false,
        ),
      if (c.totalObtained != null)
        ('Total', '${_fmt(c.totalObtained!)} / ${_fmt(totalMax)}', true),
    ];

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
        if (columns.isEmpty)
          // The course exists but no marks rows were published.
          _notEntered(context)
        else
          // Column-wise marks table: assessments left→right, value beneath each,
          // Total as the final column. Horizontally scrollable when it's wide.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns.length; i++)
                      _MarkColumn(
                        label: columns[i].$1,
                        value: columns[i].$2,
                        isTotal: columns[i].$3,
                        showDivider: i > 0,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _notEntered(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Text('Marks not entered',
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// One column of the marks table: an assessment label on top and its value
/// beneath. The Total column is accent-tinted. All colours are theme-driven.
class _MarkColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final bool showDivider;
  const _MarkColumn({
    required this.label,
    required this.value,
    required this.isTotal,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      constraints: BoxConstraints(minWidth: isTotal ? 96 : 76),
      decoration: BoxDecoration(
        color: isTotal ? scheme.primary.withValues(alpha: 0.08) : null,
        border: showDivider
            ? Border(left: BorderSide(color: scheme.outlineVariant, width: 0.5))
            : null,
      ),
      child: Column(
        children: [
          // Header cell.
          Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: 8),
            child: Text(label,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(
                    color: isTotal ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800)),
          ),
          // Value cell.
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: 12),
            child: Text(value,
                textAlign: TextAlign.center,
                style: (isTotal
                        ? context.text.titleSmall
                        : context.text.bodyMedium)
                    ?.copyWith(
                        color: isTotal ? scheme.primary : scheme.onSurface,
                        fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Trim a trailing ".00" but keep meaningful decimals (e.g. 4.50).
String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

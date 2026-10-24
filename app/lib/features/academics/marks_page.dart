import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import 'marks_model.dart';

/// Strips a leading "[261] " term code from a trimester label. Compiled once.
final _termCodePrefix = RegExp(r'^\[(\d+)\]\s*');

/// Item-wise marks: pick a trimester, then each course loads independently and
/// fills in as its marks arrive. Each course shows a small marks table.
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

    return PageScaffold(
      title: 'Course Marks',
      body: Stacked(
        children: [
          trimesters.when(
            loading: () => const LoadingState(label: 'Loading trimesters…'),
            error: (e, _) => ErrorState(
              title: 'Couldn’t load trimesters',
              message: '$e',
              onRetry: () => ref.invalidate(markTrimestersProvider),
            ),
            data: (opts) => opts.isEmpty
                ? const EmptyState(
                    icon: AppIcons.marks, title: 'No trimesters available')
                : SegmentedControl<String?>(
                    expand: false,
                    value: _trimester,
                    options: [
                      for (final o in opts)
                        SegmentOption<String?>(
                            o.value, o.label.replaceFirst(_termCodePrefix, '')),
                    ],
                    onChanged: (v) => setState(() => _trimester = v),
                  ),
          ),
          if (_trimester == null)
            const EmptyState(
              icon: AppIcons.marks,
              title: 'Pick a trimester',
              message: 'Choose a trimester above to see its marks.',
              compact: true,
            )
          else
            _MarksList(trimester: _trimester!),
        ],
      ),
    );
  }
}

/// Loads the course list for the trimester, then renders one section per course
/// that independently fetches its own marks.
class _MarksList extends ConsumerWidget {
  final String trimester;
  const _MarksList({required this.trimester});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(markCoursesProvider(trimester));
    return courses.when(
      loading: () => const LoadingState(label: 'Finding your courses…'),
      error: (e, _) => ErrorState(
        title: 'Couldn’t load courses',
        message: '$e',
        onRetry: () => ref.invalidate(markCoursesProvider(trimester)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: AppIcons.marks,
            title: 'No courses',
            message: 'No courses found for this trimester.',
          );
        }
        return ResponsiveGrid(
          maxColumns: 2,
          stretch: false,
          spacing: Spacing.xl,
          runSpacing: Spacing.xl,
          children: [
            for (final c in list) _CourseSection(trimester: trimester, course: c),
          ],
        );
      },
    );
  }
}

/// One course — watches its own per-course provider and fills in when its marks
/// arrive, so courses appear independently as they load.
class _CourseSection extends ConsumerWidget {
  final String trimester;
  final TrimesterOption course;
  const _CourseSection({required this.trimester, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (trimester: trimester, course: course.value);
    final marks = ref.watch(markCourseProvider(key));
    // Course code from the dropdown label, e.g. "CSE 2217: Data Structure".
    final label = course.label;
    final codeMatch = RegExp(r'^([A-Z]{2,4}\s*\d{3,4})').firstMatch(label);
    final code = codeMatch?.group(1) ?? label;

    final total = marks.maybeWhen(
      data: (cm) => cm?.totalObtained != null
          ? StatusBadge(
              'Total ${_fmt(cm!.totalObtained!)} / ${_fmt(cm.totalMax ?? 100.0)}',
              tone: StatusTone.accent)
          : null,
      orElse: () => null,
    );

    return Section(
      title: code,
      trailing: total,
      child: marks.when(
        loading: () => const LoadingState(verticalPadding: Spacing.md),
        error: (e, _) => InfoNote(
          tone: StatusTone.danger,
          icon: AppIcons.error,
          text: 'Couldn’t load this course.',
          action: TextButton(
            onPressed: () => ref.invalidate(markCourseProvider(key)),
            child: const Text('Retry'),
          ),
        ),
        data: (cm) {
          if (cm == null) {
            return const InfoNote(
                icon: AppIcons.pending, text: 'Marks not entered yet.');
          }
          return _CourseMarksView(cm, fallbackTitle: label);
        },
      ),
    );
  }
}

/// Course title, attendance line, and a marks table (component | marks) with a
/// Total row.
class _CourseMarksView extends StatelessWidget {
  final CourseMarks c;
  final String fallbackTitle;
  const _CourseMarksView(this.c, {required this.fallbackTitle});

  @override
  Widget build(BuildContext context) {
    final title = c.title.isNotEmpty ? c.title : fallbackTitle;
    final totalMax = c.totalMax ?? 100.0;

    final rows = <List<String>>[
      for (final comp in c.components)
        [comp.name, comp.obtained != null ? _fmt(comp.obtained!) : '—'],
      if (c.totalObtained != null)
        ['Total', '${_fmt(c.totalObtained!)} / ${_fmt(totalMax)}'],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty) Text(title, style: context.text.bodySmall),
        if (c.totalClass != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xxs),
            child: Text(
              'Attendance ${c.present ?? 0}/${c.totalClass} classes '
              '(${c.attendancePct.toStringAsFixed(0)}%)',
              style: context.text.bodySmall,
            ),
          ),
        const SizedBox(height: Spacing.md),
        if (rows.isEmpty)
          const InfoNote(icon: AppIcons.pending, text: 'Marks not entered yet.')
        else
          SimpleTable(
            columns: const ['Assessment', 'Marks'],
            rows: rows,
            emphasizeLast: c.totalObtained != null,
          ),
      ],
    );
  }
}

/// Trim a trailing ".00" but keep meaningful decimals (e.g. 4.50).
String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

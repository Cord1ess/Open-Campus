import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/course_names.dart';
import 'section_catalog_model.dart';

/// Short day label, e.g. "Saturday" -> "Sat".
String shortDay(String day) => day.length >= 3 ? day.substring(0, 3) : day;

/// Credits without a trailing ".0" (3.0 -> "3", 1.5 -> "1.5").
String _credits(double c) =>
    c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toString();

/// Compact "Sat & Tue · 8:30 AM – 9:50 AM" summary of a section's schedule.
String scheduleSummary(CatalogSection s) {
  if (s.schedule.isEmpty) return 'No fixed time';
  final days = s.days.map(shortDay).join(' & ');
  final first = s.schedule.first;
  return '$days · ${to12h(first.start)} – ${to12h(first.end)}';
}

/// One course with all its sections: a section heading (course name, count
/// summary), the code + credits line, then a bordered group of [SectionRow]s.
/// Optionally each section is selectable (simulator's manual pick).
class CourseSectionsCard extends StatelessWidget {
  final CatalogCourse course;
  final void Function(CatalogSection)? onPickSection;
  final String? selectedSection;

  const CourseSectionsCard({
    super.key,
    required this.course,
    this.onPickSection,
    this.selectedSection,
  });

  @override
  Widget build(BuildContext context) {
    final sections = course.sections;
    final facultyCount = course.facultyByCode.length;
    final credits = course.credits != null
        ? '${_credits(course.credits!)} credit${course.credits == 1 ? "" : "s"}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CourseName(
                  code: course.formalCode,
                  title: course.name,
                  extra: credits,
                  titleStyle: context.text.titleLarge,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child:
                    StatusBadge('${sections.length} sec · $facultyCount fac'),
              ),
            ],
          ),
        ),
        if (sections.isEmpty)
          Text('No sections listed for this course.',
              style: context.text.bodySmall)
        else
          RowGroup(
            children: [
              for (final s in sections)
                SectionRow(
                  section: s,
                  selected:
                      selectedSection != null && s.section == selectedSection,
                  onTap: onPickSection == null ? null : () => onPickSection!(s),
                ),
            ],
          ),
      ],
    );
  }
}

/// One section line: section badge, faculty, schedule + room, capacity, and a
/// radio-style indicator when selectable.
class SectionRow extends StatelessWidget {
  final CatalogSection section;
  final bool selected;
  final VoidCallback? onTap;

  const SectionRow({
    super.key,
    required this.section,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final sub = [
      scheduleSummary(section),
      if (section.room != null) 'Room ${section.room}',
    ].join(' · ');

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (section.capacity != null)
          Tooltip(
            message: 'Section size (not live seats)',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.seat, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: Spacing.xs),
                Text('${section.capacity}',
                    style: context.text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: tabularFigures)),
              ],
            ),
          ),
        if (onTap != null) ...[
          const SizedBox(width: Spacing.md),
          Icon(
            selected ? AppIcons.selected : AppIcons.unselected,
            size: 20,
            color: selected ? p.accentInk : scheme.outline,
          ),
        ],
      ],
    );

    return ListRow(
      leading:
          StatusBadge('Sec ${section.section ?? '?'}', tone: StatusTone.accent),
      title: section.facultyName ?? section.facultyCode ?? 'TBA',
      subtitle: sub,
      trailing: trailing,
      chevron: false,
      onTap: onTap,
    );
  }
}

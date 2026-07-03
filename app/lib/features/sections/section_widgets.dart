import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import 'section_catalog_model.dart';

/// Short day label, e.g. "Saturday" -> "Sat". Keeps the schedule chips compact.
String shortDay(String day) => day.length >= 3 ? day.substring(0, 3) : day;

/// Credits without a trailing ".0" (3.0 -> "3", 1.5 -> "1.5").
String _credits(double c) =>
    c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toString();

/// Compact "Sat & Tue · 8:30–9:50 AM" summary of a section's schedule, using a
/// friendly 12-hour clock.
String scheduleSummary(CatalogSection s) {
  if (s.schedule.isEmpty) return 'No fixed time';
  final days = s.days.map(shortDay).join(' & ');
  // Sections almost always share one time across their days; show the first.
  final first = s.schedule.first;
  return '$days · ${to12h(first.start)} – ${to12h(first.end)}';
}

/// A card for one course, listing all its sections. Used by both "Your
/// Sections" (browse) and can be embedded elsewhere. Optionally each section is
/// tappable (for the simulator's manual pick), with a check on the selected one.
class CourseSectionsCard extends StatelessWidget {
  final CatalogCourse course;

  /// If provided, sections are tappable and [selectedSection] is highlighted.
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
    final scheme = context.scheme;
    final sections = course.sections;
    final facultyCount = course.facultyByCode.length;

    return SectionCard(
      // Lead with the human-readable course NAME; the code is secondary.
      title: course.name ?? course.formalCode,
      icon: Icons.menu_book_outlined,
      trailing: Text(
        '${sections.length} sec · $facultyCount fac',
        style: context.text.labelMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The code + credits, small, under the name.
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text(
              course.credits != null
                  ? '${course.formalCode}  ·  ${_credits(course.credits!)} credit'
                      '${course.credits == 1 ? "" : "s"}'
                  : course.formalCode,
              style: context.text.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (sections.isEmpty)
            Text('No sections listed for this course.',
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant))
          else
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0)
                Divider(height: Spacing.md, color: scheme.outlineVariant),
              SectionRow(
                section: sections[i],
                selected: selectedSection != null &&
                    sections[i].section == selectedSection,
                onTap: onPickSection == null
                    ? null
                    : () => onPickSection!(sections[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// One section line: section letter, faculty, schedule, room, capacity.
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
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SectionBadge(section.section ?? '?', selected: selected),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.facultyName ?? section.facultyCode ?? 'TBA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.schedule, size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      scheduleSummary(section),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (section.room != null) ...[
                    const SizedBox(width: Spacing.sm),
                    Icon(Icons.meeting_room_outlined,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(section.room!,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        _CapacityTag(section.capacity),
        if (onTap != null) ...[
          const SizedBox(width: Spacing.xs),
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ],
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: content,
      ),
    );
  }
}

/// A prominent "SECTION / A" chip. Students pick a section first, so the
/// section letter is the most important thing to spot — this makes it pop.
class _SectionBadge extends StatelessWidget {
  final String label;
  final bool selected;
  const _SectionBadge(this.label, {this.selected = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final onColor = selected ? scheme.onPrimary : scheme.primary;
    return Container(
      constraints: const BoxConstraints(minWidth: 46),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary
            : scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SEC',
              style: context.text.labelSmall?.copyWith(
                  color: onColor.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  fontSize: 8,
                  letterSpacing: 0.5,
                  height: 1.0)),
          Text(label,
              style: context.text.titleMedium?.copyWith(
                  color: onColor, fontWeight: FontWeight.w900, height: 1.1)),
        ],
      ),
    );
  }
}

/// The section's capacity (its size), explicitly NOT live availability.
class _CapacityTag extends StatelessWidget {
  final int? capacity;
  const _CapacityTag(this.capacity);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    if (capacity == null) return const SizedBox.shrink();
    return Tooltip(
      message: 'Section size (not live seats)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_seat_outlined,
                size: 12, color: scheme.onSurfaceVariant),
            const SizedBox(width: 3),
            Text('$capacity',
                style: context.text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../academics/advising_model.dart';
import '../common/collapsing_title.dart';
import 'schedule_detail_page.dart';
import 'section_catalog_model.dart';
import 'section_widgets.dart';
import 'simulator_engine.dart';

/// Selection Simulator: by default it schedules the courses you pre-advised
/// (marked Taken). You can add more via a dropdown, set faculty priority (by
/// name), preferred hours, days to keep free, and compactness, then Calculate
/// ranked conflict-free combinations — with best-partial options when nothing
/// fits everything. Results can be exported as an image.
class SimulatorPage extends StatefulWidget {
  final SectionCatalogData catalog;
  final AdvisingData? advising;

  const SimulatorPage({super.key, required this.catalog, this.advising});

  @override
  State<SimulatorPage> createState() => _SimulatorPageState();
}

class _SimulatorPageState extends State<SimulatorPage> {
  final Map<String, CatalogCourse> _selected = {};
  final Map<String, List<String>> _facultyPrefs = {};

  bool _preferFewerDays = true;
  TimeOfDay? _earliest;
  TimeOfDay? _latest;
  final Set<String> _avoidDays = {};

  List<ScheduleCandidate>? _results;

  @override
  void initState() {
    super.initState();
    // Default selection: the courses you PRE-ADVISED (Taken), that exist in the
    // catalog — not the full offered list.
    for (final c in widget.advising?.taken ?? const <OfferedCourse>[]) {
      final code = c.code;
      if (code == null) continue;
      final found = widget.catalog.courseByCode(code);
      if (found != null) _selected[found.formalCode] = found;
    }
  }

  void _run() {
    final wanted = <CoursePreference>[];
    for (final entry in _selected.entries) {
      wanted.add(CoursePreference(
        formalCode: entry.key,
        course: entry.value,
        preferredFacultyCodes: _facultyPrefs[entry.key] ?? const [],
      ));
    }
    final prefs = SimulatorPreferences(
      preferFewerDays: _preferFewerDays,
      timeWindow: (_earliest != null || _latest != null)
          ? TimeWindow(
              earliestMin:
                  (_earliest?.hour ?? 0) * 60 + (_earliest?.minute ?? 0),
              latestMin: _latest != null
                  ? _latest!.hour * 60 + _latest!.minute
                  : 24 * 60,
            )
          : null,
      avoid: [
        for (final day in _avoidDays)
          AvoidBlock(day: day, startMin: 0, endMin: 24 * 60),
      ],
    );
    final engine = SimulatorEngine(wanted: wanted, prefs: prefs);
    setState(() => _results = engine.build(limit: 12));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _run,
              icon: const Icon(Icons.calculate_rounded),
              label: Text(_results == null ? 'Calculate' : 'Recalculate'),
            ),
      body: CustomScrollView(
        slivers: [
          const SliverCollapsingAppBar(title: 'Schedule Simulator'),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              FadeSlideIn(
                child: _CourseSelector(
                  catalog: widget.catalog,
                  selected: _selected,
                  onRemove: (course) => setState(() {
                    _selected.remove(course.formalCode);
                    _facultyPrefs.remove(course.formalCode);
                    _results = null;
                  }),
                  onAdd: (course) => setState(() {
                    _selected[course.formalCode] = course;
                    _results = null;
                  }),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              if (_selected.isNotEmpty) ...[
                FadeSlideIn(
                  delayMs: 60,
                  child: _FacultyPrefsCard(
                    selected: _selected,
                    facultyPrefs: _facultyPrefs,
                    onChanged: () => setState(() => _results = null),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                FadeSlideIn(
                  delayMs: 90,
                  child: _TimeAndDayCard(
                    earliest: _earliest,
                    latest: _latest,
                    avoidDays: _avoidDays,
                    preferFewerDays: _preferFewerDays,
                    onEarliest: (t) =>
                        setState(() { _earliest = t; _results = null; }),
                    onLatest: (t) =>
                        setState(() { _latest = t; _results = null; }),
                    onToggleDay: (d, on) => setState(() {
                      if (on) { _avoidDays.add(d); } else { _avoidDays.remove(d); }
                      _results = null;
                    }),
                    onFewerDays: (v) =>
                        setState(() { _preferFewerDays = v; _results = null; }),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.lg),
              if (_results != null)
                _ResultsSection(
                  results: _results!,
                  trimester: widget.catalog.trimester,
                ),
              const SizedBox(height: 120),
            ]),
          ),
        ],
      ),
    );
  }
}

// --- Course selector: your taken courses as removable chips + Add more -------

class _CourseSelector extends StatelessWidget {
  final SectionCatalogData catalog;
  final Map<String, CatalogCourse> selected;
  final void Function(CatalogCourse) onRemove;
  final void Function(CatalogCourse) onAdd;

  const _CourseSelector({
    required this.catalog,
    required this.selected,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: 'Courses to schedule',
      icon: Icons.checklist_rounded,
      trailing: Text('${selected.length}',
          style: context.text.labelLarge?.copyWith(
              color: scheme.primary, fontWeight: FontWeight.w800)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selected.isEmpty
                ? 'Add the courses you want to schedule.'
                : 'Your pre-advised courses. Remove any you don’t want, or add more.',
            style: context.text.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: Spacing.md),
          if (selected.isNotEmpty)
            Column(
              children: [
                for (final c in selected.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: _SelectedCourseChip(
                      course: c,
                      onRemove: () => onRemove(c),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: Spacing.sm),
          _AddCourseButton(
            catalog: catalog,
            alreadyIn: selected.keys.toSet(),
            onAdd: onAdd,
          ),
        ],
      ),
    );
  }
}

class _SelectedCourseChip extends StatelessWidget {
  final CatalogCourse course;
  final VoidCallback onRemove;
  const _SelectedCourseChip({required this.course, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.xs, Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.name ?? course.formalCode,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('${course.formalCode} · ${course.sections.length} sections',
                    style: context.text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// "Add more courses" — opens a searchable picker (by name) of catalog courses
/// not already selected.
class _AddCourseButton extends StatelessWidget {
  final SectionCatalogData catalog;
  final Set<String> alreadyIn;
  final void Function(CatalogCourse) onAdd;

  const _AddCourseButton({
    required this.catalog,
    required this.alreadyIn,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        // The sheet invokes onAdd itself (via Navigator.pop-with-result handled
        // inside), so there's no context use after an await out here.
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _CoursePickerSheet(
            catalog: catalog,
            alreadyIn: alreadyIn,
            onPick: onAdd,
          ),
        );
      },
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add more courses'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}

class _CoursePickerSheet extends StatefulWidget {
  final SectionCatalogData catalog;
  final Set<String> alreadyIn;
  final void Function(CatalogCourse) onPick;
  const _CoursePickerSheet({
    required this.catalog,
    required this.alreadyIn,
    required this.onPick,
  });

  @override
  State<_CoursePickerSheet> createState() => _CoursePickerSheetState();
}

class _CoursePickerSheetState extends State<_CoursePickerSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final query = _q.text.trim().toUpperCase();
    final available = widget.catalog.courses
        .where((c) => !widget.alreadyIn.contains(c.formalCode))
        .where((c) =>
            query.isEmpty ||
            (c.name?.toUpperCase().contains(query) ?? false) ||
            c.formalCode.toUpperCase().contains(query))
        .toList()
      ..sort((a, b) => (a.name ?? a.formalCode).compareTo(b.name ?? b.formalCode));

    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.lg,
        right: Spacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.lg,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a course',
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _q,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by course name',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Expanded(
              child: available.isEmpty
                  ? Center(
                      child: Text('No courses found',
                          style: context.text.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)))
                  : ListView.separated(
                      itemCount: available.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1, color: scheme.outlineVariant),
                      itemBuilder: (_, i) {
                        final c = available[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(c.name ?? c.formalCode,
                              style: context.text.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${c.formalCode} · ${c.sections.length} sections',
                              style: context.text.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant)),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () {
                            widget.onPick(c);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Faculty preferences (by NAME) -------------------------------------------

class _FacultyPrefsCard extends StatelessWidget {
  final Map<String, CatalogCourse> selected;
  final Map<String, List<String>> facultyPrefs;
  final VoidCallback onChanged;

  const _FacultyPrefsCard({
    required this.selected,
    required this.facultyPrefs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: 'Preferred faculty',
      icon: Icons.person_pin_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tap faculty in the order you want them. The number shows priority — '
            'the simulator tries your #1 first. Optional.',
            style: context.text.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: Spacing.md),
          for (final entry in selected.entries) ...[
            _CourseFacultyPicker(
              course: entry.value,
              chosen: facultyPrefs[entry.key] ?? const [],
              onChanged: (list) {
                if (list.isEmpty) {
                  facultyPrefs.remove(entry.key);
                } else {
                  facultyPrefs[entry.key] = list;
                }
                onChanged();
              },
            ),
            if (entry.key != selected.keys.last)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _CourseFacultyPicker extends StatelessWidget {
  final CatalogCourse course;
  final List<String> chosen;
  final ValueChanged<List<String>> onChanged;

  const _CourseFacultyPicker({
    required this.course,
    required this.chosen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final faculties = course.facultyByCode; // code -> name
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Course NAME leads; code is the small subtitle.
        Text(course.name ?? course.formalCode,
            style: context.text.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(course.formalCode,
            style: context.text.labelSmall
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final code in faculties.keys)
              _FacultyChip(
                name: faculties[code] ?? code,
                priority: chosen.indexOf(code),
                onTap: () {
                  final next = [...chosen];
                  if (next.contains(code)) {
                    next.remove(code);
                  } else {
                    next.add(code);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _FacultyChip extends StatelessWidget {
  final String name;
  final int priority; // -1 = not chosen, else 0-based rank
  final VoidCallback onTap;

  const _FacultyChip({
    required this.name,
    required this.priority,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final chosen = priority >= 0;
    return SpringTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chosen
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: chosen ? scheme.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chosen) ...[
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: scheme.primary, shape: BoxShape.circle),
                child: Text('${priority + 1}',
                    style: context.text.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10)),
              ),
              const SizedBox(width: 6),
            ],
            Text(name,
                style: context.text.labelMedium?.copyWith(
                    color: chosen ? scheme.primary : scheme.onSurface,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// --- Time window + days ------------------------------------------------------

class _TimeAndDayCard extends StatelessWidget {
  final TimeOfDay? earliest;
  final TimeOfDay? latest;
  final Set<String> avoidDays;
  final bool preferFewerDays;
  final ValueChanged<TimeOfDay?> onEarliest;
  final ValueChanged<TimeOfDay?> onLatest;
  final void Function(String, bool) onToggleDay;
  final ValueChanged<bool> onFewerDays;

  const _TimeAndDayCard({
    required this.earliest,
    required this.latest,
    required this.avoidDays,
    required this.preferFewerDays,
    required this.onEarliest,
    required this.onLatest,
    required this.onToggleDay,
    required this.onFewerDays,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    const days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday'];
    return SectionCard(
      title: 'Time & days',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'No class before',
                  value: earliest,
                  onPick: onEarliest,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _TimeField(
                  label: 'No class after',
                  value: latest,
                  onPick: onLatest,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Text('Days to keep free',
              style: context.text.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final d in days)
                FilterChip(
                  label: Text(shortDay(d)),
                  selected: avoidDays.contains(d),
                  onSelected: (on) => onToggleDay(d, on),
                  avatar: avoidDays.contains(d)
                      ? const Icon(Icons.block, size: 16)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Prefer fewer days on campus',
                style: context.text.bodyMedium),
            subtitle: Text('Bunch classes into as few days as possible',
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            value: preferFewerDays,
            onChanged: onFewerDays,
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onPick;

  const _TimeField(
      {required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.schedule, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onPick(null),
                ),
        ),
        child: Text(
          value?.format(context) ?? 'Any',
          style: context.text.bodyMedium?.copyWith(
              color:
                  value == null ? scheme.onSurfaceVariant : scheme.onSurface),
        ),
      ),
    );
  }
}

// --- Results (with export) ---------------------------------------------------

class _ResultsSection extends StatefulWidget {
  final List<ScheduleCandidate> results;
  final String? trimester;
  const _ResultsSection({required this.results, this.trimester});

  @override
  State<_ResultsSection> createState() => _ResultsSectionState();
}

class _ResultsSectionState extends State<_ResultsSection> {
  void _openDetail(int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScheduleDetailPage(
        candidate: widget.results[index],
        rank: index + 1,
        trimester: widget.trimester,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final results = widget.results;
    if (results.isEmpty) {
      return const StateMessage(
        icon: Icons.error_outline,
        title: 'No schedules',
        subtitle: 'None of the selected courses could be scheduled. Try '
            'removing a day-block or a course.',
      );
    }

    final anyPerfect = results.any((r) => r.isPerfect);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
            const SizedBox(width: Spacing.sm),
            Text('${results.length} schedules',
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          anyPerfect
              ? 'Tap any schedule to see it laid out on a weekly calendar.'
              : 'No schedule satisfies every preference conflict-free. These '
                  'are the closest — tap one to view its calendar and trade-offs.',
          style: context.text.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: Spacing.md),
        for (var i = 0; i < results.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: FadeSlideIn(
              delayMs: i.clamp(0, 6) * 40,
              child: _CandidateCard(
                candidate: results[i],
                rank: i + 1,
                trimester: widget.trimester,
                onTap: () => _openDetail(i),
              ),
            ),
          ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final ScheduleCandidate candidate;
  final int rank;
  final String? trimester;
  final VoidCallback? onTap;

  const _CandidateCard({
    required this.candidate,
    required this.rank,
    this.trimester,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final perfect = candidate.isPerfect;
    final accent = perfect
        ? scheme.primary
        : (candidate.conflictFree ? scheme.secondary : scheme.error);

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Radii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle),
                    child: Text('$rank',
                        style: context.text.labelMedium?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      perfect
                          ? 'Perfect match'
                          : candidate.conflictFree
                              ? 'Conflict-free'
                              : 'Has a clash',
                      style: context.text.titleSmall?.copyWith(
                          color: accent, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _DaysPill(candidate.daysOnCampus),
                ],
              ),
              const SizedBox(height: Spacing.md),
              for (final p in candidate.picks) _PickLine(p),
              if (candidate.sacrifices.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in candidate.sacrifices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.remove_circle_outline,
                                  size: 13, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(s,
                                    style: context.text.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.3)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Spacing.md),
              // Clear affordance that the card opens the calendar view.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.calendar_view_week,
                      size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text('View calendar',
                      style: context.text.labelLarge?.copyWith(
                          color: scheme.primary, fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right, size: 18, color: scheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickLine extends StatelessWidget {
  final PickedSection pick;
  const _PickLine(this.pick);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final s = pick.section;
    final unscheduled = s.section == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course NAME leads each line.
          Text(pick.courseName ?? pick.formalCode,
              style: context.text.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          if (unscheduled)
            Text('No section fits your constraints',
                style: context.text.bodySmall?.copyWith(color: scheme.error))
          else
            Row(
              children: [
                _MiniBadge('Sec ${s.section}'),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    // Faculty NAME + schedule.
                    '${s.facultyName ?? s.facultyCode ?? "TBA"} · ${scheduleSummary(s)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  const _MiniBadge(this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: context.text.labelSmall?.copyWith(
              color: scheme.primary, fontWeight: FontWeight.w800)),
    );
  }
}

class _DaysPill extends StatelessWidget {
  final List<String> days;
  const _DaysPill(this.days);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        days.isEmpty ? '—' : '${days.length} day${days.length == 1 ? "" : "s"}',
        style: context.text.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
      ),
    );
  }
}

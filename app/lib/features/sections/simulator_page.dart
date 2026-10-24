import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../academics/advising_model.dart';
import '../common/course_names.dart';
import 'schedule_detail_page.dart';
import 'section_catalog_model.dart';
import 'section_widgets.dart';
import 'simulator_engine.dart';

/// Selection Simulator: by default it schedules the courses you pre-advised
/// (marked Taken). You can add more, set faculty priority, preferred hours,
/// days to keep free, and compactness, then Calculate ranked conflict-free
/// combinations — with best-partial options when nothing fits everything.
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
    final selector = _CourseSelector(
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
    );

    final prefs = _selected.isEmpty
        ? null
        : Stacked(children: [
            _FacultyPrefsCard(
              selected: _selected,
              facultyPrefs: _facultyPrefs,
              onChanged: () => setState(() => _results = null),
            ),
            _TimeAndDayCard(
              earliest: _earliest,
              latest: _latest,
              avoidDays: _avoidDays,
              preferFewerDays: _preferFewerDays,
              onEarliest: (t) => setState(() {
                _earliest = t;
                _results = null;
              }),
              onLatest: (t) => setState(() {
                _latest = t;
                _results = null;
              }),
              onToggleDay: (d, on) => setState(() {
                if (on) {
                  _avoidDays.add(d);
                } else {
                  _avoidDays.remove(d);
                }
                _results = null;
              }),
              onFewerDays: (v) => setState(() {
                _preferFewerDays = v;
                _results = null;
              }),
            ),
          ]);

    return PageScaffold(
      title: 'Schedule Simulator',
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _run,
              icon: const Icon(AppIcons.gpaTool),
              label: Text(_results == null ? 'Calculate' : 'Recalculate'),
            ),
      body: Stacked(
        children: [
          Reveal(
            child: prefs == null
                ? selector
                : TwoColumn(left: selector, right: prefs, ratio: 0.45),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _results == null
                ? const SizedBox(width: double.infinity)
                : Reveal(
                    key: ValueKey(_results),
                    child: _ResultsSection(
                      results: _results!,
                      trimester: widget.catalog.trimester,
                    ),
                  ),
          ),
          // Room so the FAB never covers the last result.
          const SizedBox(height: Spacing.xxl),
        ],
      ),
    );
  }
}

// --- Course selector ---------------------------------------------------------

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
    return Section(
      title: 'Courses to schedule',
      trailing: Text('${selected.length}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected.isEmpty
                ? 'Add the courses you want to schedule.'
                : 'Your pre-advised courses. Remove any you don’t want, or add more.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Spacing.md),
          if (selected.isNotEmpty) ...[
            RowGroup(
              children: [
                for (final c in selected.values)
                  ListRow(
                    title: c.name ?? c.formalCode,
                    subtitle: '${c.formalCode} · ${c.sections.length} sections',
                    chevron: false,
                    trailing: IconButton(
                      icon: const Icon(AppIcons.clear, size: 18),
                      tooltip: 'Remove',
                      onPressed: () => onRemove(c),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
          ],
          OutlinedButton.icon(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _CoursePickerSheet(
                  catalog: catalog,
                  alreadyIn: selected.keys.toSet(),
                  onPick: onAdd,
                ),
              );
            },
            icon: const Icon(AppIcons.add, size: 18),
            label: const Text('Add courses'),
          ),
        ],
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
    final query = _q.text.trim().toUpperCase();
    final available = widget.catalog.courses
        .where((c) => !widget.alreadyIn.contains(c.formalCode))
        .where((c) =>
            query.isEmpty ||
            (c.name?.toUpperCase().contains(query) ?? false) ||
            c.formalCode.toUpperCase().contains(query))
        .toList()
      ..sort(
          (a, b) => (a.name ?? a.formalCode).compareTo(b.name ?? b.formalCode));

    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.lg,
        right: Spacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.lg,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a course', style: context.text.titleMedium),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _q,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by course name or code',
                prefixIcon: Icon(AppIcons.search),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Expanded(
              child: available.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.search,
                      title: 'No courses found',
                      compact: true)
                  : ListView.separated(
                      itemCount: available.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = available[i];
                        return ListRow(
                          title: c.name ?? c.formalCode,
                          subtitle:
                              '${c.formalCode} · ${c.sections.length} sections',
                          chevron: false,
                          trailing: Icon(AppIcons.add,
                              size: 20, color: context.palette.accentInk),
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

// --- Faculty preferences (by name) ------------------------------------------

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
    final keys = selected.keys.toList();
    return Section(
      title: 'Preferred faculty',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tap faculty in the order you want them. The number shows priority — '
            'the simulator tries your #1 first. Optional.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Spacing.md),
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const Divider(height: Spacing.xl),
            _CourseFacultyPicker(
              course: selected[keys[i]]!,
              chosen: facultyPrefs[keys[i]] ?? const [],
              onChanged: (list) {
                if (list.isEmpty) {
                  facultyPrefs.remove(keys[i]);
                } else {
                  facultyPrefs[keys[i]] = list;
                }
                onChanged();
              },
            ),
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
        CourseName(code: course.formalCode, title: course.name),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final code in faculties.keys)
              Builder(builder: (context) {
                final priority = chosen.indexOf(code);
                final name = faculties[code] ?? code;
                return FilterChip(
                  showCheckmark: false,
                  label: Text(priority >= 0 ? '${priority + 1} · $name' : name),
                  selected: priority >= 0,
                  onSelected: (_) {
                    final next = [...chosen];
                    if (next.contains(code)) {
                      next.remove(code);
                    } else {
                      next.add(code);
                    }
                    onChanged(next);
                  },
                );
              }),
          ],
        ),
      ],
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
    const days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday'];
    return Section(
      title: 'Time & days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormWidth(
            child: Row(
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
          ),
          const SizedBox(height: Spacing.lg),
          Text('Days to keep free', style: context.text.titleSmall),
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
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prefer fewer days on campus'),
            subtitle: const Text('Bunch classes into as few days as possible'),
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
          suffixIcon: value == null
              ? const Icon(AppIcons.time, size: 18)
              : IconButton(
                  icon: const Icon(AppIcons.clear, size: 18),
                  tooltip: 'Clear',
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

// --- Results -----------------------------------------------------------------

class _ResultsSection extends StatelessWidget {
  final List<ScheduleCandidate> results;
  final String? trimester;
  const _ResultsSection({required this.results, this.trimester});

  void _openDetail(BuildContext context, int index) {
    Navigator.of(context).push(appRoute(
      ScheduleDetailPage(
        candidate: results[index],
        rank: index + 1,
        trimester: trimester,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: AppIcons.warning,
        title: 'No schedules',
        message: 'None of the selected courses could be scheduled. Try '
            'removing a day-block or a course.',
      );
    }

    final anyPerfect = results.any((r) => r.isPerfect);
    return Section(
      title: '${results.length} schedule${results.length == 1 ? "" : "s"}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            anyPerfect
                ? 'Tap any schedule to see it laid out on a weekly calendar.'
                : 'No schedule satisfies every preference conflict-free. These '
                    'are the closest — tap one to view its calendar and trade-offs.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Spacing.md),
          ResponsiveGrid(
            maxColumns: 2,
            stretch: false,
            children: [
              for (var i = 0; i < results.length; i++)
                _CandidateCard(
                  candidate: results[i],
                  rank: i + 1,
                  onTap: () => _openDetail(context, i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final ScheduleCandidate candidate;
  final int rank;
  final VoidCallback? onTap;

  const _CandidateCard({
    required this.candidate,
    required this.rank,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final days = candidate.daysOnCampus.length;
    return Panel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('$rank',
                  style: context.text.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: tabularFigures)),
              const SizedBox(width: Spacing.sm),
              StatusBadge(scheduleLabel(candidate),
                  tone: scheduleTone(candidate)),
              const Spacer(),
              Text(
                days == 0 ? '—' : '$days day${days == 1 ? "" : "s"}',
                style: context.text.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          for (final p in candidate.picks) _PickLine(p),
          if (candidate.sacrifices.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            for (final s in candidate.sacrifices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text('− $s', style: context.text.bodySmall),
              ),
          ],
          const SizedBox(height: Spacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(AppIcons.routine, size: 18),
              label: const Text('View calendar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickLine extends StatelessWidget {
  final PickedSection pick;
  const _PickLine(this.pick);

  @override
  Widget build(BuildContext context) {
    final s = pick.section;
    final unscheduled = s.section == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourseName(code: pick.formalCode, title: pick.courseName),
          const SizedBox(height: Spacing.xxs),
          Text(
            unscheduled
                ? 'No section fits your constraints'
                : 'Sec ${s.section} · ${s.facultyName ?? s.facultyCode ?? "TBA"}'
                    ' · ${scheduleSummary(s)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
                color: unscheduled ? context.palette.dangerInk : null),
          ),
        ],
      ),
    );
  }
}

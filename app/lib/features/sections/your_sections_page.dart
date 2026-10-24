import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../academics/advising_model.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'section_catalog_model.dart';
import 'section_widgets.dart';
import 'simulator_page.dart';

/// "Section Selection": the shared section catalog, filtered to the courses the
/// student pre-advised (advising.taken) and joined against the catalog. A
/// toggle switches to browsing the whole catalog, grouped by subject and
/// expanded on demand so we never render ~1200 sections at once.
///
/// Seat numbers are CAPACITY (section size), not live availability.
class YourSectionsPage extends ConsumerStatefulWidget {
  const YourSectionsPage({super.key});

  @override
  ConsumerState<YourSectionsPage> createState() => _YourSectionsPageState();
}

class _YourSectionsPageState extends ConsumerState<YourSectionsPage> {
  bool _showAll = false;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sectionCatalogProvider.notifier).ensureLoaded();
      ref.read(advisingProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catState = ref.watch(sectionCatalogProvider);
    final advState = ref.watch(advisingProvider);

    return PageScaffold(
      title: 'Section Selection',
      onRefresh: () =>
          ref.read(sectionCatalogProvider.notifier).load(force: true),
      floatingActionButton: _buildFab(context, catState, advState),
      body: ResourceBody<SectionCatalogData>(
        state: catState,
        loadingLabel: 'Loading course sections…',
        errorTitle: 'Couldn’t load sections',
        onRetry: () =>
            ref.read(sectionCatalogProvider.notifier).load(force: true),
        builder: (catalog) => _Content(
          catalog: catalog,
          advising: advState is ResData<AdvisingData>
              ? advState.loaded.data
              : null,
          advisingLoading: advState is ResLoading<AdvisingData>,
          showAll: _showAll,
          search: _search,
          onToggleShowAll: (v) => setState(() => _showAll = v),
          onSearchChanged: () => setState(() {}),
        ),
      ),
    );
  }

  Widget? _buildFab(BuildContext context, ResourceState<SectionCatalogData> cat,
      ResourceState<AdvisingData> adv) {
    if (cat is! ResData<SectionCatalogData>) return null;
    return FloatingActionButton.extended(
      onPressed: () {
        final advising = adv is ResData<AdvisingData> ? adv.loaded.data : null;
        Navigator.of(context).push(appRoute(
          SimulatorPage(catalog: cat.loaded.data, advising: advising),
        ));
      },
      icon: const Icon(AppIcons.simulator),
      label: const Text('Plan schedule'),
    );
  }
}

class _Content extends StatelessWidget {
  final SectionCatalogData catalog;
  final AdvisingData? advising;
  final bool advisingLoading;
  final bool showAll;
  final TextEditingController search;
  final ValueChanged<bool> onToggleShowAll;
  final VoidCallback onSearchChanged;

  const _Content({
    required this.catalog,
    required this.advising,
    required this.advisingLoading,
    required this.showAll,
    required this.search,
    required this.onToggleShowAll,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    // "My courses" = the courses the student pre-advised (marked Taken) that
    // exist in the catalog.
    final myCourses = <CatalogCourse>[];
    final missing = <String>[];
    for (final c in advising?.taken ?? const <OfferedCourse>[]) {
      final code = c.code;
      if (code == null) continue;
      final found = catalog.courseByCode(code);
      if (found != null) {
        myCourses.add(found);
      } else {
        missing.add(c.title ?? code);
      }
    }
    final noPreAdvise = (advising?.taken ?? const []).isEmpty;
    final query = search.text.trim().toUpperCase();
    final trimester = catalog.trimester;

    return Stacked(
      gap: Spacing.lg,
      children: [
        InfoNote(
          title: trimester != null
              ? 'Course catalog · $trimester'
              : 'Course catalog',
          text: 'Plan your faculties and times here, then grab your seats on '
              'the official site. Seat numbers show each section’s size, not '
              'live availability.',
        ),
        FormWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedControl<bool>(
                value: showAll,
                onChanged: onToggleShowAll,
                options: [
                  SegmentOption(false, 'My courses (${myCourses.length})',
                      icon: AppIcons.profile,
                      enabled: !(noPreAdvise && !advisingLoading)),
                  SegmentOption(true, 'All (${catalog.courses.length})',
                      icon: AppIcons.course),
                ],
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: search,
                onChanged: (_) => onSearchChanged(),
                decoration: InputDecoration(
                  hintText: 'Search course name or code',
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(AppIcons.clear),
                          tooltip: 'Clear',
                          onPressed: () {
                            search.clear();
                            onSearchChanged();
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xs),
        if (showAll)
          _AllCoursesBrowser(catalog: catalog, query: query)
        else if (advisingLoading && myCourses.isEmpty)
          const LoadingState(label: 'Loading your pre-advised courses…')
        else if (noPreAdvise)
          EmptyState(
            icon: AppIcons.advising,
            title: 'No pre-advised courses yet',
            message:
                'Pre-advise your courses on UCAM first (mark them Taken). '
                'They’ll show here with their sections. Or browse all courses.',
            actionLabel: 'Browse all courses',
            onAction: () => onToggleShowAll(true),
          )
        else
          _MyCoursesList(myCourses: myCourses, query: query),
        if (!showAll && missing.isNotEmpty)
          InfoNote(
            text: 'Not in this catalog yet: ${missing.join(", ")}. The catalog '
                'may not cover every department — check the official site for '
                'these.',
          ),
      ],
    );
  }
}

/// The student's pre-advised courses (already a short list), filtered by search.
class _MyCoursesList extends StatelessWidget {
  final List<CatalogCourse> myCourses;
  final String query;
  const _MyCoursesList({required this.myCourses, required this.query});

  @override
  Widget build(BuildContext context) {
    final shown = query.isEmpty
        ? myCourses
        : myCourses.where((c) => _matches(c, query)).toList();
    if (shown.isEmpty) {
      return EmptyState(
        icon: AppIcons.search,
        title: 'No matches',
        message: 'None of your courses match “$query”.',
        compact: true,
      );
    }
    return ResponsiveGrid(
      maxColumns: 2,
      stretch: false,
      spacing: Spacing.xl,
      runSpacing: Spacing.xl,
      children: [for (final c in shown) CourseSectionsCard(course: c)],
    );
  }
}

/// The full catalog grouped by subject; each subject expands on demand. A
/// search flattens to matching courses across all subjects.
class _AllCoursesBrowser extends StatelessWidget {
  final SectionCatalogData catalog;
  final String query;
  const _AllCoursesBrowser({required this.catalog, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) {
      final hits = catalog.courses.where((c) => _matches(c, query)).toList()
        ..sort((a, b) => a.formalCode.compareTo(b.formalCode));
      if (hits.isEmpty) {
        return EmptyState(
          icon: AppIcons.search,
          title: 'No matches',
          message: 'No course matches “$query”.',
          compact: true,
        );
      }
      final shown = hits.length > 40 ? hits.sublist(0, 40) : hits;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveGrid(
            maxColumns: 2,
            stretch: false,
            spacing: Spacing.xl,
            runSpacing: Spacing.xl,
            children: [for (final c in shown) CourseSectionsCard(course: c)],
          ),
          if (hits.length > 40)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.md),
              child: Text(
                  'Showing first 40 of ${hits.length}. Refine your search.',
                  style: context.text.bodySmall),
            ),
        ],
      );
    }

    final groups = catalog.coursesBySubject;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : Spacing.sm),
            child: _SubjectTile(subject: groups[i].key, courses: groups[i].value),
          ),
      ],
    );
  }
}

/// A lazy, expandable subject group. Course cards build only on expand.
class _SubjectTile extends StatelessWidget {
  final String subject;
  final List<CatalogCourse> courses;
  const _SubjectTile({required this.subject, required this.courses});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        leading: StatusBadge(subject),
        title: Text(_subjectName(subject), style: context.text.titleSmall),
        subtitle: Text(
            '${courses.length} course${courses.length == 1 ? "" : "s"}',
            style: context.text.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.sm, Spacing.lg, Spacing.lg),
        children: [
          for (var i = 0; i < courses.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : Spacing.xl),
              child: CourseSectionsCard(course: courses[i]),
            ),
        ],
      ),
    );
  }
}

bool _matches(CatalogCourse c, String upperQuery) =>
    c.formalCode.toUpperCase().contains(upperQuery) ||
    (c.name?.toUpperCase().contains(upperQuery) ?? false);

/// A friendly name for common subject prefixes; falls back to the prefix.
String _subjectName(String prefix) => _subjectNames[prefix] ?? prefix;

const Map<String, String> _subjectNames = {
  'CSE': 'Computer Science',
  'EEE': 'Electrical & Electronic',
  'CE': 'Civil Engineering',
  'DS': 'Data Science',
  'ARCH': 'Architecture',
  'BUS': 'Business',
  'MGT': 'Management',
  'MKT': 'Marketing',
  'FIN': 'Finance',
  'ACT': 'Accounting',
  'AIS': 'Accounting Info Systems',
  'MIS': 'Management Info Systems',
  'ECO': 'Economics',
  'ECN': 'Economics',
  'ENG': 'English',
  'MATH': 'Mathematics',
  'PHY': 'Physics',
  'CHEM': 'Chemistry',
  'BIO': 'Biology',
  'STAT': 'Statistics',
  'LAW': 'Law',
  'MSJ': 'Media & Journalism',
  'GED': 'General Education',
  'GEN': 'General',
};

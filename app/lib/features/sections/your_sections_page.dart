import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../academics/advising_model.dart';
import '../common/collapsing_title.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'section_catalog_model.dart';
import 'section_widgets.dart';
import 'simulator_page.dart';

/// "Your Sections": the shared section catalog, filtered to the courses the
/// student PRE-ADVISED for next term (the ones marked "Taken" on the advising
/// page — i.e. advising.taken), joined against the catalog. A toggle switches to
/// browsing the whole catalog, grouped by subject and expanded on demand so we
/// never render ~1200 sections at once.
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

    return Scaffold(
      floatingActionButton: _buildFab(context, catState, advState),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(sectionCatalogProvider.notifier).load(force: true),
        child: CustomScrollView(
          slivers: [
            const SliverCollapsingAppBar(title: 'Section Selection'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (catState) {
                  ResLoading() => const SectionCard(
                      title: 'Loading catalog',
                      icon: Icons.grid_view_outlined,
                      child: CardSkeleton(label: 'Loading course sections…')),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn’t load sections',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () => ref
                          .read(sectionCatalogProvider.notifier)
                          .load(force: true),
                    ),
                  ResData(:final loaded) => _Content(
                      catalog: loaded.data,
                      advising: advState is ResData<AdvisingData>
                          ? advState.loaded.data
                          : null,
                      advisingLoading: advState is ResLoading<AdvisingData>,
                      showAll: _showAll,
                      search: _search,
                      onToggleShowAll: (v) => setState(() => _showAll = v),
                      onSearchChanged: () => setState(() {}),
                    ),
                },
                const SizedBox(height: 96),
              ]),
            ),
          ],
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
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SimulatorPage(
            catalog: cat.loaded.data,
            advising: advising,
          ),
        ));
      },
      icon: const Icon(Icons.calculate_outlined),
      label: const Text('Calculate'),
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
    // "My courses" = the courses the student PRE-ADVISED (marked Taken on the
    // advising page) that exist in the catalog. NOT the full offered list.
    final myCourses = <CatalogCourse>[];
    final missing = <String>[];
    for (final c in advising?.taken ?? const <OfferedCourse>[]) {
      final code = c.code;
      if (code == null) continue;
      final found = catalog.courseByCode(code);
      if (found != null) {
        myCourses.add(found);
      } else {
        missing.add(c.title ?? code); // show the NAME in the gap note
      }
    }
    final noPreAdvise = (advising?.taken ?? const []).isEmpty;

    final query = search.text.trim().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(child: _CatalogBanner(catalog)),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          delayMs: 60,
          child: _ScopeToggle(
            showAll: showAll,
            myCount: myCourses.length,
            allCount: catalog.courses.length,
            onChanged: onToggleShowAll,
            disabledMine: noPreAdvise && !advisingLoading,
          ),
        ),
        const SizedBox(height: Spacing.md),
        FadeSlideIn(
          delayMs: 90,
          child: TextField(
            controller: search,
            onChanged: (_) => onSearchChanged(),
            decoration: InputDecoration(
              hintText: 'Search course name or code',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        search.clear();
                        onSearchChanged();
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),

        if (showAll)
          _AllCoursesBrowser(catalog: catalog, query: query)
        else if (advisingLoading && myCourses.isEmpty)
          const SectionCard(
            title: 'Finding your courses',
            icon: Icons.person_search_outlined,
            child: CardSkeleton(label: 'Loading your pre-advised courses…'),
          )
        else if (noPreAdvise)
          FadeSlideIn(
            delayMs: 120,
            child: StateMessage(
              icon: Icons.assignment_late_outlined,
              title: 'No pre-advised courses yet',
              subtitle:
                  'Pre-advise your courses on UCAM first (mark them Taken). '
                  'They’ll show here with their sections. Or browse all courses.',
              actionLabel: 'Browse all courses',
              onAction: () => onToggleShowAll(true),
            ),
          )
        else
          _MyCoursesList(myCourses: myCourses, query: query),

        if (!showAll && missing.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          _MissingNote(missing),
        ],
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
      return StateMessage(
        icon: Icons.search_off,
        title: 'No matches',
        subtitle: 'None of your courses match “$query”.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: FadeSlideIn(
              delayMs: (i.clamp(0, 6) * 30),
              child: CourseSectionsCard(course: shown[i]),
            ),
          ),
      ],
    );
  }
}

/// The full catalog, grouped by subject (CSE, EEE, …). Each subject is a
/// collapsed tile that renders its courses only when expanded — so we never
/// build ~1200 sections up front. A search jumps straight to matching courses
/// across all subjects (auto-expanded).
class _AllCoursesBrowser extends StatelessWidget {
  final SectionCatalogData catalog;
  final String query;
  const _AllCoursesBrowser({required this.catalog, required this.query});

  @override
  Widget build(BuildContext context) {
    // With a search active, flatten to matching courses (expanded), so the user
    // isn't hunting through subject accordions.
    if (query.isNotEmpty) {
      final hits = catalog.courses.where((c) => _matches(c, query)).toList()
        ..sort((a, b) => a.formalCode.compareTo(b.formalCode));
      if (hits.isEmpty) {
        return StateMessage(
          icon: Icons.search_off,
          title: 'No matches',
          subtitle: 'No course matches “$query”.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < hits.length && i < 40; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: CourseSectionsCard(course: hits[i]),
            ),
          if (hits.length > 40)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text('Showing first 40 of ${hits.length}. Refine your search.',
                  style: context.text.labelSmall?.copyWith(
                      color: context.scheme.onSurfaceVariant)),
            ),
        ],
      );
    }

    final groups = catalog.coursesBySubject;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: _SubjectTile(subject: g.key, courses: g.value),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Text(subject,
                style: context.text.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: subject.length > 3 ? 9 : 11)),
          ),
          title: Text(_subjectName(subject),
              style: context.text.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          subtitle: Text('${courses.length} course${courses.length == 1 ? "" : "s"}',
              style: context.text.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          childrenPadding: const EdgeInsets.fromLTRB(
              Spacing.md, 0, Spacing.md, Spacing.md),
          children: [
            for (final c in courses)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: CourseSectionsCard(course: c),
              ),
          ],
        ),
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

/// Provenance banner: what trimester this catalog is + the "capacity not live
/// seats" caveat.
class _CatalogBanner extends StatelessWidget {
  final SectionCatalogData catalog;
  const _CatalogBanner(this.catalog);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final trimester = catalog.trimester;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  trimester != null
                      ? 'Course catalog · $trimester'
                      : 'Course catalog',
                  style: context.text.titleSmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Plan your faculties and times here, then grab your seats on the '
            'official site. Seat numbers show each section’s size, not live '
            'availability.',
            style: context.text.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Full-width segmented toggle sized for desktop and mobile alike.
class _ScopeToggle extends StatelessWidget {
  final bool showAll;
  final int myCount;
  final int allCount;
  final ValueChanged<bool> onChanged;
  final bool disabledMine;

  const _ScopeToggle({
    required this.showAll,
    required this.myCount,
    required this.allCount,
    required this.onChanged,
    required this.disabledMine,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    Widget seg(bool value, IconData icon, String label) {
      final selected = showAll == value;
      final enabled = !(value == false && disabledMine);
      return Expanded(
        child: SpringTap(
          onTap: enabled ? () => onChanged(value) : null,
          child: AnimatedContainer(
            duration: Motion.fast,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: selected
                        ? scheme.onPrimary
                        : enabled
                            ? scheme.onSurfaceVariant
                            : scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(
                          color: selected
                              ? scheme.onPrimary
                              : enabled
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        children: [
          seg(false, Icons.person_outline, 'My courses ($myCount)'),
          seg(true, Icons.grid_view_outlined, 'All ($allCount)'),
        ],
      ),
    );
  }
}

class _MissingNote extends StatelessWidget {
  final List<String> missing;
  const _MissingNote(this.missing);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'Not in this catalog yet: ${missing.join(", ")}. The catalog may '
              'not cover every department — check the official site for these.',
              style: context.text.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

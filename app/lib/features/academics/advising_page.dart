import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'advising_model.dart';

/// Pre-advising: courses offered for next-term registration and courses already
/// taken. Data from /student/advising.
class AdvisingPage extends ConsumerWidget {
  const AdvisingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(advisingProvider.notifier).ensureLoaded();
    final state = ref.watch(advisingProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(advisingProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.large(title: Text('Pre-Advising')),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (state) {
                  ResLoading() => const CardSkeleton(lines: 6),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn\'t load',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.read(advisingProvider.notifier).load(),
                    ),
                  ResData(:final loaded) => _Content(loaded.data),
                },
                const SizedBox(height: 96),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final AdvisingData d;
  const _Content(this.d);

  @override
  Widget build(BuildContext context) {
    if (d.offered.isEmpty && d.taken.isEmpty) {
      return const StateMessage(
          icon: Icons.assignment_outlined,
          title: 'Nothing to advise',
          subtitle: 'No advising data is available right now.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.offered.isNotEmpty)
          FadeSlideIn(
            child: _CourseListCard(
              title: 'Available next term',
              icon: Icons.playlist_add_check_outlined,
              courses: d.offered,
              showMandatory: true,
            ),
          ),
        if (d.taken.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 80,
            child: _CourseListCard(
              title: 'Already taken',
              icon: Icons.history_outlined,
              courses: d.taken,
              showMandatory: false,
            ),
          ),
        ],
      ],
    );
  }
}

class _CourseListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<OfferedCourse> courses;
  final bool showMandatory;
  const _CourseListCard({
    required this.title,
    required this.icon,
    required this.courses,
    required this.showMandatory,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final credits = courses.fold<double>(0, (s, c) => s + (c.credit ?? 0));
    return SectionCard(
      title: title,
      icon: icon,
      trailing: Text('${courses.length} · ${credits.toStringAsFixed(0)} cr',
          style: context.text.labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant)),
      child: Column(
        children: [
          for (var i = 0; i < courses.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _CourseRow(courses[i], showMandatory: showMandatory),
          ],
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final OfferedCourse c;
  final bool showMandatory;
  const _CourseRow(this.c, {required this.showMandatory});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(c.code ?? '—',
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (showMandatory && c.mandatory) ...[
                    const SizedBox(width: Spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.status.warnContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Required',
                          style: context.text.labelSmall?.copyWith(
                              color: context.status.warn,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              if (c.title != null)
                Text(c.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${c.credit?.toStringAsFixed(0) ?? '—'} cr',
                style: context.text.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (c.offeredTrimester != null)
              Text(c.offeredTrimester!,
                  style: context.text.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/coming_soon_page.dart';
import '../common/course_names.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'advising_model.dart';

/// Pre-advising: the courses offered for next-term registration, with the ones
/// you've already taken marked inline. Pre-advising itself happens on UCAM (we
/// don't do it in-app), so there's a direct link out.
class AdvisingPage extends ConsumerStatefulWidget {
  const AdvisingPage({super.key});

  @override
  ConsumerState<AdvisingPage> createState() => _AdvisingPageState();
}

class _AdvisingPageState extends ConsumerState<AdvisingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(advisingProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(advisingProvider);
    return PageScaffold(
      title: 'Pre-Advising',
      onRefresh: () => ref.read(advisingProvider.notifier).load(force: true),
      body: ResourceBody<AdvisingData>(
        state: state,
        loadingLabel: 'Loading offered courses…',
        errorTitle: 'Couldn’t load pre-advising',
        onRetry: () => ref.read(advisingProvider.notifier).load(force: true),
        builder: (d) => _Content(d),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final AdvisingData d;
  const _Content(this.d);

  @override
  Widget build(BuildContext context) {
    final note = InfoNote(
      tone: StatusTone.accent,
      title: 'Pre-advise on UCAM',
      icon: AppIcons.advising,
      text: 'Use this list to plan, then submit your pre-advising on the UCAM '
          'portal — it isn’t done inside the app.',
      action: OutlinedButton.icon(
        onPressed: () => openUcam(context),
        icon: const Icon(AppIcons.external, size: 18),
        label: const Text('Open UCAM'),
      ),
    );

    if (d.offered.isEmpty && d.taken.isEmpty) {
      return Stacked(
        gap: Spacing.lg,
        children: [
          const Reveal(
            child: EmptyState(
                icon: AppIcons.advising,
                title: 'Nothing to advise',
                message: 'No advising data is available right now.'),
          ),
          Reveal(index: 1, child: note),
        ],
      );
    }

    // Taken course codes (normalised) so offered ones can be marked inline.
    final takenCodes = {
      for (final c in d.taken)
        if (c.code != null) _norm(c.code!),
    };
    final offered = d.offered;
    final takenInOffered = offered
        .where((c) => c.code != null && takenCodes.contains(_norm(c.code!)))
        .length;
    final remaining = offered.length - takenInOffered;

    final available = offered.isEmpty
        ? null
        : Section(
            title: 'Available next term',
            trailing: Text('$remaining new · ${offered.length} total'),
            child: RowGroup(
              children: [
                for (final c in offered)
                  _CourseRow(
                    c,
                    taken:
                        c.code != null && takenCodes.contains(_norm(c.code!)),
                  ),
              ],
            ),
          );
    final taken = d.taken.isNotEmpty ? _TakenSummary(d.taken) : null;

    Widget body;
    if (available != null && taken != null) {
      body = TwoColumn(left: available, right: taken, ratio: 0.6);
    } else {
      body = available ?? taken ?? const SizedBox.shrink();
    }

    return Stacked(children: [
      Reveal(child: note),
      Reveal(index: 1, child: body),
    ]);
  }

  static String _norm(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

class _CourseRow extends StatelessWidget {
  final OfferedCourse c;
  final bool taken;
  const _CourseRow(this.c, {required this.taken});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final extra = [
      '${c.credit?.toStringAsFixed(0) ?? '—'} cr',
      if (c.offeredTrimester != null && c.offeredTrimester!.isNotEmpty)
        c.offeredTrimester!,
    ].join(' · ');
    final badge = taken
        ? const StatusBadge('Taken',
            tone: StatusTone.success, icon: AppIcons.check)
        : (c.mandatory
            ? const StatusBadge('Required', tone: StatusTone.accent)
            : null);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg + 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: CourseName(
                code: c.code ?? '—',
                title: c.title,
                extra: extra,
                titleStyle: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: taken ? scheme.onSurfaceVariant : null),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: Spacing.md),
              badge,
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact roll-up of already-taken courses (a count + credit total) so the page
/// acknowledges them without a second long list.
class _TakenSummary extends StatelessWidget {
  final List<OfferedCourse> taken;
  const _TakenSummary(this.taken);

  @override
  Widget build(BuildContext context) {
    final credits = taken.fold<double>(0, (s, c) => s + (c.credit ?? 0));
    return Section(
      title: 'Already taken',
      trailing: Text('${taken.length} · ${credits.toStringAsFixed(0)} cr'),
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          for (final c in taken)
            StatusBadge(
              (c.title != null && c.title!.isNotEmpty)
                  ? '${c.title} · ${c.code ?? ''}'
                  : (c.code ?? '—'),
              tone: StatusTone.success,
            ),
        ],
      ),
    );
  }
}

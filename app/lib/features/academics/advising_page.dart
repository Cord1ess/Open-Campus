import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/coming_soon_page.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import '../common/collapsing_title.dart';
import 'advising_model.dart';

/// Pre-advising: the courses offered for next-term registration, with the ones
/// you've ALREADY taken marked inline. Pre-advising itself happens on UCAM (we
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(advisingProvider.notifier).load(force: true),
        child: CustomScrollView(
          slivers: [
            const SliverCollapsingAppBar(title: 'Pre-Advising'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (state) {
                  ResLoading() => const SectionCard(
                      title: 'Pre-Advising',
                      icon: Icons.assignment_outlined,
                      child: CardSkeleton(label: 'Loading offered courses…')),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn’t load',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.read(advisingProvider.notifier).load(force: true),
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
      return Column(
        children: [
          const StateMessage(
              icon: Icons.assignment_outlined,
              title: 'Nothing to advise',
              subtitle: 'No advising data is available right now.'),
          const SizedBox(height: Spacing.lg),
          _UcamCard(),
        ],
      );
    }

    // Taken course codes (normalised) so offered ones can be marked inline.
    final takenCodes = {
      for (final c in d.taken)
        if (c.code != null) _norm(c.code!),
    };
    final offered = d.offered;
    final takenInOffered =
        offered.where((c) => c.code != null && takenCodes.contains(_norm(c.code!))).length;
    final remaining = offered.length - takenInOffered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(child: _UcamCard()),
        const SizedBox(height: Spacing.lg),
        if (offered.isNotEmpty)
          FadeSlideIn(
            delayMs: 60,
            child: SectionCard(
              title: 'Available next term',
              icon: Icons.playlist_add_check_outlined,
              trailing: Text(
                  '$remaining new · ${offered.length} total',
                  style: context.text.labelMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant)),
              child: Column(
                children: [
                  for (var i = 0; i < offered.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: Spacing.lg,
                          color: context.scheme.outlineVariant),
                    _CourseRow(
                      offered[i],
                      taken: offered[i].code != null &&
                          takenCodes.contains(_norm(offered[i].code!)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        // Any taken courses that AREN'T in the offered list (already-cleared
        // requirements) — shown compactly so the data isn't lost.
        if (d.taken.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 120,
            child: _TakenSummary(d.taken),
          ),
        ],
      ],
    );
  }

  static String _norm(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

/// Prominent card linking out to UCAM, since pre-advising is done there.
class _UcamCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.open_in_new_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text('Pre-advise on UCAM',
                    style: context.text.titleSmall?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
              'Use this list to plan, then submit your pre-advising on the UCAM '
              'portal — it isn’t done inside the app.',
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openUcam(context),
              icon: const Icon(Icons.account_balance_rounded, size: 18),
              label: const Text('Open UCAM'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final OfferedCourse c;
  final bool taken;
  const _CourseRow(this.c, {required this.taken});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Opacity(
      opacity: taken ? 0.6 : 1,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.code ?? '—',
                          style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration:
                                  taken ? TextDecoration.lineThrough : null)),
                    ),
                    if (taken) ...[
                      const SizedBox(width: Spacing.sm),
                      _tag(context, 'Taken', scheme.secondary,
                          icon: Icons.check_rounded),
                    ] else if (c.mandatory) ...[
                      const SizedBox(width: Spacing.sm),
                      _tag(context, 'Required', scheme.primary),
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
      ),
    );
  }

  Widget _tag(BuildContext context, String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
          ],
          Text(label,
              style: context.text.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
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
    final scheme = context.scheme;
    final credits = taken.fold<double>(0, (s, c) => s + (c.credit ?? 0));
    return SectionCard(
      title: 'Already taken',
      icon: Icons.history_outlined,
      trailing: Text('${taken.length} · ${credits.toStringAsFixed(0)} cr',
          style: context.text.labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant)),
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          for (final c in taken)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(c.code ?? '—',
                  style: context.text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

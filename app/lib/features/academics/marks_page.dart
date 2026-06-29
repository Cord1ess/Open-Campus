import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'marks_model.dart';

/// Item-wise marks: pick a trimester, then see each course's assessment
/// breakdown (attendance, class tests, assignment, midterm, …) with progress
/// bars. Data from /student/marks (driven cascade — slower, so on demand).
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Marks')),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              trimesters.when(
                loading: () => const CardSkeleton(lines: 1),
                error: (e, _) => StateMessage(
                  icon: Icons.cloud_off,
                  title: 'Couldn\'t load trimesters',
                  subtitle: '$e',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(markTrimestersProvider),
                ),
                data: (opts) => _TrimesterPicker(
                  options: opts,
                  selected: _trimester,
                  onPick: (v) => setState(() => _trimester = v),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              if (_trimester == null)
                const StateMessage(
                  icon: Icons.touch_app_outlined,
                  title: 'Pick a trimester',
                  subtitle: 'Choose a trimester above to see its marks.',
                )
              else
                _MarksList(trimester: _trimester!),
              const SizedBox(height: 96),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TrimesterPicker extends StatelessWidget {
  final List<TrimesterOption> options;
  final String? selected;
  final ValueChanged<String> onPick;
  const _TrimesterPicker({
    required this.options,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const StateMessage(
          icon: Icons.event_busy_outlined, title: 'No trimesters available');
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (_, i) {
          final o = options[i];
          final sel = o.value == selected;
          final scheme = context.scheme;
          return SpringTap(
            onTap: () => onPick(o.value),
            borderRadius: BorderRadius.circular(Radii.full),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: sel ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
              alignment: Alignment.center,
              child: Text(
                // Show the bracketed term label, e.g. "[261] Spring 2026".
                o.label.replaceFirst(RegExp(r'^\[(\d+)\]\s*'), ''),
                style: context.text.labelLarge?.copyWith(
                  color: sel ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MarksList extends ConsumerWidget {
  final String trimester;
  const _MarksList({required this.trimester});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(marksProvider(trimester));
    return marks.when(
      loading: () => Column(
        children: const [
          _LoadingNote(),
          SizedBox(height: Spacing.lg),
          CardSkeleton(lines: 5),
        ],
      ),
      error: (e, _) => StateMessage(
        icon: Icons.cloud_off,
        title: 'Couldn\'t load marks',
        subtitle: '$e',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(marksProvider(trimester)),
      ),
      data: (d) {
        if (d.courses.isEmpty) {
          return const StateMessage(
            icon: Icons.assignment_outlined,
            title: 'No marks yet',
            subtitle: 'No marks have been published for this trimester.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < d.courses.length; i++) ...[
              if (i > 0) const SizedBox(height: Spacing.lg),
              FadeSlideIn(delayMs: 40 * i, child: _CourseCard(d.courses[i])),
            ],
          ],
        );
      },
    );
  }
}

class _LoadingNote extends StatelessWidget {
  const _LoadingNote();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            'Fetching each course from UCAM… this takes a few seconds.',
            style: context.text.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseMarks c;
  const _CourseCard(this.c);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final pct = (c.totalMax != null && c.totalMax! > 0 && c.totalObtained != null)
        ? c.totalObtained! / c.totalMax! * 100
        : null;
    return SectionCard(
      title: c.code,
      icon: Icons.assignment_turned_in_outlined,
      trailing: c.totalObtained != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${c.totalObtained!.toStringAsFixed(2)}'
                '${c.totalMax != null ? ' / ${c.totalMax!.toStringAsFixed(0)}' : ''}',
                style: context.text.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.title.isNotEmpty)
            Text(c.title,
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          if (c.totalClass != null) ...[
            const SizedBox(height: 4),
            Text(
              'Attendance: ${c.present ?? 0}/${c.totalClass} classes '
              '(${c.attendancePct.toStringAsFixed(0)}%)',
              style: context.text.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: Spacing.md),
          for (final comp in c.components) ...[
            _ComponentRow(comp),
            const SizedBox(height: Spacing.sm),
          ],
          if (pct != null) ...[
            Divider(color: scheme.outlineVariant),
            Row(
              children: [
                Text('Total',
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${pct.toStringAsFixed(1)}%',
                    style: context.text.titleSmall?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final MarkComponent comp;
  const _ComponentRow(this.comp);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(comp.name,
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(
              '${comp.obtained?.toStringAsFixed(2) ?? '—'}'
              '${comp.max != null ? ' / ${comp.max!.toStringAsFixed(0)}' : ''}',
              style: context.text.bodyMedium?.copyWith(
                  color: scheme.onSurface, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: comp.ratio.toDouble()),
            duration: Motion.slow,
            curve: Motion.emphasized,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'exam_routine_model.dart';

/// Exam routines are published by UIU as Google Sheets, one per program. We list
/// them and open the chosen one in the browser. Data from /student/exam-routine.
class ExamRoutinePage extends ConsumerWidget {
  const ExamRoutinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examRoutineProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Exam Routine')),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              FadeSlideIn(
                child: Text(
                  'UIU publishes exam routines per program. Open the one that '
                  'matches your program.',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              state.when(
                loading: () => const CardSkeleton(lines: 4),
                error: (e, _) => StateMessage(
                  icon: Icons.cloud_off,
                  title: 'Couldn\'t load',
                  subtitle: '$e',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(examRoutineProvider),
                ),
                data: (d) => d.routines.isEmpty
                    ? const StateMessage(
                        icon: Icons.event_busy_outlined,
                        title: 'No exam routine published',
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < d.routines.length; i++) ...[
                            if (i > 0) const SizedBox(height: Spacing.md),
                            FadeSlideIn(
                              delayMs: 40 * i,
                              child: _RoutineTile(d.routines[i]),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 96),
            ]),
          ),
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  final ExamRoutineLink routine;
  const _RoutineTile(this.routine);

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(routine.url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t open the routine.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SpringTap(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(Icons.calendar_month_outlined,
                  color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(routine.label,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: Spacing.sm),
            Icon(Icons.open_in_new, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

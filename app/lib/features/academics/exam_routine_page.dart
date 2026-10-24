import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import 'exam_routine_model.dart';

/// Exam routines are published by UIU as Google Sheets, one per program. We
/// list them and open the chosen one in the browser. Data from
/// /student/exam-routine.
class ExamRoutinePage extends ConsumerWidget {
  const ExamRoutinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examRoutineProvider);
    return PageScaffold(
      title: 'Exam Routine',
      body: Stacked(
        gap: Spacing.lg,
        children: [
          Text(
            'UIU publishes exam routines per program. Open the one that '
            'matches your program.',
            style: context.text.bodyMedium
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          state.when(
            loading: () => const LoadingState(label: 'Loading exam routines…'),
            error: (e, _) => ErrorState(
              title: 'Couldn’t load exam routines',
              message: '$e',
              onRetry: () => ref.invalidate(examRoutineProvider),
            ),
            data: (d) => d.routines.isEmpty
                ? const EmptyState(
                    icon: AppIcons.exams,
                    title: 'No exam routine published',
                    message: 'Check back once UIU publishes this term’s routine.',
                  )
                : RowGroup(
                    children: [
                      for (final r in d.routines)
                        ListRow(
                          icon: AppIcons.exams,
                          title: r.label,
                          external: true,
                          onTap: () => _open(context, r),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, ExamRoutineLink routine) async {
    final uri = Uri.tryParse(routine.url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open the routine.')),
      );
    }
  }
}

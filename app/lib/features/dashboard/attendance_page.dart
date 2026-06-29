import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'models.dart';
import 'resource_view.dart';

class AttendancePage extends ConsumerWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(attendanceProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            const SliverCollapsingAppBar(title: 'Attendance'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                FadeSlideIn(
                  child: ResourceSection<AttendanceData>(
                    title: 'By course',
                    icon: Icons.event_available_outlined,
                    state: attendance,
                    loadingSkeleton: const CardSkeleton(lines: 6),
                    builder: (d) => AttendanceContent(d),
                  ),
                ),
                const SizedBox(height: 96),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

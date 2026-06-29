import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import 'dashboard_controller.dart';
import 'dashboard_widgets.dart';
import 'models.dart';
import 'resource_view.dart';

class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(resultsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(resultsProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.large(
              title: Text('Results'),
              floating: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                FadeSlideIn(
                  child: ResourceSection<ResultsData>(
                    title: 'Semester results',
                    icon: Icons.timeline,
                    state: results,
                    loadingSkeleton: const CardSkeleton(chart: true, lines: 4),
                    builder: (d) => ResultsContent(d),
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

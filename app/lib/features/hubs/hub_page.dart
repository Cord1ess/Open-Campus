import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/coming_soon_page.dart';
import '../profile/profile_button.dart';

/// Availability of a hub feature.
enum FeatureStatus { live, comingSoon, opensInUcam }

class HubFeature {
  final IconData icon;
  final String title;
  final String? subtitle;
  final FeatureStatus status;
  final void Function(BuildContext context)? onTap;
  const HubFeature({
    required this.icon,
    required this.title,
    this.subtitle,
    this.status = FeatureStatus.live,
    this.onTap,
  });
}

class HubGroup {
  final String label;
  final List<HubFeature> features;
  const HubGroup(this.label, this.features);
}

/// A tab page of grouped feature rows (Academics, Finance, Services). Working
/// features are plain rows; features that open the UCAM site show an external
/// link icon; features that are not available yet are collected into a muted
/// group at the bottom so they stay discoverable without cluttering the list.
/// On wide screens the groups flow into two columns.
class HubPage extends StatelessWidget {
  final String title;
  final List<HubGroup> groups;
  final Widget? header;
  const HubPage({
    super.key,
    required this.title,
    required this.groups,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final available = <HubGroup>[];
    final unavailable = <HubFeature>[];
    for (final g in groups) {
      final live = g.features
          .where((f) => f.status != FeatureStatus.comingSoon)
          .toList();
      unavailable
          .addAll(g.features.where((f) => f.status == FeatureStatus.comingSoon));
      if (live.isNotEmpty) available.add(HubGroup(g.label, live));
    }

    return PageScaffold(
      title: title,
      showBack: false,
      actions: const [ProfileButton()],
      body: Stacked(
        children: [
          if (header != null) header!,
          ResponsiveGrid(
            maxColumns: 2,
            stretch: false,
            spacing: Spacing.xl,
            runSpacing: Spacing.xl,
            children: [
              for (final g in available)
                RowGroup(
                  title: g.label,
                  children: [for (final f in g.features) _row(context, f)],
                ),
              if (unavailable.isNotEmpty)
                RowGroup(
                  title: 'Not available yet',
                  trailing: const Text('Opens in UCAM'),
                  children: [
                    for (final f in unavailable) _row(context, f, muted: true),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, HubFeature f, {bool muted = false}) {
    return ListRow(
      icon: f.icon,
      title: f.title,
      subtitle: f.subtitle,
      muted: muted,
      external: f.status == FeatureStatus.opensInUcam,
      onTap: () {
        if (f.onTap != null) {
          f.onTap!(context);
        } else if (f.status == FeatureStatus.opensInUcam) {
          openUcam(context);
        } else {
          Navigator.of(context).push(appRoute(
            ComingSoonPage(title: f.title, icon: f.icon),
          ));
        }
      },
    );
  }
}

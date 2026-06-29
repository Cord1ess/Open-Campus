import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import '../common/coming_soon_page.dart';

/// Collapsing-title page of grouped feature rows, used by Academics, Finance,
/// and Services. On wide screens the rows flow into a responsive grid; each row
/// navigates with a shared-axis transition.
class HubPage extends StatelessWidget {
  final String title;
  final List<HubGroup> groups;

  /// Optional summary widget shown at the top of the page (e.g. stat cards) so
  /// the header area isn't empty.
  final Widget? header;
  const HubPage({
    super.key,
    required this.title,
    required this.groups,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    // Wide screens: feature rows within a group flow 2-up so groups read as
    // compact cards instead of one tall column.
    final groupCols = Breakpoints.isWide(context) ? 2 : 1;
    return Scaffold(
      body: CollapsingTitleScrollView(
        title: title,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, 0),
            sliver: SliverList.list(children: [
              if (header != null) ...[
                SpringIn(child: header!),
                const SizedBox(height: Spacing.xl),
              ],
              for (var g = 0; g < groups.length; g++) ...[
                if (g > 0) const SizedBox(height: Spacing.xl),
                SpringIn(
                  delayMs: 40 * g,
                  child: FeatureGroup(
                    label: groups[g].label,
                    rows: [
                      ResponsiveGrid(
                        columns: groupCols,
                        children: [
                          for (final f in groups[g].features) _row(context, f),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 96),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, HubFeature f) {
    return FeatureRow(
      icon: f.icon,
      title: f.title,
      subtitle: f.subtitle,
      status: f.status,
      onTap: () {
        if (f.onTap != null) {
          f.onTap!(context);
        } else {
          Navigator.of(context).push(sharedAxisRoute(
            ComingSoonPage(title: f.title, icon: f.icon),
          ));
        }
      },
    );
  }
}

class HubGroup {
  final String label;
  final List<HubFeature> features;
  const HubGroup(this.label, this.features);
}

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
    this.status = FeatureStatus.comingSoon,
    this.onTap,
  });
}

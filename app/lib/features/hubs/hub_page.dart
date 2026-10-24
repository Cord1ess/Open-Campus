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
  final Hue? hue;
  final void Function(BuildContext context)? onTap;
  const HubFeature({
    required this.icon,
    required this.title,
    this.subtitle,
    this.status = FeatureStatus.live,
    this.hue,
    this.onTap,
  });
}

class HubGroup {
  final String label;
  final List<HubFeature> features;
  const HubGroup(this.label, this.features);
}

const _rotation = [
  Hue.peach, Hue.sky, Hue.mint, Hue.lavender, Hue.pink, Hue.lemon, Hue.aqua,
];

/// A tab page: optional summary tiles, a colour-block grid of the main
/// features ([featured] of them), then the remaining features grouped in
/// lists with pastel icon tiles. Features that aren't available yet are
/// collected into a muted group at the end.
class HubPage extends StatelessWidget {
  final String title;
  final List<HubGroup> groups;
  final Widget? header;
  final int featured;
  const HubPage({
    super.key,
    required this.title,
    required this.groups,
    this.header,
    this.featured = 4,
  });

  void _open(BuildContext context, HubFeature f) {
    if (f.onTap != null) {
      f.onTap!(context);
    } else if (f.status == FeatureStatus.opensInUcam) {
      openUcam(context);
    } else {
      Navigator.of(context)
          .push(appRoute(ComingSoonPage(title: f.title, icon: f.icon)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Assign a stable colour to every feature.
    var k = 0;
    final hueOf = <HubFeature, Hue>{};
    for (final g in groups) {
      for (final f in g.features) {
        hueOf[f] = f.hue ?? _rotation[k++ % _rotation.length];
      }
    }

    final live = [
      for (final g in groups)
        for (final f in g.features)
          if (f.status == FeatureStatus.live) f,
    ];
    final top = live.take(featured).toSet();
    final unavailable = [
      for (final g in groups)
        for (final f in g.features)
          if (f.status == FeatureStatus.comingSoon) f,
    ];
    final lists = <HubGroup>[
      for (final g in groups)
        if (g.features.any((f) =>
            f.status != FeatureStatus.comingSoon && !top.contains(f)))
          HubGroup(g.label, [
            for (final f in g.features)
              if (f.status != FeatureStatus.comingSoon && !top.contains(f)) f,
          ]),
    ];

    final wide = Breakpoints.isExpanded(context);
    final tileCols = (wide ? 4 : 2).clamp(1, top.isEmpty ? 1 : top.length);

    return PageScaffold(
      title: title,
      showBack: false,
      actions: const [ProfileButton()],
      body: Stacked(
        children: [
          if (header != null) header!,
          if (top.isNotEmpty)
            ResponsiveGrid(
              columns: tileCols,
              spacing: Spacing.md,
              runSpacing: Spacing.md,
              children: [
                for (final f in top)
                  _FeatureTile(
                      feature: f, hue: hueOf[f]!, onTap: () => _open(context, f)),
              ],
            ),
          if (lists.isNotEmpty || unavailable.isNotEmpty)
            ResponsiveGrid(
              maxColumns: 2,
              stretch: false,
              spacing: Spacing.xl,
              runSpacing: Spacing.xl + 4,
              children: [
                for (final g in lists)
                  RowGroup(
                    title: g.label,
                    children: [
                      for (final f in g.features)
                        ListRow(
                          icon: f.icon,
                          hue: hueOf[f],
                          title: f.title,
                          subtitle: f.subtitle,
                          external: f.status == FeatureStatus.opensInUcam,
                          onTap: () => _open(context, f),
                        ),
                    ],
                  ),
                if (unavailable.isNotEmpty)
                  RowGroup(
                    title: 'Not available yet',
                    trailing: const Text('Opens in UCAM'),
                    children: [
                      for (final f in unavailable)
                        ListRow(
                          icon: f.icon,
                          hue: hueOf[f],
                          muted: true,
                          title: f.title,
                          subtitle: f.subtitle,
                          onTap: () => _open(context, f),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final HubFeature feature;
  final Hue hue;
  final VoidCallback onTap;
  const _FeatureTile(
      {required this.feature, required this.hue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Panel(
      hue: hue,
      radius: Radii.lg,
      padding: const EdgeInsets.all(Spacing.lg + 2),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 128),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(feature.icon, size: 22, color: p.onContainer),
            ),
            const SizedBox(height: Spacing.lg),
            Text(feature.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    context.text.titleMedium?.copyWith(color: p.onContainer)),
            if (feature.subtitle != null)
              Text(feature.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                      color: p.onContainer.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }
}

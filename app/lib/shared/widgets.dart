import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/motion.dart';

export '../core/theme/motion.dart'
    show SpringIn, SpringTap, CountUp, sharedAxisRoute;

/// Freshness state for a section (live vs. cached-from-device).
enum Freshness { live, cached }

/// A titled M3 card section.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  const SectionCard({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // Matches the dashboard card: white/neutral surface with a hairline border
    // (not a Material elevation), so every section reads as one design language.
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
              ],
              Expanded(
                child: Text(title, style: context.text.titleMedium),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: Spacing.lg),
          child,
        ],
      ),
    );
  }
}

/// M3 freshness chip — uses tonal containers.
class FreshnessChip extends StatelessWidget {
  final Freshness freshness;
  final DateTime? at;
  const FreshnessChip({super.key, required this.freshness, this.at});

  @override
  Widget build(BuildContext context) {
    final live = freshness == Freshness.live;
    final bg = live ? context.status.goodContainer : context.scheme.surfaceContainerHighest;
    final fg = live ? context.status.good : context.scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(live ? Icons.bolt : Icons.history, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(live ? 'Live' : _ago(at),
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _ago(DateTime? at) {
    if (at == null) return 'Cached';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

/// Shimmer skeleton block, animated with the M3 surface tones.
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 14, this.width, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.slow)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lo = context.scheme.surfaceContainerHighest;
    final hi = context.scheme.surfaceContainer;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(lo, hi, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Soft re-login prompt (M3 tonal banner) when the UCAM session expired.
class ReloginBanner extends StatelessWidget {
  final VoidCallback onRelogin;
  const ReloginBanner({super.key, required this.onRelogin});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.status.warnContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.md, Spacing.sm, Spacing.md),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: context.status.warn),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                'Your UCAM session expired. Showing your last synced data.',
                style: TextStyle(fontSize: 13, color: context.scheme.onSurface),
              ),
            ),
            TextButton(onPressed: onRelogin, child: const Text('Re-login')),
          ],
        ),
      ),
    );
  }
}

/// Friendly empty/error state (M3). Optionally shows a retry action.
class StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: context.scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, size: 26, color: context.scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.md),
          Text(title,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: context.text.bodySmall
                    ?.copyWith(color: context.scheme.onSurfaceVariant)),
          ],
          if (onAction != null) ...[
            const SizedBox(height: Spacing.md),
            SpringTap(
              onTap: onAction,
              borderRadius: BorderRadius.circular(Radii.full),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.sm),
                decoration: BoxDecoration(
                  color: context.scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh,
                        size: 16, color: context.scheme.onSecondaryContainer),
                    const SizedBox(width: 6),
                    Text(actionLabel ?? 'Retry',
                        style: context.text.labelLarge?.copyWith(
                            color: context.scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Entrance animation — now spring-based (Expressive). Kept under the old name
/// so existing pages don't need edits; delegates to SpringIn (motion.dart).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) =>
      SpringIn(delayMs: delayMs, child: child);
}

/// Status of a feature in the app.
enum FeatureStatus { live, comingSoon, opensInUcam }

/// An animated, pressable row representing a UCAM feature inside a hub page.
class FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final FeatureStatus status;
  final VoidCallback? onTap;
  const FeatureRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.status = FeatureStatus.live,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SpringTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(icon, size: 22, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            _StatusPill(status),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final FeatureStatus status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      FeatureStatus.live => ('Live', context.status.goodContainer, context.status.good),
      FeatureStatus.comingSoon => (
          'Soon',
          context.scheme.surfaceContainerHighest,
          context.scheme.onSurfaceVariant
        ),
      FeatureStatus.opensInUcam => (
          'UCAM',
          context.scheme.tertiaryContainer,
          context.scheme.onTertiaryContainer
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// A titled group of feature rows for the hub pages.
class FeatureGroup extends StatelessWidget {
  final String label;
  final List<Widget> rows;
  const FeatureGroup({super.key, required this.label, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Spacing.xs, bottom: Spacing.sm),
          child: Text(label.toUpperCase(),
              style: context.text.labelMedium?.copyWith(
                  color: context.scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: Spacing.sm),
          rows[i],
        ],
      ],
    );
  }
}

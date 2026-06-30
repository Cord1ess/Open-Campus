import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/avatar.dart';
import '../../shared/widgets.dart';
import '../about/about_page.dart';
import '../auth/auth_controller.dart';
import '../common/collapsing_title.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final homeState = ref.watch(homeProvider);
    final home =
        homeState is ResData<HomeSummary> ? homeState.loaded.data : null;
    final avatar = ref.watch(avatarProvider).value;
    // Prefer the roll scraped from the home page; fall back to the auth roll
    // (which is empty right after a restored session until home loads).
    final authRoll =
        auth is AuthSignedIn && auth.roll.isNotEmpty ? auth.roll : null;
    final roll = home?.roll ?? authRoll ?? '—';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverCollapsingAppBar(
            title: 'Profile',
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context)
                    .push(sharedAxisRoute(const AboutPage())),
                tooltip: 'Settings',
                iconSize: 26,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              FadeSlideIn(
                child: _ProfileHeader(
                    home: home, roll: roll, avatarBytes: avatar),
              ),
              if (home != null && _hasBio(home)) ...[
                const SizedBox(height: Spacing.lg),
                FadeSlideIn(delayMs: 60, child: _BioCard(home)),
              ],
              const SizedBox(height: Spacing.lg),
              FadeSlideIn(
                delayMs: 80,
                child: SectionCard(
                  title: 'Your privacy',
                  icon: Icons.lock_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Bullet('Your UCAM password is never stored.'),
                      _Bullet(
                          'We keep no copy of your data on our servers — everything is live.'),
                      _Bullet(
                          'The app caches your last view on this device only; logging out clears it.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              FadeSlideIn(
                delayMs: 140,
                child: _LogoutCard(onLogout: () {
                  // Pop any pushed routes (this Profile page lives on top of the
                  // shell) so logout reveals the login screen, not a stale page.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ref.read(authControllerProvider.notifier).logout();
                }),
              ),
              const SizedBox(height: Spacing.xl),
              Center(
                child: Text(
                    'Open Campus · unofficial · v${AppInfo.version} ${AppInfo.buildChannel}',
                    style: context.text.labelSmall
                        ?.copyWith(color: context.scheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 96),
            ]),
          ),
        ],
      ),
    );
  }
}

bool _hasBio(HomeSummary h) =>
    h.dob != null ||
    h.bloodGroup != null ||
    h.phone != null ||
    h.fatherName != null ||
    h.motherName != null;

class _ProfileHeader extends StatelessWidget {
  final HomeSummary? home;
  final String roll;
  final List<int>? avatarBytes;
  const _ProfileHeader({
    required this.home,
    required this.roll,
    required this.avatarBytes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final term = home?.currentTerm?.name;
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Avatar(bytes: avatarBytes, radius: 44),
          const SizedBox(height: Spacing.md),
          Text(home?.name ?? 'Student',
              textAlign: TextAlign.center,
              style: context.text.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Spacing.sm),
          // ID badge — high-contrast pill so the student ID is clearly visible.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(roll,
                    style: context.text.labelLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          if (term != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(term,
                style: context.text.labelMedium
                    ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _BioCard extends StatelessWidget {
  final HomeSummary home;
  const _BioCard(this.home);

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      if (home.dob != null) (Icons.cake_outlined, 'Date of birth', home.dob!),
      if (home.bloodGroup != null)
        (Icons.bloodtype_outlined, 'Blood group', home.bloodGroup!),
      if (home.phone != null) (Icons.phone_outlined, 'Phone', home.phone!),
      if (home.fatherName != null)
        (Icons.man_outlined, 'Father', home.fatherName!),
      if (home.motherName != null)
        (Icons.woman_outlined, 'Mother', home.motherName!),
    ];
    return SectionCard(
      title: 'Personal',
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: context.scheme.outlineVariant),
            _InfoRow(rows[i].$1, rows[i].$2, rows[i].$3),
          ],
        ],
      ),
    );
  }
}

/// One personal-info line: an icon, a fixed-width label, then the value — the
/// fixed label column keeps every value left-aligned in a clean second column.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: Spacing.md),
        SizedBox(
          width: 96,
          child: Text(label,
              style: context.text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// Bordered logout card matching the unified card look.
class _LogoutCard extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutCard({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SpringTap(
      onTap: onLogout,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.logout, size: 20, color: scheme.error),
            const SizedBox(width: Spacing.md),
            Text('Log out',
                style: context.text.titleMedium?.copyWith(color: scheme.error)),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.check_circle,
                size: 15, color: context.status.good),
          ),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

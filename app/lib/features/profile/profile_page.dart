import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final roll = auth is AuthSignedIn && auth.roll.isNotEmpty ? auth.roll : '—';
    final homeState = ref.watch(homeProvider);
    final home =
        homeState is ResData<HomeSummary> ? homeState.loaded.data : null;
    final avatar = ref.watch(avatarProvider).value;

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
              if (home?.advisor?.name != null) ...[
                const SizedBox(height: Spacing.lg),
                FadeSlideIn(delayMs: 100, child: _AdvisorCard(home!.advisor!)),
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
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.logout, color: context.scheme.error),
                    title: Text('Log out',
                        style: TextStyle(color: context.scheme.error)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.lg)),
                    onTap: () {
                      // Pop any pushed routes (this Profile page lives on top of
                      // the shell) so logout reveals the login screen, not a
                      // stale page beneath.
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                      ref.read(authControllerProvider.notifier).logout();
                    },
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xl),
              Center(
                child: Text('Open Campus · unofficial · v0.1',
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
    final avatar = avatarBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Row(
          children: [
            Avatar(bytes: avatar, radius: 34),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(home?.name ?? 'Student',
                      style: context.text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(roll,
                      style: context.text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  if (home?.currentTerm?.name != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(home!.currentTerm!.name!,
                          style: context.text.labelMedium
                              ?.copyWith(color: scheme.primary)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BioCard extends StatelessWidget {
  final HomeSummary home;
  const _BioCard(this.home);

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Personal',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          if (home.dob != null) _InfoRow(Icons.cake_outlined, 'Date of birth', home.dob!),
          if (home.bloodGroup != null)
            _InfoRow(Icons.bloodtype_outlined, 'Blood group', home.bloodGroup!),
          if (home.phone != null)
            _InfoRow(Icons.phone_outlined, 'Phone', home.phone!),
          if (home.fatherName != null)
            _InfoRow(Icons.man_outlined, 'Father', home.fatherName!),
          if (home.motherName != null)
            _InfoRow(Icons.woman_outlined, 'Mother', home.motherName!),
        ],
      ),
    );
  }
}

class _AdvisorCard extends StatelessWidget {
  final Advisor advisor;
  const _AdvisorCard(this.advisor);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: 'Academic advisor',
      icon: Icons.support_agent_outlined,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.secondaryContainer,
            child: Text(advisor.initial ?? '?',
                style: context.text.titleMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(advisor.name ?? '—',
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (advisor.room != null)
                  Text('Room ${advisor.room}',
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                if (advisor.email != null)
                  Text(advisor.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.md),
          Text(label,
              style: context.text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
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

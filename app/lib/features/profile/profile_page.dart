import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/avatar.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';
import 'settings_sections.dart';

/// Profile + settings in one place: identity and personal details, then
/// appearance, storage, server status and about, then log out.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('This clears the saved data on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Pop any pushed routes (this page lives on top of the shell) so logout
    // reveals the login screen, not a stale page.
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(authControllerProvider.notifier).logout();
  }

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
    final p = context.palette;

    final identity = _IdentityPanel(home: home, roll: roll, avatarBytes: avatar);
    final personal =
        home != null && _hasBio(home) ? _PersonalSection(home) : null;
    const privacy = InfoNote(
      icon: AppIcons.privacy,
      text:
          'Your UCAM password is never stored and our servers keep no copy of '
          'your data; the app caches your last view on this device only, and '
          'logging out clears it.',
    );
    final logout = Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _logout(context, ref),
        style: OutlinedButton.styleFrom(
          foregroundColor: p.dangerInk,
          side: BorderSide(color: p.dangerInk),
        ),
        icon: const Icon(AppIcons.logout, size: 18),
        label: const Text('Log out'),
      ),
    );
    final version = Text(
      'Open Campus · unofficial · v${AppInfo.version} ${AppInfo.buildChannel}',
      style: context.text.bodySmall,
    );

    final left = Stacked(children: [
      identity,
      if (personal != null) personal,
      privacy,
      logout,
    ]);
    const right = Stacked(children: [
      AppearanceSection(),
      StorageSection(),
      ServerStatusSection(),
      AboutSection(),
    ]);

    return PageScaffold(
      title: 'Profile',
      body: Stacked(
        children: [
          if (Breakpoints.isExpanded(context))
            TwoColumn(left: left, right: right, ratio: 0.45)
          else ...[
            identity,
            if (personal != null) personal,
            const AppearanceSection(),
            const StorageSection(),
            const ServerStatusSection(),
            const AboutSection(),
            privacy,
            logout,
          ],
          version,
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

class _IdentityPanel extends StatelessWidget {
  final HomeSummary? home;
  final String roll;
  final List<int>? avatarBytes;
  const _IdentityPanel({
    required this.home,
    required this.roll,
    required this.avatarBytes,
  });

  @override
  Widget build(BuildContext context) {
    final term = home?.currentTerm?.name;
    return Panel(
      child: Row(
        children: [
          Avatar(bytes: avatarBytes, radius: 28),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(home?.name ?? 'Student',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium),
                const SizedBox(height: Spacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(roll, outlined: true, icon: AppIcons.id),
                ),
                if (term != null) ...[
                  const SizedBox(height: Spacing.sm),
                  Text(term, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalSection extends StatelessWidget {
  final HomeSummary home;
  const _PersonalSection(this.home);


  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (home.dob != null)
        KeyValueRow(icon: AppIcons.birthday, label: 'Date of birth', value: home.dob!),
      if (home.bloodGroup != null)
        KeyValueRow(
            icon: AppIcons.bloodGroup, label: 'Blood group', value: home.bloodGroup!),
      if (home.phone != null)
        KeyValueRow(icon: AppIcons.phone, label: 'Phone', value: home.phone!),
      if (home.fatherName != null)
        KeyValueRow(icon: AppIcons.family, label: 'Father', value: home.fatherName!),
      if (home.motherName != null)
        KeyValueRow(icon: AppIcons.family, label: 'Mother', value: home.motherName!),
    ];
    return RowGroup(
      title: 'Personal',
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: r,
          ),
      ],
    );
  }
}

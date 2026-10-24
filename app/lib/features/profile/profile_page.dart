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

    final identity =
        _IdentityPanel(home: home, roll: roll, avatarBytes: avatar);
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

    final figures = _Figures(home: home);
    List<Widget> staggered(List<Widget> ws, [int from = 0]) => [
          for (var i = 0; i < ws.length; i++)
            Reveal(index: from + i, child: ws[i]),
        ];
    final leftItems = <Widget>[
      identity,
      figures,
      if (personal != null) personal,
      privacy,
      logout,
    ];
    const rightItems = <Widget>[
      AppearanceSection(),
      StorageSection(),
      ServerStatusSection(),
      AboutSection(),
    ];

    return PageScaffold(
      title: 'Profile',
      body: Stacked(
        children: [
          if (Breakpoints.isExpanded(context))
            TwoColumn(
              left: Stacked(children: staggered(leftItems)),
              right: Stacked(children: staggered(rightItems, 1)),
              ratio: 0.45,
            )
          else
            ...staggered([
              identity,
              figures,
              if (personal != null) personal,
              ...rightItems,
              privacy,
              logout,
            ]),
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
    final p = context.palette;
    return Panel(
      hue: Hue.lavender,
      radius: Radii.xl,
      padding: const EdgeInsets.all(Spacing.xl),
      child: Row(
        children: [
          // Avatar framed by a slowly turning Expressive cookie shape.
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                  child: IdleSpin(
                    period: const Duration(seconds: 26),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: ShapeDecoration(
                        color: p.accent,
                        shape: const ExpressiveShapeBorder(
                            ExpressiveShapeKind.cookie),
                      ),
                    ),
                  ),
                ),
                Avatar(bytes: avatarBytes, radius: 32),
              ],
            ),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(home?.name ?? 'Student',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge
                        ?.copyWith(color: p.onContainer)),
                const SizedBox(height: Spacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(roll, onColored: true, icon: AppIcons.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three figure tiles under the identity block: CGPA (hidden by default),
/// completed credits and the current term.
class _Figures extends StatelessWidget {
  final HomeSummary? home;
  const _Figures({required this.home});

  @override
  Widget build(BuildContext context) {
    final cgpa = home?.cgpa;
    final credits = home?.completedCredits;
    final term = home?.currentTerm?.name ?? home?.currentTerm?.code;
    return StatStrip(items: [
      StatBlock(
        label: 'CGPA',
        value: cgpa?.toStringAsFixed(2) ?? '—',
        secretId: cgpa != null ? Secrets.cgpa : null,
        hue: Hue.mint,
      ),
      StatBlock(
        label: 'Credits',
        value: credits?.toStringAsFixed(0) ?? '—',
        numeric: credits,
        format: (v) => v.toStringAsFixed(0),
        hue: Hue.sky,
      ),
      StatBlock(
        label: 'Term',
        value: term ?? '—',
        hue: Hue.peach,
      ),
    ]);
  }
}

class _PersonalSection extends StatelessWidget {
  final HomeSummary home;
  const _PersonalSection(this.home);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (home.dob != null)
        KeyValueRow(
            icon: AppIcons.birthday, label: 'Date of birth', value: home.dob!),
      if (home.bloodGroup != null)
        KeyValueRow(
            icon: AppIcons.bloodGroup,
            label: 'Blood group',
            value: home.bloodGroup!),
      if (home.phone != null)
        KeyValueRow(icon: AppIcons.phone, label: 'Phone', value: home.phone!),
      if (home.fatherName != null)
        KeyValueRow(
            icon: AppIcons.family, label: 'Father', value: home.fatherName!),
      if (home.motherName != null)
        KeyValueRow(
            icon: AppIcons.family, label: 'Mother', value: home.motherName!),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/motion.dart';
import '../../shared/avatar.dart';
import '../dashboard/dashboard_controller.dart';
import 'profile_page.dart';

/// App-bar action: the student's avatar, opening Profile (which also holds
/// Settings). Placed on every top-level tab so profile and settings are one tap
/// away from anywhere.
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(avatarProvider).value;
    return Semantics(
      button: true,
      label: 'Profile and settings',
      child: Tooltip(
        message: 'Profile',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () =>
              Navigator.of(context).push(appRoute(const ProfilePage())),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Avatar(bytes: bytes, radius: 16),
          ),
        ),
      ),
    );
  }
}

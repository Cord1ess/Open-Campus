import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/coming_soon_page.dart';

/// Transport & Gym registration — UCAM keeps these closed outside the
/// registration window, so we mirror that with a clear closed state and a way
/// to check UCAM if it reopens.
class RegistrationClosedPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  const RegistrationClosedPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: title,
      body: Column(
        children: [
          const SizedBox(height: Spacing.xl),
          const Reveal(
            child: StatusBadge('Registration is closed',
                tone: StatusTone.warning, icon: AppIcons.locked),
          ),
          Reveal(
            index: 1,
            child: EmptyState(
              icon: icon,
              title: title,
              message: description,
              actionLabel: 'Check on UCAM',
              actionIcon: AppIcons.external,
              onAction: () => openUcam(context),
            ),
          ),
        ],
      ),
    );
  }
}

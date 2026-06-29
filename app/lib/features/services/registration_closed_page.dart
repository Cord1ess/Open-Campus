import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/coming_soon_page.dart';

/// Transport & Gym registration — UCAM keeps these closed outside the
/// registration window, so we mirror that: show the service with a clear
/// "registration closed" state and a way to open UCAM if it reopens.
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
    final scheme = context.scheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SpringIn(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(Radii.xl),
                  ),
                  child:
                      Icon(icon, size: 44, color: scheme.onSecondaryContainer),
                ),
                const SizedBox(height: Spacing.xl),
                Text(title,
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall),
                const SizedBox(height: Spacing.sm),
                Text(description,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: Spacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg, vertical: Spacing.md),
                  decoration: BoxDecoration(
                    color: context.status.warnContainer,
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_clock_outlined,
                          size: 18, color: context.status.warn),
                      const SizedBox(width: Spacing.sm),
                      Text('Registration is closed',
                          style: context.text.labelLarge?.copyWith(
                              color: context.status.warn,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                TextButton.icon(
                  onPressed: () => openUcam(context),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Check on UCAM'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

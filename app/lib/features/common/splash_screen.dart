import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/brand_logo.dart';

/// Full-screen branded splash shown while the app boots / restores a session.
/// Static: the logo on the neutral surface and a small indicator, matching the
/// web boot loader so the hand-off is seamless.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(height: 60),
            SizedBox(height: Spacing.xxl),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

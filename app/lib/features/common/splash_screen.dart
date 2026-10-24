import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../shared/brand_logo.dart';
import '../../shared/states.dart';

/// Full-screen branded splash shown while the app boots / restores a session.
/// The logo rises in over the canvas with the Expressive loading indicator
/// beneath it, matching the web boot loader so the hand-off is seamless.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Reveal(child: BrandLogo(height: 60)),
            SizedBox(height: Spacing.xxl),
            Reveal(index: 2, child: ExpressiveLoader(size: 40)),
          ],
        ),
      ),
    );
  }
}

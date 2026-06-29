import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';

/// Full-screen branded splash shown while the app boots / restores a session.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: 0)
        ..springTo(1, Springs.spatialSlow);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Scaffold(
      // Surface-colored so the native pre-splash, this screen, and the app read
      // as one continuous background (no jarring full-color flash on reload).
      backgroundColor: scheme.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value.clamp(0.0, 1.2);
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.85 + 0.15 * t.clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand logo mark — orange tile with a blue gradient sheen
                    // so the brand colors greet the user immediately.
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.orange, // flat brand orange
                        borderRadius: BorderRadius.circular(Radii.xl),
                      ),
                      child: const Icon(Icons.school_rounded,
                          size: 52, color: Colors.white),
                    ),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      'Open Campus',
                      style: context.text.headlineMedium
                          ?.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

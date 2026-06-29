import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../shared/brand_logo.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';

/// One step of the post-login load.
class _Step {
  final String label;
  final Future<void> Function() run;
  const _Step(this.label, this.run);
}

/// Shown right after login: loads the core data with a visible, labelled
/// progress bar ("Loading your profile…"), then hands off to the app with a
/// smooth fade once everything is ready. If a step fails the app still proceeds
/// (the screens show their own cached/retry states), so a slow UCAM never traps
/// the user here.
class BootstrapScreen extends ConsumerStatefulWidget {
  final VoidCallback onReady;
  const BootstrapScreen({super.key, required this.onReady});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  late final List<_Step> _steps;
  int _index = 0;
  String _label = 'Getting things ready…';

  @override
  void initState() {
    super.initState();
    _steps = [
      _Step('Loading your profile',
          () => ref.read(homeProvider.notifier).load()),
      _Step('Fetching results',
          () => ref.read(resultsProvider.notifier).load()),
      _Step('Checking attendance',
          () => ref.read(attendanceProvider.notifier).load()),
      _Step('Loading notices',
          () => ref.read(noticesProvider.notifier).load()),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    for (var i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _index = i;
        _label = _steps[i].label;
      });
      try {
        await _steps[i].run();
      } catch (_) {
        // Non-fatal — screens have their own fallback. Keep going.
      }
    }
    if (!mounted) return;
    setState(() {
      _index = _steps.length;
      _label = 'Ready';
    });
    // Brief beat on "Ready" before handing off, so the fill completes visually.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final progress = _steps.isEmpty ? 1.0 : _index / _steps.length;
    // Once the profile step lands we can greet by first name.
    final home = ref.watch(homeProvider);
    final name = home is ResData<HomeSummary>
        ? home.loaded.data.name?.split(' ').first
        : null;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SpringIn(child: Center(child: BrandLogo(size: 76))),
              const SizedBox(height: Spacing.xxl),
              Text(
                name != null ? 'Welcome back, $name' : 'Setting up your campus',
                textAlign: TextAlign.center,
                style: context.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: Spacing.xl),
              // Animated progress bar.
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                  duration: Motion.medium,
                  curve: Motion.emphasized,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: _index == 0 && progress == 0 ? null : v,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              // Step label with a smooth crossfade as it changes.
              AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                            begin: const Offset(0, 0.25), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: Row(
                  key: ValueKey(_label),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_index < _steps.length) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: scheme.primary),
                      ),
                      const SizedBox(width: Spacing.sm),
                    ] else
                      Icon(Icons.check_circle,
                          size: 16, color: context.status.good),
                    if (_index >= _steps.length)
                      const SizedBox(width: Spacing.sm),
                    Flexible(
                      child: Text(
                        _label,
                        style: context.text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

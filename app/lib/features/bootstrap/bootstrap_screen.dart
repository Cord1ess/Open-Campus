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
  // Per-step completion, so the UI shows each item finishing independently as
  // its concurrent fetch lands — a live checklist, not one sequential label.
  late final List<bool> _stepDone;
  int _doneCount = 0;

  @override
  void initState() {
    super.initState();
    _steps = [
      _Step('Fetching your profile',
          () => ref.read(homeProvider.notifier).load()),
      _Step('Fetching your results & CGPA',
          () => ref.read(resultsProvider.notifier).load()),
      _Step('Fetching your attendance',
          () => ref.read(attendanceProvider.notifier).load()),
      _Step('Fetching notices',
          () => ref.read(noticesProvider.notifier).load()),
      // The academic calendar drives the dashboard's payment + upcoming-events
      // cards, so load it here too — otherwise those cards would pop in late
      // after the dashboard appears. Errors are swallowed by _run's try/catch.
      _Step('Fetching the academic calendar',
          () async {
        await ref.read(academicCalendarProvider.future);
      }),
    ];
    _stepDone = List<bool>.filled(_steps.length, false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    // Fire all fetches CONCURRENTLY — they're independent, so total wait is the
    // slowest single request, not the sum. Each step flips to "done" the moment
    // ITS request settles (in any order), so the checklist fills smoothly.
    await Future.wait(List.generate(_steps.length, (i) async {
      try {
        await _steps[i].run();
      } catch (_) {
        // Non-fatal — screens have their own fallback.
      }
      if (mounted) {
        setState(() {
          _stepDone[i] = true;
          _doneCount++;
        });
      }
    }));
    if (!mounted) return;
    // Brief beat on a fully-filled bar before handing off.
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (mounted) widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final progress = _steps.isEmpty ? 1.0 : _doneCount / _steps.length;
    // Once the profile step lands we can greet by first name (treat a blank
    // name from the backend as absent).
    final home = ref.watch(homeProvider);
    final rawName = home is ResData<HomeSummary>
        ? home.loaded.data.name?.trim()
        : null;
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName.split(' ').first
        : null;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SpringIn(child: Center(child: BrandLogo(height: 64))),
                const SizedBox(height: Spacing.xxl),
                Text(
                  name != null ? 'Welcome, $name' : 'Setting up your campus',
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Getting your latest information',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Spacing.xl),
                // Animated progress bar — fills smoothly as each fetch lands.
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                    duration: Motion.medium,
                    curve: Motion.emphasized,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: _doneCount == 0 ? null : v,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                // Live checklist: each row shows its own spinner → check as that
                // concurrent fetch settles, so the user sees exactly what's loading.
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: _StepRow(label: _steps[i].label, done: _stepDone[i]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One checklist row: a small spinner while its fetch is in flight, swapping to
/// a check (and dimming the label) the moment that fetch settles.
class _StepRow extends StatelessWidget {
  final String label;
  final bool done;
  const _StepRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: done
                ? Icon(Icons.check_circle_rounded,
                    key: const ValueKey('done'),
                    size: 18,
                    color: context.status.good)
                : SizedBox(
                    key: const ValueKey('loading'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: scheme.primary),
                  ),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: Motion.fast,
            style: context.text.bodyMedium!.copyWith(
              color: done ? scheme.onSurfaceVariant : scheme.onSurface,
              fontWeight: done ? FontWeight.w500 : FontWeight.w600,
            ),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}

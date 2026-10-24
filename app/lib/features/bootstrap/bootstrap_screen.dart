import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/brand_logo.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';

/// One step of the post-login load.
class _Step {
  final String label;
  final Future<void> Function() run;
  const _Step(this.label, this.run);
}

/// Shown right after login: loads the core data with a labelled progress bar
/// and checklist, then hands off to the app once everything is ready. If a step
/// fails the app still proceeds (the screens show their own cached/retry
/// states), so a slow UCAM never traps the user here.
class BootstrapScreen extends ConsumerStatefulWidget {
  final VoidCallback onReady;
  const BootstrapScreen({super.key, required this.onReady});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  late final List<_Step> _steps;
  // Per-step completion, so each row finishes independently as its concurrent
  // fetch lands.
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
      _Step(
          'Fetching notices', () => ref.read(noticesProvider.notifier).load()),
      // The academic calendar drives the dashboard's payment + upcoming-events
      // blocks, so load it here too. Errors are swallowed by _run's try/catch.
      _Step('Fetching the academic calendar', () async {
        await ref.read(academicCalendarProvider.future);
      }),
    ];
    _stepDone = List<bool>.filled(_steps.length, false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    // Fire all fetches CONCURRENTLY — total wait is the slowest request.
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
    final rawName =
        home is ResData<HomeSummary> ? home.loaded.data.name?.trim() : null;
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName.split(' ').first
        : null;

    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Reveal(child: Center(child: BrandLogo(height: 56))),
                const SizedBox(height: Spacing.xxl),
                Reveal(
                  index: 1,
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    child: Text(
                      name != null
                          ? 'Welcome, $name'
                          : 'Setting up your campus',
                      key: ValueKey(name),
                      textAlign: TextAlign.center,
                      style: context.text.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Getting your latest information',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: Spacing.xl),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.full),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress.clamp(0.0, 1.0)),
                    duration: Motion.slow,
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: _doneCount == 0 ? null : v,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                for (var i = 0; i < _steps.length; i++)
                  Reveal(
                    index: i + 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                      child:
                          _StepRow(label: _steps[i].label, done: _stepDone[i]),
                    ),
                  ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Nothing is stored on our servers.',
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One checklist row: a small indicator while its fetch is in flight, a check
/// (and a dimmed label) once it settles.
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
          width: 22,
          height: 22,
          child: AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: done
                ? Icon(AppIcons.success,
                    key: const ValueKey('done'),
                    size: 22,
                    color: context.palette.successInk)
                : const ExpressiveLoader(key: ValueKey('busy'), size: 20),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Text(
            label,
            style: context.text.bodyMedium?.copyWith(
                color: done ? scheme.onSurfaceVariant : scheme.onSurface),
          ),
        ),
      ],
    );
  }
}

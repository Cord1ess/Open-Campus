import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

/// First-run walkthrough: a centred card with three pages (How it works, Data
/// privacy, Features), each with a simple static illustration. Follows the
/// user's theme.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _count = 3;

  void _next() {
    if (_index < _count - 1) {
      _controller.nextPage(duration: Motion.medium, curve: Motion.emphasized);
    } else {
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _count - 1;
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Reveal(
                child: Panel(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('${_index + 1} of $_count',
                              style: context.text.labelMedium?.copyWith(
                                  color: context.scheme.onSurfaceVariant)),
                          const Spacer(),
                          if (!last)
                            TextButton(
                                onPressed: widget.onDone,
                                child: const Text('Skip')),
                        ],
                      ),
                      SizedBox(
                        height: 340,
                        child: PageView(
                          controller: _controller,
                          onPageChanged: (i) => setState(() => _index = i),
                          children: const [
                            _Card(
                              illustration: _HowItWorksArt(),
                              title: 'How it works',
                              body:
                                  'Open Campus is a cleaner window into your UCAM '
                                  'portal. You sign in with your own account; it '
                                  'fetches your results, attendance, routine and '
                                  'dues live and shows them clearly organised.',
                            ),
                            _Card(
                              illustration: _PrivacyArt(),
                              title: 'Your data stays yours',
                              body:
                                  'Your password is never stored, and our servers '
                                  'keep none of your data. Everything is fetched '
                                  'live from your own account and shown only to you.',
                            ),
                            _Card(
                              illustration: _FeaturesArt(),
                              title: 'Everything in one place',
                              body:
                                  'Results, attendance, routine, dues, notices and '
                                  'planning tools, with light and dark themes.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                      _Dots(count: _count, index: _index),
                      const SizedBox(height: Spacing.xl),
                      FilledButton(
                        onPressed: _next,
                        child: Text(last ? 'Get started' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single onboarding page: illustration, title, body.
class _Card extends StatelessWidget {
  final Widget illustration;
  final String title;
  final String body;
  const _Card({
    required this.illustration,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      child: Column(
        children: [
          SizedBox(height: 150, child: Center(child: illustration)),
          const SizedBox(height: Spacing.xl),
          Text(title,
              textAlign: TextAlign.center, style: context.text.titleLarge),
          const SizedBox(height: Spacing.sm),
          Text(body,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Page 1: phone → server → UCAM, three Expressive shapes joined by lines;
/// each shape turns slowly.
class _HowItWorksArt extends StatelessWidget {
  const _HowItWorksArt();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = context.scheme;
    Widget node(IconData icon, Hue hue, ExpressiveShapeKind kind, int secs) =>
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IdleSpin(
                period: Duration(seconds: secs),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: ShapeDecoration(
                    color: p.container(hue),
                    shape: ExpressiveShapeBorder(kind),
                  ),
                ),
              ),
              Icon(icon, size: 26, color: p.onContainer),
            ],
          ),
        );
    Widget line() => Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: scheme.outline,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        node(AppIcons.device, Hue.peach, ExpressiveShapeKind.cookie, 22),
        line(),
        node(AppIcons.server, Hue.sky, ExpressiveShapeKind.clover, 18),
        line(),
        node(AppIcons.academics, Hue.mint, ExpressiveShapeKind.flower, 26),
      ],
    );
  }
}

/// Page 2: a shield inside a slowly turning cookie shape.
class _PrivacyArt extends StatelessWidget {
  const _PrivacyArt();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IdleSpin(
            period: const Duration(seconds: 24),
            child: Container(
              width: 120,
              height: 120,
              decoration: ShapeDecoration(
                color: p.container(Hue.lavender),
                shape: const ExpressiveShapeBorder(ExpressiveShapeKind.cookie),
              ),
            ),
          ),
          IdleSpin(
            period: const Duration(seconds: 16),
            reverse: true,
            child: Container(
              width: 72,
              height: 72,
              decoration: ShapeDecoration(
                color: p.accent,
                shape: const ExpressiveShapeBorder(ExpressiveShapeKind.clover),
              ),
            ),
          ),
          Icon(AppIcons.privacy, size: 34, color: p.onAccent),
        ],
      ),
    );
  }
}

/// Page 3: the main features as pastel badges.
class _FeaturesArt extends StatelessWidget {
  const _FeaturesArt();

  static const _items = <(IconData, String, StatusTone)>[
    (AppIcons.results, 'Results', StatusTone.accent),
    (AppIcons.attendance, 'Attendance', StatusTone.success),
    (AppIcons.gpaTool, 'GPA planner', StatusTone.info),
    (AppIcons.dues, 'Dues', StatusTone.warning),
    (AppIcons.routine, 'Routine', StatusTone.neutral),
    (AppIcons.notices, 'Notices', StatusTone.danger),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final (i, (icon, label, tone)) in _items.indexed)
          Reveal(
            index: i,
            child: StatusBadge(label, icon: icon, tone: tone),
          ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasizedDecelerate,
            margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? p.ink : scheme.outline,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
      ],
    );
  }
}

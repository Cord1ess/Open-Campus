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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
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

/// Page 1: phone → server → UCAM, three nodes joined by lines.
class _HowItWorksArt extends StatelessWidget {
  const _HowItWorksArt();


  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    Widget node(IconData icon) => Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(icon, size: 24, color: scheme.onSurface),
        );
    Widget line() => Container(
          width: 32,
          height: 2,
          color: scheme.outline,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        node(AppIcons.device),
        line(),
        node(AppIcons.server),
        line(),
        node(AppIcons.academics),
      ],
    );
  }
}

/// Page 2: a shield in a soft accent circle.
class _PrivacyArt extends StatelessWidget {
  const _PrivacyArt();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: p.accentTint, shape: BoxShape.circle),
      child: Icon(AppIcons.privacy, size: 36, color: p.accentInk),
    );
  }
}

/// Page 3: the main feature names as badges.
class _FeaturesArt extends StatelessWidget {
  const _FeaturesArt();

  static const _items = <(IconData, String)>[
    (AppIcons.results, 'Results'),
    (AppIcons.attendance, 'Attendance'),
    (AppIcons.gpaTool, 'GPA planner'),
    (AppIcons.dues, 'Dues'),
    (AppIcons.routine, 'Routine'),
    (AppIcons.notices, 'Notices'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final (icon, label) in _items)
          StatusBadge(label, icon: icon, outlined: true),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? scheme.onSurface : scheme.outline,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

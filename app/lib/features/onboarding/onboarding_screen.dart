import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final IconData icon;
  final String title;
  final String body;
  const _Page(this.icon, this.title, this.body);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = <_Page>[
    _Page(
      Icons.auto_awesome_rounded,
      'UCAM, made simple',
      'Open Campus is a cleaner, faster way to use your UCAM student portal. '
          'Your results, attendance, routine, dues and more — organized the way '
          'they should be, on your phone.',
    ),
    _Page(
      Icons.lock_outline_rounded,
      'Your data stays yours',
      'You sign in with your own UCAM account. We never store your password, and '
          'our servers keep none of your data. Everything is fetched live from '
          'UCAM and shown only to you.',
    ),
    _Page(
      Icons.bolt_rounded,
      'Just a better window',
      'Think of it as a nicer browser for UCAM — it shows the same information '
          'you\'d see when you log in, just organized and beautiful. Nothing more, '
          'nothing less.',
    ),
  ];

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 420),
          curve: const Cubic(0.05, 0.7, 0.1, 1.0));
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
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: last ? 0 : 1,
                duration: Motion.fast,
                child: TextButton(
                  onPressed: last ? null : widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardPageView(_pages[i]),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            _Dots(count: _pages.length, index: _index),
            const SizedBox(height: Spacing.xl),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, 0, Spacing.xl, Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPageView extends StatelessWidget {
  final _Page page;
  const _OnboardPageView(this.page);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpringIn(
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.xl),
              ),
              child: Icon(page.icon,
                  size: 64, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          SpringIn(
            delayMs: 80,
            child: Text(page.title,
                textAlign: TextAlign.center,
                style: context.text.headlineMedium),
          ),
          const SizedBox(height: Spacing.md),
          SpringIn(
            delayMs: 140,
            child: Text(page.body,
                textAlign: TextAlign.center,
                style: context.text.bodyLarge
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
          ),
        ],
      ),
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
          AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasizedDecelerate,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/theme_controller.dart';

/// First-run walkthrough, presented as a centered MODAL card over a dimmed
/// backdrop (not a fullscreen takeover). Three cards — How it works, Data
/// privacy, Features & UI — each with a bespoke animated illustration. The
/// whole flow is forced to the default (Custom) light theme so the first
/// impression is always on-brand regardless of saved preferences.
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
      _controller.nextPage(
          duration: const Duration(milliseconds: 480),
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
    // Force the default Custom light theme for a consistent first impression.
    final theme =
        const ThemePrefs(seed: SeedSwatches.custom, mode: AppThemeMode.light)
            .light;
    final last = _index == _count - 1;

    return Theme(
      data: theme,
      child: Builder(builder: (context) {
        final scheme = theme.colorScheme;
        return Scaffold(
          // Dimmed brand-tinted backdrop the modal floats over.
          backgroundColor: const Color(0xFF0B1220),
          body: Stack(
            children: [
              const _Backdrop(),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: SpringIn(
                        dy: 0.06,
                        child: Material(
                          color: scheme.surface,
                          elevation: 16,
                          shadowColor: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(Radii.xl),
                          child: Padding(
                            padding: const EdgeInsets.all(Spacing.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Top row: step counter + Skip.
                                Row(
                                  children: [
                                    Text('${_index + 1} / $_count',
                                        style: context.text.labelMedium
                                            ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w700)),
                                    const Spacer(),
                                    AnimatedOpacity(
                                      opacity: last ? 0 : 1,
                                      duration: Motion.fast,
                                      child: TextButton(
                                        onPressed: last ? null : widget.onDone,
                                        child: const Text('Skip'),
                                      ),
                                    ),
                                  ],
                                ),
                                // The animated illustration + copy.
                                SizedBox(
                                  height: 380,
                                  child: PageView(
                                    controller: _controller,
                                    onPageChanged: (i) =>
                                        setState(() => _index = i),
                                    children: const [
                                      _Card(
                                        illustration: _HowItWorksArt(),
                                        title: 'How it works',
                                        body:
                                            'Open Campus is a cleaner window into '
                                            'your UCAM portal. You sign in with your '
                                            'own account; we fetch your results, '
                                            'attendance, routine and dues live — and '
                                            'show them, beautifully organized.',
                                      ),
                                      _Card(
                                        illustration: _PrivacyArt(),
                                        title: 'Your data stays yours',
                                        body:
                                            'Your password is never stored, and our '
                                            'servers keep none of your data. Everything '
                                            'is fetched live from your own account and '
                                            'shown only to you — nothing is collected.',
                                      ),
                                      _Card(
                                        illustration: _FeaturesArt(),
                                        title: 'Designed to feel great',
                                        body:
                                            'Charts, a GPA planner, attendance, dues, '
                                            'routines and notices — in a fast, modern '
                                            'interface with light & dark themes you can '
                                            'make your own.',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: Spacing.lg),
                                _Dots(count: _count, index: _index),
                                const SizedBox(height: Spacing.xl),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _next,
                                    child: Text(last ? 'Get started' : 'Next'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// A single onboarding card: animated illustration, title, body. The
/// illustration re-keys per build so its entrance animation replays when the
/// card scrolls into view.
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
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      child: Column(
        children: [
          SizedBox(height: 168, child: Center(child: illustration)),
          const SizedBox(height: Spacing.xl),
          Text(title,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Spacing.sm),
          Text(body,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
        ],
      ),
    );
  }
}

/// Subtle moving radial glows behind the modal for depth.
class _Backdrop extends StatefulWidget {
  const _Backdrop();
  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _BackdropPainter(_c.value),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final double t;
  _BackdropPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }

    final a = 2 * math.pi * t;
    glow(
      Offset(size.width * (0.25 + 0.1 * math.sin(a)),
          size.height * (0.22 + 0.06 * math.cos(a))),
      size.shortestSide * 0.6,
      AppColors.orange.withValues(alpha: 0.22),
    );
    glow(
      Offset(size.width * (0.8 + 0.08 * math.cos(a)),
          size.height * (0.78 + 0.06 * math.sin(a))),
      size.shortestSide * 0.7,
      AppColors.blue.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Card 1 — How it works: phone ↔ server ↔ UCAM with a packet pulsing across.
// ---------------------------------------------------------------------------
class _HowItWorksArt extends StatefulWidget {
  const _HowItWorksArt();
  @override
  State<_HowItWorksArt> createState() => _HowItWorksArtState();
}

class _HowItWorksArtState extends State<_HowItWorksArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: const Size(280, 150),
        painter: _FlowPainter(
          _c.value,
          line: scheme.outlineVariant,
          a: scheme.primary,
          b: scheme.secondary,
          node: scheme.surfaceContainerHigh,
          onNode: scheme.onSurface,
        ),
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  final double t;
  final Color line, a, b, node, onNode;
  _FlowPainter(this.t,
      {required this.line,
      required this.a,
      required this.b,
      required this.node,
      required this.onNode});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final lx = size.width * 0.12;
    final mx = size.width * 0.5;
    final rx = size.width * 0.88;

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(lx, cy), Offset(rx, cy), linePaint);

    // Two packets traveling in opposite directions (request out, data back).
    void packet(double phase, Color color, bool ltr) {
      final p = (t + phase) % 1.0;
      final x = ltr ? lx + (rx - lx) * p : rx - (rx - lx) * p;
      final glow = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, cy), 9, glow);
      canvas.drawCircle(Offset(x, cy), 5, Paint()..color = color);
    }

    packet(0.0, a, true);
    packet(0.5, b, false);

    // Nodes: phone (left), server (mid), UCAM (right).
    void chip(double x, IconData icon, Color ring) {
      const r = 26.0;
      canvas.drawCircle(Offset(x, cy), r, Paint()..color = node);
      canvas.drawCircle(
          Offset(x, cy),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ring);
      final tp = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
                fontSize: 24,
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                color: onNode)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, cy - tp.height / 2));
    }

    chip(lx, Icons.phone_iphone_rounded, a);
    chip(mx, Icons.dns_rounded, b);
    chip(rx, Icons.school_rounded, a);
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Card 2 — Data privacy: a shield that draws on with a check, lock pulses.
// ---------------------------------------------------------------------------
class _PrivacyArt extends StatefulWidget {
  const _PrivacyArt();
  @override
  State<_PrivacyArt> createState() => _PrivacyArtState();
}

class _PrivacyArtState extends State<_PrivacyArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // Gentle breathing pulse.
        final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * _c.value);
        return CustomPaint(
          size: const Size(160, 160),
          painter: _ShieldPainter(
            pulse,
            fill: scheme.primary,
            ring: scheme.secondary,
            glyph: Colors.white,
          ),
        );
      },
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final double pulse;
  final Color fill, ring, glyph;
  _ShieldPainter(this.pulse,
      {required this.fill, required this.ring, required this.glyph});

  Path _shieldPath(Size s) {
    final w = s.width, h = s.height;
    final p = Path();
    p.moveTo(w * 0.5, h * 0.08);
    p.lineTo(w * 0.86, h * 0.22);
    p.lineTo(w * 0.86, h * 0.52);
    p.cubicTo(w * 0.86, h * 0.78, w * 0.7, h * 0.9, w * 0.5, h * 0.96);
    p.cubicTo(w * 0.3, h * 0.9, w * 0.14, h * 0.78, w * 0.14, h * 0.52);
    p.lineTo(w * 0.14, h * 0.22);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Expanding aura ring (the "protected" pulse).
    final auraR = size.width * (0.5 + 0.18 * pulse);
    canvas.drawCircle(
        center,
        auraR,
        Paint()
          ..color = ring.withValues(alpha: 0.18 * (1 - pulse))
          ..style = PaintingStyle.fill);

    final shield = _shieldPath(size);
    // Soft shadow.
    canvas.drawPath(
        shield.shift(const Offset(0, 4)),
        Paint()
          ..color = fill.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(shield, Paint()..color = fill);

    // Lock glyph centered on the shield.
    final tp = TextPainter(
      text: TextSpan(
          text: String.fromCharCode(Icons.lock_rounded.codePoint),
          style: TextStyle(
              fontSize: size.width * 0.34,
              fontFamily: Icons.lock_rounded.fontFamily,
              color: glyph)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 - 4));
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter old) => old.pulse != pulse;
}

// ---------------------------------------------------------------------------
// Card 3 — Features & UI: a cluster of feature chips that float/stagger in.
// ---------------------------------------------------------------------------
class _FeaturesArt extends StatelessWidget {
  const _FeaturesArt();

  static const _items = <(IconData, String, bool)>[
    (Icons.insights_rounded, 'CGPA', true),
    (Icons.event_available_rounded, 'Attendance', false),
    (Icons.calculate_rounded, 'GPA planner', false),
    (Icons.account_balance_wallet_rounded, 'Dues', true),
    (Icons.calendar_month_rounded, 'Routine', false),
    (Icons.campaign_rounded, 'Notices', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (var i = 0; i < _items.length; i++)
          _FloatChip(
            delayMs: 60 * i,
            icon: _items[i].$1,
            label: _items[i].$2,
            filled: _items[i].$3,
          ),
      ],
    );
  }
}

class _FloatChip extends StatefulWidget {
  final int delayMs;
  final IconData icon;
  final String label;
  final bool filled;
  const _FloatChip({
    required this.delayMs,
    required this.icon,
    required this.label,
    required this.filled,
  });

  @override
  State<_FloatChip> createState() => _FloatChipState();
}

class _FloatChipState extends State<_FloatChip>
    with TickerProviderStateMixin {
  late final AnimationController _in =
      AnimationController.unbounded(vsync: this);
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _in.springTo(1, Springs.spatialSlow);
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = widget.filled ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = widget.filled ? Colors.white : scheme.onSurface;
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _float]),
      builder: (_, child) {
        final t = _in.value.clamp(0.0, 1.0);
        final bob = math.sin(2 * math.pi * _float.value) * 3;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24 + bob),
            child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
          ),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.full),
          border:
              widget.filled ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(widget.label,
                style: context.text.labelLarge
                    ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
          ],
        ),
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

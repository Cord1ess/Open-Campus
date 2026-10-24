import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Navigation helper: a standard route using the app's PageTransitionsTheme.
/// Every push goes through this so transitions are identical everywhere.
Route<T> appRoute<T>(Widget page) =>
    MaterialPageRoute<T>(builder: (_) => page);

/// True when the user asked the OS to reduce motion. Every animation below
/// collapses to its end state in that case.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Expressive spring presets (stiffness/damping in the M3 Expressive range).
class Springs {
  /// Spatial (position/scale): quick with a little overshoot.
  static final spatial =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 520, ratio: 0.72);

  /// Effects (opacity/colour): no overshoot.
  static final effects =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 900, ratio: 1);
}

/// Fades and rises its child into place once, after [index] × [stagger]. Use
/// on sections and list items so pages assemble rather than pop in.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration stagger;
  final double offset;
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 55),
    this.offset = 18,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0 || _done) return;
    if (reduceMotion(context)) {
      _done = true;
      return;
    }
    final delay = widget.stagger * widget.index.clamp(0, 12);
    Future.delayed(delay, () {
      if (!mounted) return;
      _c.forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Wraps tappable surfaces: squishes slightly on press and springs back.
class PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double pressed;
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressed = 0.965,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: 1);

  void _to(double target) {
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    _c.animateWith(SpringSimulation(Springs.spatial, _c.value, target, 0));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => _to(widget.pressed),
      onPointerUp: (_) => _to(1),
      onPointerCancel: (_) => _to(1),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(scale: _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Animates a number from its previous value (0 on first show) to [value].
class CountUp extends StatelessWidget {
  final double value;
  final String Function(double v) format;
  final TextStyle? style;
  final Duration duration;
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format(v), maxLines: 1, style: style),
    );
  }
}

/// Slowly rotates (and gently bobs) its child forever: idle motion for
/// decorative shapes. One full turn per [period].
class IdleSpin extends StatefulWidget {
  final Widget child;
  final Duration period;
  final bool reverse;
  final double bob;
  const IdleSpin({
    super.key,
    required this.child,
    this.period = const Duration(seconds: 24),
    this.reverse = false,
    this.bob = 0,
  });

  @override
  State<IdleSpin> createState() => _IdleSpinState();
}

class _IdleSpinState extends State<IdleSpin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final a = _c.value * 2 * math.pi * (widget.reverse ? -1 : 1);
          final dy = math.sin(_c.value * 4 * math.pi) * widget.bob;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(angle: a, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A dot with an expanding halo, for "live / now" states.
class LiveDot extends StatefulWidget {
  final Color color;
  final double size;
  const LiveDot({super.key, required this.color, this.size = 8});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final dot = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (reduceMotion(context)) return dot;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: s + s * 1.4 * t,
                height: s + s * 1.4 * t,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                  shape: BoxShape.circle,
                ),
              ),
              dot,
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Material 3 Expressive motion — spring physics.
///
/// Expressive replaces easing+duration with spring-based motion. Two families:
///   - Spatial springs: position/size/layout (have a little bounce → "alive").
///   - Effects springs:  color/opacity/elevation (no bounce, just smooth).
/// Each in fast / default / slow. Values mirror the M3 Expressive spring tokens
/// (stiffness + damping ratio), expressed as Flutter SpringDescriptions.
class Springs {
  // Spatial — damping ratio ~0.8 gives a subtle, premium bounce.
  static final spatialFast =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1400, ratio: 0.8);
  static final spatialDefault =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.8);
  static final spatialSlow =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);

  // Effects — critically damped (ratio 1) → smooth, no overshoot.
  static final effectsFast =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 3800, ratio: 1);
  static final effectsDefault =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1600, ratio: 1);
}

/// Drives a value with a spring simulation (for AnimationController.animateWith).
extension SpringDrive on AnimationController {
  TickerFuture springTo(double target, SpringDescription spring,
      {double velocity = 0}) {
    final sim = SpringSimulation(spring, value, target, velocity);
    return animateWith(sim);
  }
}

/// Entrance: fade + spring-slide up. The slide uses a real spring so it settles
/// with a subtle, expressive bounce rather than a linear ease.
class SpringIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double dy;
  const SpringIn({super.key, required this.child, this.delayMs = 0, this.dy = 0.16});

  @override
  State<SpringIn> createState() => _SpringInState();
}

class _SpringInState extends State<SpringIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: 0);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      // Softer spring → the entrance is slower and clearly visible (fluid),
      // settling with a gentle, premium bounce rather than snapping in.
      if (mounted) _c.springTo(1, Springs.spatialSlow);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.dy * 120),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A tap target that springs down on press and back up on release, with a
/// haptic tick. Wrap any interactive surface. Adds a Material ripple when a
/// borderRadius is given.
class SpringTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final BorderRadius? borderRadius;
  final bool haptic;
  const SpringTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressScale = 0.95,
    this.borderRadius,
    this.haptic = true,
  });

  @override
  State<SpringTap> createState() => _SpringTapState();
}

class _SpringTapState extends State<SpringTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: 1.0);

  void _down(_) {
    _c.springTo(widget.pressScale, Springs.spatialFast);
    if (widget.haptic) HapticFeedback.lightImpact();
  }

  void _up([_]) => _c.springTo(1.0, Springs.spatialFast);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.borderRadius != null && widget.onTap != null) {
      child = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          child: child,
        ),
      );
    }
    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      onTap: widget.borderRadius != null ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, c) =>
            Transform.scale(scale: _c.value.clamp(0.9, 1.05), child: c),
        child: child,
      ),
    );
  }
}

/// Count-up animation for numbers (CGPA, %, balance). Springs from 0 → value.
class CountUp extends StatelessWidget {
  final double value;
  final int decimals;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  const CountUp(
    this.value, {
    super.key,
    this.decimals = 2,
    this.prefix = '',
    this.suffix = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) =>
          Text('$prefix${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// Staggered list: wraps children so each springs in with an increasing delay.
class StaggerList extends StatelessWidget {
  final List<Widget> children;
  final int stepMs;
  final int baseMs;
  const StaggerList(
      {super.key, required this.children, this.stepMs = 55, this.baseMs = 0});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          SpringIn(delayMs: baseMs + i * stepMs, child: children[i]),
      ],
    );
  }
}

/// Shared-axis (X) transition for card → detail navigation: the incoming page
/// slides in from the right while fading in; the outgoing page slides slightly
/// left and fades back. On reverse both invert, so motion always reads as moving
/// forward/backward along one axis rather than a generic fade.
Route<T> sharedAxisRoute<T>(Widget page) {
  const inCurve = Cubic(0.05, 0.7, 0.1, 1.0); // emphasized decelerate
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, secondary, child) {
      final entering = CurvedAnimation(parent: anim, curve: inCurve);
      // Outgoing (this page being covered) drifts left + dims.
      final leaving = CurvedAnimation(parent: secondary, curve: inCurve);
      return FadeTransition(
        opacity: entering,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.10, 0), end: Offset.zero)
              .animate(entering),
          child: SlideTransition(
            position: Tween(begin: Offset.zero, end: const Offset(-0.06, 0))
                .animate(leaving),
            child: FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.85).animate(leaving),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

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
  // Entrance: softer + slightly heavier than spatialSlow so the slide-up travels
  // a longer, clearly visible distance and settles smoothly (a touch of bounce).
  static final entrance =
      SpringDescription.withDampingRatio(mass: 1.1, stiffness: 260, ratio: 0.82);

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

/// Entrance: a prominent, smooth spring-slide UP. The element starts well below
/// its resting position and travels up on a soft spring so the SLIDE is the
/// motion you notice — not a fade. Opacity ramps in quickly (resolving early in
/// the travel) so the content is clearly visible while it's still moving, rather
/// than fading in at the end.
class SpringIn extends StatefulWidget {
  final Widget child;
  final int delayMs;

  /// Slide distance as a fraction of [_travelPx]. Larger = more pronounced rise.
  final double dy;
  const SpringIn({super.key, required this.child, this.delayMs = 0, this.dy = 1.0});

  /// Base upward travel in logical pixels at dy == 1.0. Generous so the slide
  /// reads clearly as movement.
  static const double _travelPx = 64;

  @override
  State<SpringIn> createState() => _SpringInState();
}

class _SpringInState extends State<SpringIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: 0);
  // Once the entrance settles we drop the AnimatedBuilder/Opacity/Transform
  // wrappers entirely and render the plain child — so finished items add ZERO
  // per-frame cost (Opacity in particular is expensive to keep around).
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      _c.springTo(1, Springs.entrance).whenCompleteOrCancel(() {
        if (mounted && !_done) setState(() => _done = true);
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
    if (_done) return widget.child; // settled → no animation overhead
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        if (t >= 1.0) return child!; // fully settled this frame
        // Opacity resolves early (by ~40% of the travel) so the content is
        // visible during the slide — the rise, not the fade, is the motion.
        final opacity = (t * 2.5).clamp(0.0, 1.0);
        final offsetY = (1 - t.clamp(0.0, 1.0)) * widget.dy * SpringIn._travelPx;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offsetY),
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
    // No tap handler → nothing to animate; pass the child straight through so
    // decorative wrappers don't run an idle controller + gesture detector.
    if (widget.onTap == null) return widget.child;

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

/// Card → detail navigation route — used for EVERY page push so the whole app
/// has one consistent motion: the incoming page slides in from the right and
/// fades in; the outgoing page drifts slightly left and dims. Reverse plays it
/// backwards (page slides back out to the right).
///
/// The same horizontal transition is used on every platform, including Android.
/// Android's **predictive-back gesture** still works: the system drives this
/// route's [animation] in reverse as you swipe, so the page is dragged back
/// along the same horizontal axis (we just don't use the native vertical peek,
/// keeping motion identical to the rest of the app).
Route<T> sharedAxisRoute<T>(Widget page) => _SharedAxisRoute<T>(page);

class _SharedAxisRoute<T> extends PageRouteBuilder<T> {
  _SharedAxisRoute(this.page)
      : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 340),
          pageBuilder: (_, __, ___) => page,
        );

  final Widget page;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // One shared-axis (X) look on all platforms. `animation` runs forward on
    // push and in reverse under the predictive-back swipe, so the gesture drags
    // the page back along this same horizontal axis.
    const inCurve = Cubic(0.05, 0.7, 0.1, 1.0); // emphasized decelerate
    final entering = CurvedAnimation(parent: animation, curve: inCurve);
    final leaving = CurvedAnimation(parent: secondaryAnimation, curve: inCurve);
    // Perf: ONE fade only, on the entering page. Each FadeTransition is a
    // saveLayer (offscreen buffer) — the most expensive primitive on web — so
    // the previous nested two-fade version cost two full-page saveLayers per
    // navigation. The leaving page now slides without fading (the dim earned
    // nothing and cost a saveLayer); slides are nearly free.
    return FadeTransition(
      opacity: entering,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.10, 0), end: Offset.zero)
            .animate(entering),
        child: SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-0.06, 0))
              .animate(leaving),
          child: child,
        ),
      ),
    );
  }
}

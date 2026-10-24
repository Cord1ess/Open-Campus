import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Material 3 Expressive shape library (a subset), drawn as smooth polar
/// outlines so they scale crisply at any size: the scalloped "cookie", the
/// four-leaf "clover", a softer eight-lobe "flower", a rounded "burst", and a
/// plain circle. Used as containers for icons and avatars, the way Expressive
/// mixes round and scalloped forms for emphasis.
enum ExpressiveShapeKind { circle, cookie, clover, flower, burst }

class ExpressiveShapeBorder extends ShapeBorder {
  final ExpressiveShapeKind kind;
  final double rotation;
  const ExpressiveShapeBorder(this.kind, {this.rotation = 0});

  (int lobes, double depth) get _spec => switch (kind) {
        ExpressiveShapeKind.circle => (0, 0.0),
        ExpressiveShapeKind.cookie => (9, 0.055),
        ExpressiveShapeKind.clover => (4, 0.16),
        ExpressiveShapeKind.flower => (8, 0.085),
        ExpressiveShapeKind.burst => (12, 0.045),
      };

  Path _path(Rect rect) {
    final (lobes, depth) = _spec;
    if (lobes == 0) return Path()..addOval(rect);
    final c = rect.center;
    final r = math.min(rect.width, rect.height) / 2 / (1 + depth);
    final path = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      // Smooth lobes: a raised cosine keeps the valleys round, not pointed.
      final wave = math.cos(lobes * (t + rotation));
      final rr = r * (1 + depth * wave);
      final p = Offset(c.dx + rr * math.cos(t), c.dy + rr * math.sin(t));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// An icon centred in an Expressive shape filled with a pastel container.
class ShapeIcon extends StatelessWidget {
  final IconData icon;
  final Hue hue;
  final ExpressiveShapeKind shape;
  final double size;
  final Color? color;
  const ShapeIcon(
    this.icon, {
    super.key,
    this.hue = Hue.peach,
    this.shape = ExpressiveShapeKind.cookie,
    this.size = 48,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: color ?? p.container(hue),
        shape: ExpressiveShapeBorder(shape),
      ),
      child: Icon(icon, size: size * 0.46, color: p.onContainer),
    );
  }
}

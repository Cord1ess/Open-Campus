import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../core/theme/app_theme.dart';
import 'app_icons.dart';
import 'expressive_shape.dart';

/// The Material 3 Expressive loading indicator: a filled shape that rotates
/// while morphing between a scalloped cookie and a four-leaf clover.
class ExpressiveLoader extends StatefulWidget {
  final double size;
  final Color? color;
  const ExpressiveLoader({super.key, this.size = 40, this.color});

  @override
  State<ExpressiveLoader> createState() => _ExpressiveLoaderState();
}

class _ExpressiveLoaderState extends State<ExpressiveLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.palette.accent;
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: _MorphPainter(_c.value, color),
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphPainter extends CustomPainter {
  final double t;
  final Color color;
  _MorphPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Ease between the two shapes twice per turn.
    final m = 0.5 - 0.5 * math.cos(t * 4 * math.pi);
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 2 / 1.16;
    final rot = t * 2 * math.pi;
    final path = Path();
    const steps = 160;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * math.pi;
      final cookie = 1 + 0.06 * math.cos(9 * (a + rot));
      final clover = 1 + 0.16 * math.cos(4 * (a + rot));
      final r = base * (cookie + (clover - cookie) * m);
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MorphPainter old) => old.t != t || old.color != color;
}

/// Loading: the Expressive loader with an optional label.
class LoadingState extends StatelessWidget {
  final String? label;
  final double verticalPadding;
  const LoadingState({super.key, this.label, this.verticalPadding = Spacing.xxl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExpressiveLoader(size: 36),
            if (label != null) ...[
              const SizedBox(height: Spacing.md),
              Text(label!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state: icon, title, optional explanation and one optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final bool compact;
  final Hue hue;
  const EmptyState({
    super.key,
    this.icon = AppIcons.empty,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.compact = false,
    this.hue = Hue.lavender,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: compact ? Spacing.lg : Spacing.xxl, horizontal: Spacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShapeIcon(icon,
                  hue: hue,
                  shape: ExpressiveShapeKind.cookie,
                  size: compact ? 52 : 72),
              SizedBox(height: compact ? Spacing.md : Spacing.lg),
              Text(title,
                  textAlign: TextAlign.center,
                  style: compact ? context.text.titleMedium : context.text.titleLarge),
              if (message != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(message!,
                    textAlign: TextAlign.center, style: context.text.bodySmall),
              ],
              if (onAction != null) ...[
                const SizedBox(height: Spacing.lg),
                actionIcon != null
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: context.palette.ink,
                            foregroundColor: context.palette.onInk),
                        onPressed: onAction,
                        icon: Icon(actionIcon, size: 18),
                        label: Text(actionLabel ?? 'Retry'),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: context.palette.ink,
                            foregroundColor: context.palette.onInk),
                        onPressed: onAction,
                        child: Text(actionLabel ?? 'Retry'),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with a retry action.
class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;
  const ErrorState({
    super.key,
    this.title = 'Couldn’t load',
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: AppIcons.offline,
        title: title,
        message: message,
        actionLabel: 'Try again',
        actionIcon: AppIcons.refresh,
        onAction: onRetry,
        compact: compact,
        hue: Hue.rose,
      );
}

/// One-line freshness indicator shown above cached content: tells the user
/// the data is an on-device copy, when it was fetched, and (if a refresh just
/// failed) why, with a retry.
class FreshnessLine extends StatelessWidget {
  final DateTime? at;
  final bool live;
  final String? error;
  final VoidCallback? onRetry;
  const FreshnessLine({
    super.key,
    this.at,
    this.live = false,
    this.error,
    this.onRetry,
  });

  static String ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (live && error == null) return const SizedBox.shrink();
    final p = context.palette;
    final tone = error != null ? StatusTone.warning : StatusTone.neutral;
    final ink = p.inkFor(tone, context.scheme);
    final when = at != null ? ' · updated ${ago(at!)}' : '';
    final text = error != null
        ? 'Couldn’t refresh — showing saved copy$when'
        : 'Saved copy$when';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: [
          Icon(error != null ? AppIcons.offline : AppIcons.time,
              size: 14, color: ink),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: ink)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  visualDensity: VisualDensity.compact),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

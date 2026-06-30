import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A tiny always-on-top FPS readout for diagnosing the "choppy on a high-refresh
/// screen" reports. It measures the real interval between rendered frames via
/// [SchedulerBinding.addTimingsCallback] (actual presented frames, not a guess),
/// so on a 120Hz display a smooth app reads ~120 and a janky one reads lower.
///
/// OFF by default and compiled out of normal builds — it only appears when the
/// app is started with `--dart-define=OC_FPS=true`. Wrapping a subtree in it when
/// the flag is off returns the child untouched (zero cost).
///
///   flutter build web --wasm --release --dart-define=OC_FPS=true
class FpsOverlay extends StatefulWidget {
  final Widget child;
  const FpsOverlay({super.key, required this.child});

  /// Whether the diagnostic build flag is set.
  static const bool enabled =
      bool.fromEnvironment('OC_FPS', defaultValue: false);

  @override
  State<FpsOverlay> createState() => _FpsOverlayState();
}

class _FpsOverlayState extends State<FpsOverlay> {
  // Rolling window of recent frame durations (in microseconds).
  final List<int> _durations = [];
  double _fps = 0;
  double _worstMs = 0;

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      // Total time from frame build start to raster finish = the frame's cost.
      final micros = t.totalSpan.inMicroseconds;
      if (micros > 0) _durations.add(micros);
    }
    // Keep the last ~60 frames for a stable average.
    if (_durations.length > 60) {
      _durations.removeRange(0, _durations.length - 60);
    }
    if (_durations.isEmpty) return;
    final avg = _durations.reduce((a, b) => a + b) / _durations.length;
    final worst = _durations.reduce((a, b) => a > b ? a : b);
    final fps = avg > 0 ? 1000000.0 / avg : 0.0;
    if (mounted) {
      setState(() {
        _fps = fps;
        _worstMs = worst / 1000.0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fps = _fps.clamp(0, 240);
    // Green ≥100, amber ≥55, red below — quick visual read on a 120Hz panel.
    final color = fps >= 100
        ? const Color(0xFF35D07F)
        : fps >= 55
            ? const Color(0xFFFFC400)
            : const Color(0xFFEF4D4D);
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned(
          top: 40,
          right: 12,
          child: IgnorePointer(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${fps.toStringAsFixed(0)} fps · ${_worstMs.toStringAsFixed(1)}ms',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

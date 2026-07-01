import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A profile avatar with a proper image fit, a soft shadow, and a fallback
/// person icon. Using a sized ClipOval + Image.memory (BoxFit.cover, centered)
/// avoids the "zoomed in" look CircleAvatar's foregroundImage can produce.
class Avatar extends StatefulWidget {
  final List<int>? bytes;
  final double radius;
  const Avatar({super.key, required this.bytes, this.radius = 22});

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  // Cache the Uint8List so we don't copy the (potentially multi-MB) image bytes
  // on every build, and so Image.memory's cache keys on a stable instance rather
  // than re-decoding each frame. Rebuilt only when the source bytes change.
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _rebuildBytes();
  }

  @override
  void didUpdateWidget(covariant Avatar old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) _rebuildBytes();
  }

  void _rebuildBytes() {
    final b = widget.bytes;
    _imageBytes = (b != null && b.isNotEmpty)
        ? (b is Uint8List ? b : Uint8List.fromList(b))
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final radius = widget.radius;
    final size = radius * 2;
    final imageBytes = _imageBytes;
    final hasImage = imageBytes != null;
    // Decode the photo at display resolution (not full UCAM resolution) so a
    // large profile JPEG doesn't sit in memory as a multi-MB bitmap to draw a
    // small circle. cacheWidth/Height are in physical pixels, hence the DPR.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodePx = (size * dpr).round();

    // Neutral fallback: a person glyph on a muted surface — no bright accent
    // circle that could bleed around the photo's edges or flash before it loads.
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.person_rounded,
          size: radius * 1.1, color: scheme.onSurfaceVariant),
    );

    // ClipOval sized EXACTLY to the circle, with the content (image or fallback)
    // filling it edge-to-edge via BoxFit.cover — so nothing shows behind/around
    // it (no bleed) and the photo isn't squashed. A thin outline gives a crisp
    // edge without a colored ring.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: radius * 0.35,
            offset: Offset(0, radius * 0.1),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? Image.memory(
                imageBytes,
                width: size,
                height: size,
                cacheWidth: decodePx,
                cacheHeight: decodePx,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter, // faces sit a touch high
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

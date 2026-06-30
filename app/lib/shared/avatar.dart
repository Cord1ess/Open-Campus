import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A profile avatar with a proper image fit, a soft shadow, and a fallback
/// person icon. Using a sized ClipOval + Image.memory (BoxFit.cover, centered)
/// avoids the "zoomed in" look CircleAvatar's foregroundImage can produce.
class Avatar extends StatelessWidget {
  final List<int>? bytes;
  final double radius;
  const Avatar({super.key, required this.bytes, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final size = radius * 2;
    final hasImage = bytes != null && bytes!.isNotEmpty;
    // Decode the photo at display resolution (not full UCAM resolution) so a
    // large profile JPEG doesn't sit in memory as a multi-MB bitmap to draw a
    // ~44px circle. cacheWidth/Height are in physical pixels, hence the DPR.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodePx = (size * dpr).round();
    // Convert to Uint8List once here rather than per Image build.
    final imageBytes = hasImage ? Uint8List.fromList(bytes!) : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.22),
            blurRadius: radius * 0.4,
            offset: Offset(0, radius * 0.12),
          ),
        ],
      ),
      child: (!hasImage)
          ? Icon(Icons.person,
              size: radius * 1.0, color: scheme.onPrimaryContainer)
          : ClipOval(
              child: Image.memory(
                imageBytes!,
                width: size,
                height: size,
                cacheWidth: decodePx,
                cacheHeight: decodePx,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter, // faces sit a touch high
                gaplessPlayback: true,
                // A corrupt/undecodable image falls back to the person icon
                // instead of Flutter's broken-image box.
                errorBuilder: (_, __, ___) => Icon(Icons.person,
                    size: radius * 1.0, color: scheme.onPrimaryContainer),
              ),
            ),
    );
  }
}

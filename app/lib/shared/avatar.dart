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
      child: bytes == null
          ? Icon(Icons.person,
              size: radius * 1.0, color: scheme.onPrimaryContainer)
          : ClipOval(
              child: Image.memory(
                Uint8List.fromList(bytes!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter, // faces sit a touch high
                gaplessPlayback: true,
              ),
            ),
    );
  }
}

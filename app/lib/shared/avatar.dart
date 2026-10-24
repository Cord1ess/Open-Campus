import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_icons.dart';

/// A circular profile photo with a hairline edge and a neutral fallback glyph.
class Avatar extends StatefulWidget {
  final List<int>? bytes;
  final double radius;
  const Avatar({super.key, required this.bytes, this.radius = 20});

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  // Cache the Uint8List so the image isn't re-copied / re-decoded every build.
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
    final size = widget.radius * 2;
    final imageBytes = _imageBytes;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodePx = (size * dpr).round();

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: scheme.surfaceContainerHigh,
      child: Icon(AppIcons.profile,
          size: widget.radius * 1.1, color: scheme.onSurfaceVariant),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipOval(
        child: imageBytes != null
            ? Image.memory(
                imageBytes,
                width: size,
                height: size,
                cacheWidth: decodePx,
                cacheHeight: decodePx,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

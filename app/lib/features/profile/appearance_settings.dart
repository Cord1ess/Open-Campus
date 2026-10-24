import 'package:flutter/material.dart';

import 'settings_sections.dart';

/// Appearance settings: accent colour + Light / Dark / Black. Thin wrapper kept
/// for existing imports; the implementation lives in [AppearanceSection].
class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) => const AppearanceSection();
}

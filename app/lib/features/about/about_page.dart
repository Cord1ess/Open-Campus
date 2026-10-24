import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../profile/settings_sections.dart';

/// Settings page reachable from the login screen (before sign-in): appearance,
/// server status, storage, and about/links. The same sections appear on the
/// Profile page once signed in.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Settings',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: const Stacked(
            children: [
              AppearanceSection(),
              ServerStatusSection(),
              StorageSection(),
              AboutSection(),
            ],
          ),
        ),
      ),
    );
  }
}

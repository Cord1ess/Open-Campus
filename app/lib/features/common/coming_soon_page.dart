import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

/// The UCAM portal entry point. Unmapped features deep-link here (login page);
/// the student continues in the browser.
const ucamPortalUrl = 'https://ucam.uiu.ac.bd';

Future<void> openUcam(BuildContext context) async {
  final uri = Uri.parse(ucamPortalUrl);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Couldn\'t open UCAM.')),
    );
  }
}

/// Placeholder detail for a feature that isn't wired yet. Minimal: a "coming
/// soon" mark and a button to open UCAM for it.
class ComingSoonPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const ComingSoonPage({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SpringIn(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(Radii.xl),
                  ),
                  child:
                      Icon(icon, size: 44, color: scheme.onSecondaryContainer),
                ),
                const SizedBox(height: Spacing.xl),
                Text(title,
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall),
                const SizedBox(height: Spacing.sm),
                Text('Coming soon',
                    style: context.text.titleMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: Spacing.xl),
                FilledButton.icon(
                  onPressed: () => openUcam(context),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open in UCAM'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

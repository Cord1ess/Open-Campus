import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets.dart';

/// The UCAM portal entry point. Features not mapped in the app deep-link here.
const ucamPortalUrl = 'https://ucam.uiu.ac.bd';

Future<void> openUcam(BuildContext context) async {
  final uri = Uri.parse(ucamPortalUrl);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Couldn’t open UCAM.')),
    );
  }
}

/// Placeholder for a feature that isn't wired yet: a short message and a way
/// to do it on UCAM.
class ComingSoonPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const ComingSoonPage({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: title,
      body: Reveal(
        child: EmptyState(
          icon: icon,
          title: 'Not available in Open Campus yet',
          message:
              'This feature is still only on the UCAM portal. You can open it there.',
          actionLabel: 'Open UCAM',
          actionIcon: AppIcons.external,
          onAction: () => openUcam(context),
        ),
      ),
    );
  }
}

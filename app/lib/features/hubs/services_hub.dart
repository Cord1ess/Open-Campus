import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/coming_soon_page.dart';
import '../services/faculty_schedule_page.dart';
import '../services/gpa_calculator_page.dart';
import '../services/registration_closed_page.dart';
import '../services/tuition_tool_page.dart';
import 'hub_page.dart';

class ServicesHub extends StatelessWidget {
  const ServicesHub({super.key});

  @override
  Widget build(BuildContext context) {
    return HubPage(
      title: 'Services',
      header: _ServicesHeader(
        onGpa: (c) =>
            Navigator.of(c).push(sharedAxisRoute(const GpaCalculatorPage())),
        onTuition: (c) =>
            Navigator.of(c).push(sharedAxisRoute(const TuitionToolPage())),
      ),
      groups: [
        HubGroup('Tools', [
          HubFeature(
            icon: Icons.calculate_outlined,
            title: 'GPA Tool',
            subtitle: 'Auto from your data, or manual',
            status: FeatureStatus.live,
            onTap: (c) => Navigator.of(c)
                .push(sharedAxisRoute(const GpaCalculatorPage())),
          ),
          HubFeature(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Tuition Fee Tool',
            subtitle: 'Your real bill, or an estimate',
            status: FeatureStatus.live,
            onTap: (c) =>
                Navigator.of(c).push(sharedAxisRoute(const TuitionToolPage())),
          ),
          HubFeature(
            icon: Icons.people_outline,
            title: 'Faculty Schedules',
            subtitle: 'Class times, counselling & room',
            status: FeatureStatus.live,
            onTap: (c) => Navigator.of(c)
                .push(sharedAxisRoute(const FacultySchedulePage())),
          ),
        ]),
        HubGroup('Campus', [
          HubFeature(
            icon: Icons.directions_bus_outlined,
            title: 'Transport',
            subtitle: 'Bus service registration',
            status: FeatureStatus.live,
            onTap: (c) => Navigator.of(c).push(sharedAxisRoute(
              const RegistrationClosedPage(
                title: 'Transport',
                icon: Icons.directions_bus_outlined,
                description:
                    'Register for the university bus service during the '
                    'registration window.',
              ),
            )),
          ),
          HubFeature(
            icon: Icons.fitness_center_outlined,
            title: 'Gymnasium',
            subtitle: 'Gym enrollment',
            status: FeatureStatus.live,
            onTap: (c) => Navigator.of(c).push(sharedAxisRoute(
              const RegistrationClosedPage(
                title: 'Gymnasium',
                icon: Icons.fitness_center_outlined,
                description:
                    'Enroll in the university gymnasium during the '
                    'registration window.',
              ),
            )),
          ),
        ]),
        HubGroup('Academic', [
          // Course evaluation is important but UCAM currently keeps it OFF, so
          // we can't pull it yet — surfaced as coming-soon.
          const HubFeature(
            icon: Icons.rate_review_outlined,
            title: 'Course Evaluation',
            subtitle: 'Evaluate your courses',
          ),
        ]),
        HubGroup('Account', [
          HubFeature(
            icon: Icons.lock_reset_outlined,
            title: 'Change Password',
            subtitle: 'Opens UCAM',
            status: FeatureStatus.opensInUcam,
            onTap: (c) => openUcam(c),
          ),
        ]),
      ],
    );
  }
}

/// Two prominent quick-action tiles for the flagship tools.
class _ServicesHeader extends StatelessWidget {
  final void Function(BuildContext) onGpa;
  final void Function(BuildContext) onTuition;
  const _ServicesHeader({required this.onGpa, required this.onTuition});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.calculate_outlined,
              title: 'GPA Tool',
              subtitle: 'Plan & project',
              accent: context.scheme.primary,
              onTap: () => onGpa(context),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: _ActionTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Tuition',
              subtitle: 'Fees & installments',
              accent: context.scheme.secondary,
              onTap: () => onTuition(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onAccent(accent); // readable foreground on the filled accent
    return SpringTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: accent, // bold filled accent tile
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(height: Spacing.md),
            Text(title,
                style: context.text.titleMedium
                    ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
            Text(subtitle,
                style: context.text.labelMedium
                    ?.copyWith(color: fg.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }
}

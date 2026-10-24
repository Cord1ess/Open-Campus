import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../services/gpa_calculator_page.dart';
import '../services/registration_closed_page.dart';
import '../services/tuition_tool_page.dart';
import 'hub_page.dart';

class ServicesHub extends StatelessWidget {
  const ServicesHub({super.key});

  @override
  Widget build(BuildContext context) {
    void go(BuildContext c, Widget page) =>
        Navigator.of(c).push(appRoute(page));

    return HubPage(
      title: 'Services',
      groups: [
        HubGroup('Tools', [
          HubFeature(
            icon: AppIcons.gpaTool,
            title: 'GPA Tool',
            subtitle: 'Projection and target planner',
            onTap: (c) => go(c, const GpaCalculatorPage()),
          ),
          HubFeature(
            icon: AppIcons.tuitionTool,
            title: 'Tuition Fee Tool',
            subtitle: 'Your real bill, or an estimate',
            onTap: (c) => go(c, const TuitionToolPage()),
          ),
        ]),
        HubGroup('Campus', [
          HubFeature(
            icon: AppIcons.transport,
            title: 'Transport',
            subtitle: 'Bus service registration',
            onTap: (c) => go(
              c,
              const RegistrationClosedPage(
                title: 'Transport',
                icon: AppIcons.transport,
                description:
                    'Register for the university bus service during the '
                    'registration window.',
              ),
            ),
          ),
          HubFeature(
            icon: AppIcons.gym,
            title: 'Gymnasium',
            subtitle: 'Gym enrollment',
            onTap: (c) => go(
              c,
              const RegistrationClosedPage(
                title: 'Gymnasium',
                icon: AppIcons.gym,
                description:
                    'Enroll in the university gymnasium during the '
                    'registration window.',
              ),
            ),
          ),
        ]),
        const HubGroup('Account', [
          HubFeature(
            icon: AppIcons.password,
            title: 'Change Password',
            subtitle: 'Opens UCAM',
            status: FeatureStatus.opensInUcam,
          ),
        ]),
        const HubGroup('Academic', [
          // Faculty schedules have no backend source yet; listed so the intent
          // is visible, without shipping sample data.
          HubFeature(
            icon: AppIcons.faculty,
            title: 'Faculty Schedules',
            subtitle: 'Class times, counselling hours and rooms',
            status: FeatureStatus.comingSoon,
          ),
          // Course evaluation is currently switched off in UCAM.
          HubFeature(
            icon: AppIcons.evaluation,
            title: 'Course Evaluation',
            subtitle: 'Evaluate your courses',
            status: FeatureStatus.comingSoon,
          ),
        ]),
      ],
    );
  }
}

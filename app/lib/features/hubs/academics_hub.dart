import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/stat_tiles.dart';
import '../../shared/widgets.dart';
import '../academics/advising_page.dart';
import '../academics/calendar_page.dart';
import '../academics/class_routine_page.dart';
import '../academics/course_history_page.dart';
import '../academics/exam_routine_page.dart';
import '../academics/marks_page.dart';
import '../academics/uiu_notices_page.dart';
import '../dashboard/attendance_page.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/dashboard_widgets.dart';
import '../dashboard/home_model.dart';
import '../dashboard/models.dart';
import '../dashboard/results_page.dart';
import 'hub_page.dart';

class AcademicsHub extends ConsumerWidget {
  const AcademicsHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final attendance = ref.watch(attendanceProvider);
    final h = home is ResData<HomeSummary> ? home.loaded.data : null;
    final a = attendance is ResData<AttendanceData>
        ? attendance.loaded.data
        : null;
    final att = a != null ? overallAttendancePct(a) : null;
    final scheme = context.scheme;

    return HubPage(
      title: 'Academics',
      header: StatRow(tiles: [
        StatTile(
          icon: Icons.workspace_premium,
          label: 'CGPA',
          value: h?.cgpa?.toStringAsFixed(2) ?? '—',
          accent: scheme.primary,
          filled: true,
        ),
        StatTile(
          icon: Icons.event_available,
          label: 'Attendance',
          value: att != null ? '${att.toStringAsFixed(0)}%' : '—',
          accent: scheme.secondary,
        ),
        StatTile(
          icon: Icons.school_outlined,
          label: 'Credits',
          value: h?.completedCredits?.toStringAsFixed(0) ?? '—',
          accent: scheme.secondary,
        ),
      ]),
      groups: [
        HubGroup('Performance', [
          HubFeature(
            icon: Icons.school_outlined,
            title: 'Results',
            subtitle: 'Semester GPA & CGPA',
            status: FeatureStatus.live,
            onTap: (c) =>
                Navigator.of(c).push(sharedAxisRoute(const ResultsPage())),
          ),
          HubFeature(
            icon: Icons.event_available_outlined,
            title: 'Attendance',
            subtitle: 'Per-course attendance',
            status: FeatureStatus.live,
            onTap: (c) =>
                Navigator.of(c).push(sharedAxisRoute(const AttendancePage())),
          ),
          HubFeature(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Course Marks',
            subtitle: 'Item-wise marks per course',
            status: FeatureStatus.live,
            onTap: (c) =>
                Navigator.of(c).push(sharedAxisRoute(const MarksPage())),
          ),
          HubFeature(
            icon: Icons.grading_outlined,
            title: 'Course Grades',
            subtitle: 'Every course, grade & credit',
            status: FeatureStatus.live,
            onTap: (c) => Navigator.of(c)
                .push(sharedAxisRoute(const CourseHistoryPage())),
          ),
        ]),
        HubGroup('Records', [
          HubFeature(
            icon: Icons.campaign_outlined,
            title: 'Notices',
            subtitle: 'Latest UIU notices',
            status: FeatureStatus.live,
            onTap: (c) =>
                Navigator.of(c).push(sharedAxisRoute(const UiuNoticesPage())),
          ),
          HubFeature(
            icon: Icons.calendar_view_week_outlined,
            title: 'Class Routine',
            subtitle: 'Weekly timetable',
            status: FeatureStatus.live,
            onTap: (c) => Navigator.of(c)
                .push(sharedAxisRoute(const ClassRoutinePage())),
          ),
          HubFeature(
            icon: Icons.event_note_outlined,
            title: 'Exam Schedule',
            subtitle: 'Published exam routines',
            status: FeatureStatus.live,
            onTap: (c) =>
                Navigator.of(c).push(sharedAxisRoute(const ExamRoutinePage())),
          ),
          HubFeature(
            icon: Icons.calendar_month_outlined,
            title: 'Academic Calendar',
            subtitle: 'Term dates & reminders',
            status: FeatureStatus.live,
            onTap: (c) =>
                Navigator.of(c).push(sharedAxisRoute(const CalendarPage())),
          ),
        ]),
        HubGroup('Registration', [
          HubFeature(
            icon: Icons.assignment_outlined,
            title: 'Pre-Advising',
            subtitle: 'Plan next semester',
            status: FeatureStatus.live,
            onTap: (c) =>
                Navigator.of(c).push(sharedAxisRoute(const AdvisingPage())),
          ),
          const HubFeature(
            icon: Icons.app_registration_outlined,
            title: 'Self Registration',
            subtitle: 'Register for courses',
          ),
          const HubFeature(
            icon: Icons.swap_horiz_outlined,
            title: 'Course Requests',
            subtitle: 'Open · withdraw · credit limit',
          ),
          const HubFeature(
            icon: Icons.groups_outlined,
            title: 'FYP Group',
            subtitle: 'Final-year project group',
          ),
        ]),
        const HubGroup('Others', [
          HubFeature(
            icon: Icons.description_outlined,
            title: 'Transcript',
            subtitle: 'Full academic transcript',
          ),
          HubFeature(
            icon: Icons.military_tech_outlined,
            title: 'Degree Progress',
            subtitle: 'Credits done & remaining',
          ),
        ]),
      ],
    );
  }
}

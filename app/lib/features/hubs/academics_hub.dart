import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
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
import '../sections/your_sections_page.dart';
import 'hub_page.dart';

class AcademicsHub extends ConsumerWidget {
  const AcademicsHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final attendance = ref.watch(attendanceProvider);
    final h = home is ResData<HomeSummary> ? home.loaded.data : null;
    final a =
        attendance is ResData<AttendanceData> ? attendance.loaded.data : null;
    final att = a != null ? overallAttendancePct(a) : null;

    void go(BuildContext c, Widget page) =>
        Navigator.of(c).push(appRoute(page));

    return HubPage(
      title: 'Academics',
      header: StatStrip(items: [
        StatBlock(
          label: 'CGPA',
          value: h?.cgpa?.toStringAsFixed(2) ?? '—',
          secretId: h?.cgpa != null ? Secrets.cgpa : null,
        ),
        StatBlock(
          label: 'Attendance',
          value: att != null ? '${att.toStringAsFixed(0)}%' : '—',
          numeric: att,
          format: (v) => '${v.toStringAsFixed(0)}%',
          hue: att != null && att < 70 ? Hue.rose : null,
        ),
        StatBlock(
          label: 'Credits',
          value: h?.completedCredits?.toStringAsFixed(0) ?? '—',
          numeric: h?.completedCredits,
          format: (v) => v.toStringAsFixed(0),
        ),
      ]),
      groups: [
        HubGroup('Performance', [
          HubFeature(
            icon: AppIcons.results,
            title: 'Results',
            subtitle: 'Semester GPA and CGPA',
            onTap: (c) => go(c, const ResultsPage()),
          ),
          HubFeature(
            icon: AppIcons.attendance,
            title: 'Attendance',
            subtitle: 'Per-course attendance and marks lost',
            onTap: (c) => go(c, const AttendancePage()),
          ),
          HubFeature(
            icon: AppIcons.marks,
            title: 'Course Marks',
            subtitle: 'Item-wise marks per course',
            onTap: (c) => go(c, const MarksPage()),
          ),
          HubFeature(
            icon: AppIcons.grades,
            title: 'Course Grades',
            subtitle: 'Every course, grade and credit',
            onTap: (c) => go(c, const CourseHistoryPage()),
          ),
        ]),
        HubGroup('Schedule', [
          HubFeature(
            icon: AppIcons.routine,
            title: 'Class Routine',
            subtitle: 'Weekly timetable',
            onTap: (c) => go(c, const ClassRoutinePage()),
          ),
          HubFeature(
            icon: AppIcons.exams,
            title: 'Exam Schedule',
            subtitle: 'Published exam routines',
            onTap: (c) => go(c, const ExamRoutinePage()),
          ),
          HubFeature(
            icon: AppIcons.calendar,
            title: 'Academic Calendar',
            subtitle: 'Term dates and reminders',
            onTap: (c) => go(c, const CalendarPage()),
          ),
          HubFeature(
            icon: AppIcons.notices,
            title: 'Notices',
            subtitle: 'Latest UIU notices',
            onTap: (c) => go(c, const UiuNoticesPage()),
          ),
        ]),
        HubGroup('Registration', [
          HubFeature(
            icon: AppIcons.advising,
            title: 'Pre-Advising',
            subtitle: 'Courses offered next term',
            onTap: (c) => go(c, const AdvisingPage()),
          ),
          HubFeature(
            icon: AppIcons.sections,
            title: 'Section Selection',
            subtitle: 'Sections, faculty and schedule planner',
            onTap: (c) => go(c, const YourSectionsPage()),
          ),
          const HubFeature(
            icon: AppIcons.courseRequests,
            title: 'Course Requests',
            subtitle: 'Open, withdraw, credit limit',
            status: FeatureStatus.comingSoon,
          ),
          const HubFeature(
            icon: AppIcons.fyp,
            title: 'FYP Group',
            subtitle: 'Final-year project group',
            status: FeatureStatus.comingSoon,
          ),
          const HubFeature(
            icon: AppIcons.transcript,
            title: 'Transcript',
            subtitle: 'Full academic transcript',
            status: FeatureStatus.comingSoon,
          ),
          const HubFeature(
            icon: AppIcons.degree,
            title: 'Degree Progress',
            subtitle: 'Credits done and remaining',
            status: FeatureStatus.comingSoon,
          ),
        ]),
      ],
    );
  }
}

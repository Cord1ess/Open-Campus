import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/core/theme/app_theme.dart';
import 'package:open_campus/features/academics/calendar_model.dart';
import 'package:open_campus/features/academics/class_routine_page.dart';
import 'package:open_campus/features/academics/course_history_model.dart';
import 'package:open_campus/features/academics/course_history_page.dart';
import 'package:open_campus/features/auth/auth_controller.dart';
import 'package:open_campus/features/auth/login_screen.dart';
import 'package:open_campus/features/dashboard/attendance_page.dart';
import 'package:open_campus/features/dashboard/dashboard_controller.dart';
import 'package:open_campus/features/dashboard/home_model.dart';
import 'package:open_campus/features/dashboard/models.dart';
import 'package:open_campus/features/dashboard/notices_model.dart';
import 'package:open_campus/features/dashboard/results_page.dart';
import 'package:open_campus/features/finance/bill_model.dart';
import 'package:open_campus/features/finance/bill_page.dart';
import 'package:open_campus/features/finance/payment_history_page.dart';
import 'package:open_campus/features/profile/profile_page.dart';
import 'package:open_campus/features/shell/app_shell.dart';
import 'package:open_campus/shared/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout smoke tests: pump the real pages with fixture data (no network) at
/// phone, tablet and desktop sizes, in light and dark themes, and assert that
/// nothing overflows or throws. This is the automated stand-in for a visual
/// pass across screen sizes.

/// A resource controller pinned to fixed data; never touches the network.
class _Fixed<T> extends ResourceController<T> {
  _Fixed(super.ref, T data, {bool cached = false})
      : super(
            resource: 'fixture',
            path: '/fixture',
            parse: (_) => data,
            toJson: (_) => const {}) {
    state = ResData(Loaded(
        data, cached ? Freshness.cached : Freshness.live, DateTime.now()));
  }

  @override
  Future<void> load({bool force = false}) async {}
}

class _SignedIn extends AuthController {
  _SignedIn(super.ref) {
    state = const AuthSignedIn('011221234', fromLogin: false);
  }

  @override
  Future<void> restore() async {}
}

final _home = HomeSummary.fromJson({
  'name': 'Test Student With A Fairly Long Name',
  'roll': '011221234',
  'dob': '1 Jan 2003',
  'blood_group': 'O+',
  'phone': '01700000000',
  'father_name': 'Parent One',
  'mother_name': 'Parent Two',
  'current_term': {'code': '261', 'name': 'Spring 2026'},
  'next_terms': [
    {'code': '262', 'name': 'Summer 2026'}
  ],
  'cgpa': 3.67,
  'completed_credits': 96,
  'current_balance': 12500,
  'total_billed': 650000,
  'total_paid': 620000,
  'total_waived': 17500,
  'advisor': {
    'name': 'Dr. Advisor Name',
    'initial': 'ADN',
    'room': '0421',
    'email': 'advisor@example.edu',
    'phone': '01800000000',
  },
  'routine': [
    for (final day in [
      'Saturday',
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday'
    ]) ...[
      {
        'day': day,
        'course_code': 'CSE 4165 Web Programming Laboratory',
        'section': 'A',
        'start': '08:30 AM',
        'end': '09:50 AM',
      },
      {
        'day': day,
        'course_code': 'CSE 3521',
        'section': 'B',
        'start': '11:11 AM',
        'end': '12:30 PM',
      },
    ],
  ],
});

final _results = ResultsData.fromJson({
  'latest_cgpa': 3.67,
  'semesters': [
    {'year': 2026, 'semester': 'Spring', 'gpa': 3.80, 'cgpa': 3.67},
    {'year': 2025, 'semester': 'Fall', 'gpa': 3.40, 'cgpa': 3.62},
    {'year': 2025, 'semester': 'Summer', 'gpa': 3.90, 'cgpa': 3.70},
    {'year': 2025, 'semester': 'Spring', 'gpa': 3.55, 'cgpa': 3.60},
  ],
});

final _attendance = AttendanceData.fromJson({
  'courses': [
    {
      'course_code': 'CSE 4165',
      'title': 'Web Programming Laboratory with an unusually long title',
      'section': 'A',
      'absent': 2,
      'present': 10,
      'total_held': 12,
    },
    {
      'course_code': 'CSE 3521',
      'title': 'Database Management Systems',
      'section': 'B',
      'absent': 5,
      'present': 7,
      'total_held': 12,
    },
    {
      'course_code': 'EEE 2113',
      'title': 'Electrical Circuits',
      'section': 'C',
      'absent': 0,
      'present': 12,
      'total_held': 12,
    },
  ],
});

final _notices = NoticesData.fromJson({
  'notices': [
    {
      'notice_id': '1',
      'title': 'Registration for Summer 2026 opens next week for all programs',
      'posted_by': 'Registrar',
      'posted_date': '20 Oct 2026',
    },
    {
      'notice_id': '2',
      'title': 'Library closed on Friday',
      'posted_by': 'Library',
      'posted_date': '19 Oct 2026',
    },
  ],
});

final _bill = BillData.fromJson({
  'total_billed': 650000,
  'total_discount': 17500,
  'total_paid': 620000,
  'balance': 12500,
  'payment_methods': [
    {'code': 'bk', 'name': 'bKash'},
    {'code': 'vm', 'name': 'Visa / Master'},
  ],
  'items': [
    {
      'fee_type': 'Tuition Fee',
      'course_code': 'CSE 4165',
      'credit': 3,
      'amount': 19500,
      'trimester': '[261] Spring 2026',
      'date': '25-Feb-26',
    },
    {
      'fee_type': 'Trimester Fee',
      'amount': 6500,
      'trimester': '[261] Spring 2026',
      'date': '25-Feb-26',
    },
    {
      'fee_type': 'Payment',
      'payment': 10000,
      'date': '01-Mar-26',
      'remark': 'bKash',
    },
    {
      'fee_type': 'Waiver',
      'discount': 2500,
      'trimester': '[261] Spring 2026',
      'date': '26-Feb-26',
    },
    {
      'fee_type': 'Tuition Fee',
      'course_code': 'CSE 3521',
      'credit': 3,
      'amount': 19500,
      'trimester': '[253] Fall 2025',
      'date': '20-Oct-25',
    },
    {
      'fee_type': 'Payment',
      'payment': 26000,
      'date': '25-Oct-25',
    },
  ],
});

final _history = CourseHistoryData.fromJson({
  'program': 'B.Sc. in Computer Science & Engineering',
  'batch': '221',
  'cgpa': 3.67,
  'degree_requirement': 137,
  'completed_credits': 96,
  'attempted_credits': 99,
  'waived_credits': 0,
  'trimester_gpas': [
    {'trimester': '253', 'credit': 12, 'gpa': 3.40, 'cgpa': 3.62},
    {'trimester': '261', 'credit': 12, 'gpa': 3.80, 'cgpa': 3.67},
  ],
  'courses': [
    {
      'trimester': '261',
      'course_code': 'CSE 4165',
      'course_name': 'Web Programming Laboratory',
      'credit': 1,
      'grade': 'A',
      'point': 4.0,
    },
    {
      'trimester': '261',
      'course_code': 'CSE 3521',
      'course_name': 'Database Management Systems',
      'credit': 3,
      'is_running': true,
    },
    {
      'trimester': '253',
      'course_code': 'EEE 2113',
      'course_name': 'Electrical Circuits',
      'credit': 3,
      'grade': 'B+',
      'point': 3.33,
    },
    {
      'trimester': '253',
      'course_code': 'MATH 2205',
      'course_name': 'Probability and Statistics',
      'credit': 3,
      'grade': 'F',
      'point': 0,
    },
  ],
});

AcademicCalendarData _calendar() {
  final now = DateTime.now();
  String d(int days) {
    final t = now.add(Duration(days: days));
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
  return AcademicCalendarData.fromJson({
    'calendars': [
      {
        'title': 'Academic Calendar Spring 2026',
        'term': 'Spring 2026',
        'program': 'Undergraduate',
        'revised': false,
        'events': [
          {
            'event': 'Classes begin',
            'day': 'Sat',
            'start_date': d(-30),
            'date_text': 'Earlier',
          },
          {
            'event': '1st installment payment deadline',
            'day': 'Sun',
            'start_date': d(5),
            'date_text': 'In five days',
          },
          {
            'event': 'Mid-term examinations',
            'day': 'Sat-Thu',
            'start_date': d(12),
            'end_date': d(18),
            'date_text': 'Mid term week',
          },
          {
            'event': 'Eid Holiday',
            'day': 'Mon',
            'start_date': d(40),
            'date_text': 'Holiday',
          },
        ],
      },
    ],
  });
}

/// Fixture overrides (also used by the visual-capture harness).
List<Override> testOverrides() => [
      authControllerProvider.overrideWith((ref) => _SignedIn(ref)),
      homeProvider.overrideWith((ref) => _Fixed(ref, _home, cached: true)),
      resultsProvider.overrideWith((ref) => _Fixed(ref, _results)),
      attendanceProvider.overrideWith((ref) => _Fixed(ref, _attendance)),
      noticesProvider.overrideWith((ref) => _Fixed(ref, _notices)),
      billProvider.overrideWith((ref) => _Fixed(ref, _bill)),
      courseHistoryProvider.overrideWith((ref) => _Fixed(ref, _history)),
      academicCalendarProvider.overrideWith((ref) async => _calendar()),
      avatarProvider.overrideWith((ref) async => null),
    ];

const _sizes = <String, Size>{
  'small phone': Size(360, 740),
  'phone': Size(390, 844),
  'tablet': Size(800, 1100),
  'desktop': Size(1440, 900),
};

Future<void> _pump(WidgetTester tester, Widget page, Size size,
    {bool dark = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: testOverrides(),
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: page,
    ),
  ));
  // Let async providers (calendar) and post-frame callbacks settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull, reason: 'layout exception');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final pages = <String, Widget Function()>{
    'AppShell': () => const AppShell(),
    'ResultsPage': () => const ResultsPage(),
    'AttendancePage': () => const AttendancePage(),
    'BillPage': () => const BillPage(),
    'PaymentHistoryPage': () => const PaymentHistoryPage(),
    'CourseHistoryPage': () => const CourseHistoryPage(),
    'ClassRoutinePage': () => const ClassRoutinePage(),
    'ProfilePage': () => const ProfilePage(),
    'LoginScreen': () => const LoginScreen(),
  };

  for (final page in pages.entries) {
    for (final size in _sizes.entries) {
      testWidgets('${page.key} lays out at ${size.key} (light)',
          (tester) async {
        await _pump(tester, page.value(), size.value);
      });
    }
    testWidgets('${page.key} lays out at phone (dark)', (tester) async {
      await _pump(tester, page.value(), _sizes['phone']!, dark: true);
    });
  }

  testWidgets('AppShell switches tabs without layout errors on phone and desktop',
      (tester) async {
    for (final size in [_sizes['phone']!, _sizes['desktop']!]) {
      await _pump(tester, const AppShell(), size);
      for (final label in ['Academics', 'Finance', 'Services', 'Home']) {
        await tester.tap(find.text(label).first);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'tab $label');
      }
    }
  });

  testWidgets('Dashboard shows the time-sensitive sections and figures',
      (tester) async {
    await _pump(tester, const AppShell(), _sizes['phone']!);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('CGPA'), findsOneWidget);
    expect(find.text('3.67'), findsWidgets);
    // Cached home data surfaces the freshness line.
    expect(find.textContaining('Saved copy'), findsOneWidget);
  });

  testWidgets('Large text scale does not overflow the dashboard or hubs',
      (tester) async {
    tester.view.physicalSize = _sizes['small phone']!;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: testOverrides(),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const AppShell(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    for (final label in ['Academics', 'Finance', 'Services']) {
      await tester.tap(find.text(label).first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'tab $label at 1.3x');
    }
  });
}

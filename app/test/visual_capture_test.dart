// Visual-capture harness for manual review: renders the real pages with the
// fixture data from page_layout_smoke_test.dart and the bundled Inter font,
// then writes PNGs to the directory in OC_CAPTURE_DIR. Skipped (no-op) when
// the variable isn't set, so it never runs in CI:
//
//   OC_CAPTURE_DIR=C:\shots flutter test test/visual_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/core/theme/app_theme.dart';
import 'package:open_campus/features/academics/class_routine_page.dart';
import 'package:open_campus/features/academics/course_history_page.dart';
import 'package:open_campus/features/auth/login_screen.dart';
import 'package:open_campus/features/dashboard/attendance_page.dart';
import 'package:open_campus/features/dashboard/results_page.dart';
import 'package:open_campus/features/finance/bill_page.dart';
import 'package:open_campus/features/finance/payment_history_page.dart';
import 'package:open_campus/features/profile/profile_page.dart';
import 'package:open_campus/features/shell/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'page_layout_smoke_test.dart' as fx;

void main() {
  final dir = Platform.environment['OC_CAPTURE_DIR'];
  if (dir == null) return;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final loader = FontLoader('Inter');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
    }
    await loader.load();
  });

  Future<void> shot(WidgetTester tester, String name, Widget page, Size size,
      {bool dark = false, String? tab}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: fx.testOverrides(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: page,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
    if (tab != null) {
      await tester.tap(find.text(tab).first);
      await tester.pump(const Duration(milliseconds: 400));
    }
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final data = await tester
        .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  }

  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  testWidgets('capture', (tester) async {
    await shot(tester, 'home_phone', const AppShell(), phone);
    await shot(tester, 'home_phone_dark', const AppShell(), phone, dark: true);
    await shot(tester, 'home_desktop', const AppShell(), desktop);
    await shot(tester, 'academics_phone', const AppShell(), phone,
        tab: 'Academics');
    await shot(tester, 'academics_desktop', const AppShell(), desktop,
        tab: 'Academics');
    await shot(tester, 'finance_desktop', const AppShell(), desktop,
        tab: 'Finance');
    await shot(tester, 'services_phone', const AppShell(), phone,
        tab: 'Services');
    await shot(tester, 'results_phone', const ResultsPage(), phone);
    await shot(tester, 'results_desktop', const ResultsPage(), desktop);
    await shot(tester, 'attendance_phone', const AttendancePage(), phone);
    await shot(tester, 'bill_phone', const BillPage(), phone);
    await shot(tester, 'bill_desktop', const BillPage(), desktop);
    await shot(tester, 'history_phone', const PaymentHistoryPage(), phone);
    await shot(tester, 'grades_phone', const CourseHistoryPage(), phone);
    await shot(tester, 'routine_desktop', const ClassRoutinePage(), desktop);
    await shot(tester, 'profile_phone', const ProfilePage(), phone);
    await shot(tester, 'profile_desktop', const ProfilePage(), desktop);
    await shot(tester, 'login_desktop', const LoginScreen(), desktop);
    await shot(tester, 'login_phone', const LoginScreen(), phone);
  });
}

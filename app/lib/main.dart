import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/bootstrap/bootstrap_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/common/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/onboarding_state.dart';
import 'features/shell/app_shell.dart';

void main() {
  // Make any framework error paint on screen instead of leaving a white page.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        child: Container(
          color: const Color(0xFF0B0F17),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Text(
            'Startup error:\n\n${details.exceptionAsString()}',
            style: const TextStyle(color: Color(0xFFEF4D4D), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
  // Initialize on-device notifications (academic-calendar reminders). Safe to
  // await; it's a no-op on web.
  NotificationService.instance.init();
  runApp(const ProviderScope(child: OpenCampusApp()));
}

class OpenCampusApp extends ConsumerWidget {
  const OpenCampusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    return MaterialApp(
      title: 'Open Campus',
      debugShowCheckedModeBanner: false,
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: theme.materialMode,
      // Clamp system text scaling so very large accessibility font sizes don't
      // break tight layouts (nav bar, stat cards). Still allows modest scaling.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.15);
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: child!,
        );
      },
      home: const _Root(),
    );
  }
}

/// Orchestrates the launch flow:
///   splash (while state loads) → onboarding (first run) → login → bootstrap → app.
class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  // True once the post-login bootstrap (data load) has finished for this session.
  bool _booted = false;
  // True once we've shown the login screen at least once. After that, an
  // AuthLoading (a login attempt in flight) keeps showing the login screen
  // (button reads "Signing in…") instead of flashing the splash spinner — the
  // ONLY post-login loader the user should see is the bootstrap progress bar.
  bool _sawLogin = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final onboardingSeen = ref.watch(onboardingProvider);

    // Reset bootstrap on logout so the next login shows the loader again.
    if (auth is! AuthSignedIn && _booted) {
      _booted = false;
    }

    final Widget child;
    String key;

    // A login attempt after we've shown the login screen: stay on login (no
    // splash flash). The login button itself shows the "Signing in…" state.
    if (auth is AuthLoading && _sawLogin && onboardingSeen != null) {
      child = const LoginScreen();
      key = 'login';
    } else if (auth is AuthLoading || onboardingSeen == null) {
      child = const SplashScreen();
      key = 'splash';
    } else if (onboardingSeen == false && auth is! AuthSignedIn) {
      child = OnboardingScreen(
        onDone: () => ref.read(onboardingProvider.notifier).complete(),
      );
      key = 'onboarding';
    } else if (auth is AuthSignedIn && !_booted) {
      // Signed in but data not loaded yet → show the bootstrap progress screen.
      child = BootstrapScreen(
        key: ValueKey('bootstrap-${auth.roll}'),
        onReady: () => setState(() => _booted = true),
      );
      key = 'bootstrap';
    } else if (auth is AuthSignedIn) {
      child = const AppShell();
      key = 'app';
    } else {
      final message = auth is AuthSignedOut ? auth.message : null;
      child = LoginScreen(message: message);
      key = 'login';
      _sawLogin = true;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: const Cubic(0.05, 0.7, 0.1, 1.0),
      switchOutCurve: Curves.easeOut,
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }
}

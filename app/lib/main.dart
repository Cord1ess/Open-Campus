import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/debug/fps_overlay.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/bootstrap/bootstrap_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/common/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/onboarding_state.dart';
import 'features/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge: let the app content draw BEHIND the status and navigation bars
  // so the whole screen is one continuous surface (the modern Android look),
  // instead of the OS drawing separate bar strips above/below the app (the older
  // 2018-era look). Combined with the transparent overlay in build(), the bars
  // become fully see-through. No-op on web/desktop.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
    final isDark = theme.materialMode == ThemeMode.dark;
    // Transparent system bars whose icons match the theme, so the Android
    // status & navigation bars blend into the app background as one continuous
    // surface (no separate brand-colored bar).
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      // Kill the translucent scrim Android otherwise paints behind the nav bar
      // (that grey/black wash is what makes the bar look like a separate strip).
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );
    return MaterialApp(
      title: 'Open Campus',
      debugShowCheckedModeBanner: false,
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: theme.materialMode,
      // Smoothly cross-animate colors on theme/accent change (instead of a hard
      // snap). Cheap now that the ThemeData itself is memoized.
      themeAnimationDuration: Motion.fast,
      themeAnimationCurve: Motion.emphasized,
      // Clamp system text scaling so very large accessibility font sizes don't
      // break tight layouts (nav bar, stat cards). Still allows modest scaling.
      // Perf: MediaQuery.withClampedTextScaling subscribes to the text-scale
      // factor ONLY — the old MediaQuery.of(context) here subscribed to every MQ
      // property, so any size/inset/scrollbar change rebuilt the whole app
      // subtree. AnnotatedRegion is a no-op on web, kept for mobile.
      builder: (context, child) {
        Widget app = MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.15,
          child: child!,
        );
        // Diagnostic FPS readout — only present with --dart-define=OC_FPS=true.
        if (FpsOverlay.enabled) app = FpsOverlay(child: app);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: app,
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
  // True if the device already has cached data from a previous session. When so,
  // we SKIP the blocking bootstrap screen entirely and render the shell instantly
  // — every card shows its cached copy immediately and hydrates live behind it.
  // The blocking bootstrap is then reserved for a true first-ever login (no cache
  // to show), where a brief progress screen beats a wall of empty skeletons.
  bool _hasCache = false;

  @override
  void initState() {
    super.initState();
    // Resolve cache presence once, up front, so the launch flow can decide
    // between "instant shell" (warm) and "bootstrap" (cold) without flicker.
    ref.read(localCacheProvider).hasAny().then((has) {
      if (mounted && has) setState(() => _hasCache = true);
    });
  }
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
    } else if (auth is AuthSignedIn &&
        !_booted &&
        (auth.fromLogin || !_hasCache)) {
      // Show the blocking bootstrap (waits for ALL data) when:
      //   • the user just logged in interactively (auth.fromLogin) — so the
      //     dashboard never appears empty and pop-fills card-by-card; or
      //   • there's no cache to show yet (true first run).
      // Only a SILENTLY RESTORED session WITH cache skips this and uses the
      // instant-shell path (cached data shown immediately, refreshed behind it).
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

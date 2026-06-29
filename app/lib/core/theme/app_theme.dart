import 'package:flutter/material.dart';

/// Open Campus — Material 3 design system.
///
/// We let Material 3 do the heavy lifting: a single seed color generates the full
/// tonal palette (primary / secondary / tertiary + their containers, plus the
/// surface tones used for elevation). We theme components with M3 roles rather
/// than hard-coded colors, so light/dark and contrast come for free.
class AppColors {
  /// The brand seed — UIU orange. The whole scheme is derived from this.
  static const seed = Color(0xFFF08700);
}

/// Semantic status colors (M3 has no built-in success/warning, so we define a
/// harmonized set). Reach them via context.status.
class StatusColors {
  final Color good, goodContainer, warn, warnContainer, bad, badContainer;
  const StatusColors({
    required this.good,
    required this.goodContainer,
    required this.warn,
    required this.warnContainer,
    required this.bad,
    required this.badContainer,
  });

  static StatusColors of(Brightness b) => b == Brightness.dark
      ? const StatusColors(
          good: Color(0xFF7BD88F),
          goodContainer: Color(0xFF1E3A28),
          warn: Color(0xFFF5C26B),
          warnContainer: Color(0xFF3D2F12),
          bad: Color(0xFFF2998E),
          badContainer: Color(0xFF44211D),
        )
      : const StatusColors(
          good: Color(0xFF1B873F),
          goodContainer: Color(0xFFD7F2DD),
          warn: Color(0xFFB26A00),
          warnContainer: Color(0xFFFFE9C7),
          bad: Color(0xFFC5362C),
          badContainer: Color(0xFFFCE0DC),
        );
}

extension StatusX on BuildContext {
  StatusColors get status =>
      StatusColors.of(Theme.of(this).brightness);
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// 4-pt spacing scale.
class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// M3 Expressive shape tokens — rounder than baseline M3. Expressive favors
/// large, full corners for a softer, friendlier feel.
class Radii {
  static const sm = 14.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 36.0;
  static const full = 999.0;
}

/// Easing fallbacks (spring physics live in motion.dart; these are for the few
/// places that still want curve-based timing, e.g. AnimatedSwitcher).
class Motion {
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 400);
  static const slow = Duration(milliseconds: 600);
}

class AppTheme {
  static ThemeData light({Color seed = AppColors.seed}) =>
      _build(Brightness.light, seed: seed);
  static ThemeData dark({Color seed = AppColors.seed, bool black = false}) =>
      _build(Brightness.dark, seed: seed, black: black);

  /// [black] = AMOLED/pitch-black: pure #000 surfaces over the dark scheme.
  static ThemeData _build(Brightness brightness,
      {Color seed = AppColors.seed, bool black = false}) {
    // `vibrant` keeps the seed saturated (the default algorithm desaturates a
    // vivid orange into a muddy brown). Material 3 derives a harmonized
    // secondary/tertiary/surface set around whichever source color is chosen.
    var scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );

    // Pitch-black: collapse the dark scheme's grey surfaces to true black,
    // keeping just enough separation for cards to read on OLED.
    if (black && brightness == Brightness.dark) {
      scheme = scheme.copyWith(
        surface: const Color(0xFF000000),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFF222222),
      );
    }

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: _typography(base.textTheme, scheme),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        elevation: 3,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm)),
      ),
    );
  }

  static TextTheme _typography(TextTheme base, ColorScheme scheme) {
    // Expressive type: bolder weights, tighter display tracking, bigger emphasis.
    return base.copyWith(
      displayLarge: base.displayLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.5),
      displayMedium: base.displayMedium
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
      displaySmall: base.displaySmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
      headlineLarge: base.headlineLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: base.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: base.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

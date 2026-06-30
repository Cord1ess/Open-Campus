import 'package:flutter/material.dart';

/// Open Campus — Material 3 design system.
///
/// The look is a clean, restrained one: pure white / neutral-dark surfaces with
/// color used only as deliberate accents. Surfaces are ALWAYS neutral (never
/// tinted by the seed); the picked color only drives the two accent shades.
///   - Custom (default): orange + blue dual accents (the brand look).
///   - Any other swatch: two shades (light + dark) of that one hue.
class AppColors {
  /// Brand orange — primary accent of the Custom theme.
  static const orange = Color(0xFFFF8007);

  /// Brand blue — secondary accent of the Custom theme.
  static const blue = Color(0xFF05BADD);

  /// Sentinel seed meaning "the Custom orange+blue brand scheme". Picked colors
  /// equal to this trigger the dual orange/blue accents instead of one hue.
  static const customSeed = Color(0xFFFF8007);

  /// Default seed.
  static const seed = customSeed;
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

/// Readable foreground (white or near-black) for text/icons drawn ON TOP of an
/// arbitrary accent fill. Used by filled accent tiles so they stay legible no
/// matter which seed/accent is active (a light accent gets dark text).
Color onAccent(Color accent) =>
    accent.computeLuminance() > 0.55 ? const Color(0xFF14181F) : Colors.white;

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
    // Resolve the two accents:
    //   Custom  → orange + blue (the brand dual-accent look).
    //   else    → two shades (a brighter + a deeper) of the picked hue.
    final (accentA, accentB) = seed == AppColors.customSeed
        ? (AppColors.orange, AppColors.blue)
        : _shadesOf(seed);

    // Start from a CONSTANT base scheme (ColorScheme.light/dark are cheap const
    // factories) instead of ColorScheme.fromSeed — fromSeed runs the expensive
    // HCT tonal-palette computation on every call, and we override almost the
    // whole scheme in _cleanScheme anyway, so its output was mostly discarded.
    // That computation was the main cause of theme/accent-switch lag.
    var scheme = brightness == Brightness.light
        ? const ColorScheme.light()
        : const ColorScheme.dark();
    scheme = _cleanScheme(scheme, brightness, accentA, accentB);

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
        outline: const Color(0xFF2A2A2A),
        outlineVariant: const Color(0xFF1C1C1C),
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
        // Predictive back (Android 14+): dragging back peeks/animates the
        // outgoing page. Falls back to a normal forward transition elsewhere.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface, fontWeight: FontWeight.w600),
      ),
      // White cards with a hairline border (clean, reference-style) — matches
      // SectionCard / the dashboard cards so every surface reads identically.
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        // Circular selection indicator (not the default wide pill) with the
        // accent tint, so the selected icon sits in a clean circle.
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: const CircleBorder(),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
            color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(
            color: scheme.onSurfaceVariant, fontSize: 12),
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

  /// Two harmonized accent shades from a single picked hue: a brighter "A"
  /// (used like the orange/primary slot) and a deeper, slightly hue-shifted "B"
  /// (used like the blue/secondary slot). Keeps a two-tone feel from one color.
  static (Color, Color) _shadesOf(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    final a = hsl
        .withSaturation((hsl.saturation * 1.05).clamp(0.0, 1.0))
        .withLightness(0.52)
        .toColor();
    // B leans a touch toward the next hue and goes deeper, so the two accents
    // read as related but distinct (not just light/dark of the exact same swatch).
    final b = hsl
        .withHue((hsl.hue + 18) % 360)
        .withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0))
        .withLightness(0.40)
        .toColor();
    return (a, b);
  }

  /// Applies the clean Open Campus scheme: NEUTRAL white/dark surfaces (no seed
  /// tint anywhere) with [accentA] (primary) and [accentB] (secondary/tertiary)
  /// as the only colors. Surfaces are identical across every theme — only the
  /// accents change — so the look stays consistent whatever color is picked.
  static ColorScheme _cleanScheme(ColorScheme scheme, Brightness brightness,
      Color accentA, Color accentB) {
    if (brightness == Brightness.light) {
      return scheme.copyWith(
        primary: accentA,
        onPrimary: Colors.white,
        primaryContainer: accentA,
        onPrimaryContainer: Colors.white,
        secondary: accentB,
        onSecondary: Colors.white,
        secondaryContainer: accentB,
        onSecondaryContainer: Colors.white,
        tertiary: accentB,
        onTertiary: Colors.white,
        tertiaryContainer: accentB,
        onTertiaryContainer: Colors.white,
        // Pure neutral surfaces — white background, white cards, soft grey tints.
        surface: Colors.white,
        onSurface: const Color(0xFF14181F),
        onSurfaceVariant: const Color(0xFF5B6470),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Colors.white,
        surfaceContainer: const Color(0xFFF4F6F8),
        surfaceContainerHigh: const Color(0xFFEEF1F4),
        surfaceContainerHighest: const Color(0xFFE9EDF1),
        outline: const Color(0xFFD3D9DF),
        outlineVariant: const Color(0xFFE7EBEF),
        surfaceTint: Colors.transparent,
      );
    }
    return scheme.copyWith(
      primary: accentA,
      onPrimary: Colors.white,
      primaryContainer: accentA,
      onPrimaryContainer: Colors.white,
      secondary: accentB,
      onSecondary: Colors.white,
      secondaryContainer: accentB,
      onSecondaryContainer: Colors.white,
      tertiary: accentB,
      onTertiary: Colors.white,
      tertiaryContainer: accentB,
      onTertiaryContainer: Colors.white,
      surface: const Color(0xFF0E1116),
      onSurface: const Color(0xFFE9EDF1),
      onSurfaceVariant: const Color(0xFF9AA4B0),
      surfaceContainerLowest: const Color(0xFF0B0E12),
      surfaceContainerLow: const Color(0xFF14181E),
      surfaceContainer: const Color(0xFF181D24),
      surfaceContainerHigh: const Color(0xFF1F252D),
      surfaceContainerHighest: const Color(0xFF272E37),
      outline: const Color(0xFF39414B),
      outlineVariant: const Color(0xFF252B33),
      surfaceTint: Colors.transparent,
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

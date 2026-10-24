import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A transparent system-bar overlay whose icon brightness follows the APP theme
/// ([isDark]) — not the OS dark-mode setting — so the status/navigation bars
/// show the app's own surface behind them.
SystemUiOverlayStyle appBarOverlayStyle(bool isDark) => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

/// Open Campus design tokens.
///
/// The system is deliberately quiet: neutral surfaces, hairline dividers, one
/// interactive accent, and semantic colour only where it carries meaning. Every
/// colour used for TEXT or ICONS is contrast-checked against the surface it sits
/// on (see [readableInk]), so the brand orange/blue — which are too light to read
/// on white — get a darker "ink" shade for text while keeping the original hue
/// for fills.
class AppColors {
  /// Brand orange (from the logo). The default accent fill.
  static const orange = Color(0xFFFF8007);

  /// Brand blue (from the logo). The default informational colour.
  static const blue = Color(0xFF05BADD);

  /// Sentinel seed meaning "the brand orange + blue scheme".
  static const customSeed = Color(0xFFFF8007);

  /// Default seed.
  static const seed = customSeed;
}

/// 4-pt spacing scale.
class Spacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Shape tokens. Controls and chips use [sm]; panels and cards use [md];
/// sheets and dialogs use [lg]. [full] is reserved for avatars and true chips.
class Radii {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const full = 999.0;
}

/// Motion: short, functional durations only (expand/collapse, selection moves,
/// theme cross-fade). No decorative entrance animation.
class Motion {
  static const emphasized = Curves.easeOutCubic;
  static const emphasizedDecelerate = Curves.easeOutCubic;
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

/// Semantic tone of a badge / note / status line.
enum StatusTone { neutral, accent, info, success, warning, danger }

/// The app's semantic palette, exposed as a theme extension so every colour
/// with MEANING comes from one place. Fills are the saturated brand colours;
/// inks are contrast-safe for text on the current surface; tints are soft
/// opaque backgrounds for badges and notes.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color accent, onAccent, accentInk, accentTint;
  final Color info, onInfo, infoInk, infoTint;
  final Color success, successInk, successTint;
  final Color warning, warningInk, warningTint;
  final Color danger, dangerInk, dangerTint;

  /// Distinguishable, theme-coherent colours for multi-series charts and the
  /// weekly schedule grid (one colour per course). Text drawn on them should use
  /// [onAccent]-style selection via [onColor].
  final List<Color> series;

  const AppPalette({
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.accentTint,
    required this.info,
    required this.onInfo,
    required this.infoInk,
    required this.infoTint,
    required this.success,
    required this.successInk,
    required this.successTint,
    required this.warning,
    required this.warningInk,
    required this.warningTint,
    required this.danger,
    required this.dangerInk,
    required this.dangerTint,
    required this.series,
  });

  /// Readable text/icon colour for a [tone] on the page surface.
  Color inkFor(StatusTone tone, ColorScheme scheme) => switch (tone) {
        StatusTone.neutral => scheme.onSurfaceVariant,
        StatusTone.accent => accentInk,
        StatusTone.info => infoInk,
        StatusTone.success => successInk,
        StatusTone.warning => warningInk,
        StatusTone.danger => dangerInk,
      };

  /// Soft background for a [tone] (badges, notes).
  Color tintFor(StatusTone tone, ColorScheme scheme) => switch (tone) {
        StatusTone.neutral => scheme.surfaceContainerHigh,
        StatusTone.accent => accentTint,
        StatusTone.info => infoTint,
        StatusTone.success => successTint,
        StatusTone.warning => warningTint,
        StatusTone.danger => dangerTint,
      };

  /// Solid fill for a [tone] (progress bars, dots).
  Color fillFor(StatusTone tone, ColorScheme scheme) => switch (tone) {
        StatusTone.neutral => scheme.onSurfaceVariant,
        StatusTone.accent => accentInk,
        StatusTone.info => infoInk,
        StatusTone.success => successInk,
        StatusTone.warning => warningInk,
        StatusTone.danger => dangerInk,
      };

  @override
  AppPalette copyWith({List<Color>? series}) => AppPalette(
        accent: accent,
        onAccent: onAccent,
        accentInk: accentInk,
        accentTint: accentTint,
        info: info,
        onInfo: onInfo,
        infoInk: infoInk,
        infoTint: infoTint,
        success: success,
        successInk: successInk,
        successTint: successTint,
        warning: warning,
        warningInk: warningInk,
        warningTint: warningTint,
        danger: danger,
        dangerInk: dangerInk,
        dangerTint: dangerTint,
        series: series ?? this.series,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentInk: l(accentInk, other.accentInk),
      accentTint: l(accentTint, other.accentTint),
      info: l(info, other.info),
      onInfo: l(onInfo, other.onInfo),
      infoInk: l(infoInk, other.infoInk),
      infoTint: l(infoTint, other.infoTint),
      success: l(success, other.success),
      successInk: l(successInk, other.successInk),
      successTint: l(successTint, other.successTint),
      warning: l(warning, other.warning),
      warningInk: l(warningInk, other.warningInk),
      warningTint: l(warningTint, other.warningTint),
      danger: l(danger, other.danger),
      dangerInk: l(dangerInk, other.dangerInk),
      dangerTint: l(dangerTint, other.dangerTint),
      series: [
        for (var i = 0; i < math.min(series.length, other.series.length); i++)
          l(series[i], other.series[i]),
      ],
    );
  }
}

/// Compatibility view over [AppPalette] for the older `context.status` call
/// sites (good / warn / bad + containers).
class StatusColors {
  final Color good, goodContainer, warn, warnContainer, bad, badContainer;
  final Color info, infoContainer;
  const StatusColors({
    required this.good,
    required this.goodContainer,
    required this.warn,
    required this.warnContainer,
    required this.bad,
    required this.badContainer,
    required this.info,
    required this.infoContainer,
  });

  factory StatusColors.fromPalette(AppPalette p) => StatusColors(
        good: p.successInk,
        goodContainer: p.successTint,
        warn: p.warningInk,
        warnContainer: p.warningTint,
        bad: p.dangerInk,
        badContainer: p.dangerTint,
        info: p.infoInk,
        infoContainer: p.infoTint,
      );
}

extension StatusX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  StatusColors get status => StatusColors.fromPalette(palette);
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// WCAG contrast ratio between two colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Near-black or white — whichever reads better on [fill]. Used for text drawn
/// ON a solid accent (buttons, selected segments, calendar blocks).
Color onColor(Color fill) {
  const dark = Color(0xFF16191E);
  return contrastRatio(dark, fill) >= contrastRatio(Colors.white, fill)
      ? dark
      : Colors.white;
}

/// Backwards-compatible name for [onColor].
Color onAccent(Color accent) => onColor(accent);

/// Darken (on light surfaces) or lighten (on dark surfaces) [base] until it
/// reaches at least [min] contrast against [surface]. Hue and saturation are
/// kept, so the result still reads as "the brand orange", just legible.
Color readableInk(Color base, Color surface, {double min = 4.5}) {
  if (contrastRatio(base, surface) >= min) return base;
  final hsl = HSLColor.fromColor(base);
  final darken = surface.computeLuminance() > 0.5;
  var l = hsl.lightness;
  var c = base;
  for (var i = 0; i < 60 && contrastRatio(c, surface) < min; i++) {
    l = (darken ? l - 0.0125 : l + 0.0125).clamp(0.0, 1.0);
    c = hsl.withLightness(l).toColor();
  }
  return c;
}

/// An opaque soft tint of [base] over [surface] (for badges and notes).
Color tintOf(Color base, Color surface, {double alpha = 0.12}) =>
    Color.alphaBlend(base.withValues(alpha: alpha), surface);

class AppTheme {
  /// The one typeface used everywhere (Inter, bundled static weights).
  static const fontFamily = 'Inter';

  static ThemeData light({Color seed = AppColors.seed}) =>
      _build(Brightness.light, seed: seed);
  static ThemeData dark({Color seed = AppColors.seed, bool black = false}) =>
      _build(Brightness.dark, seed: seed, black: black);

  // ---- Neutral surfaces -----------------------------------------------------

  static const _lightSurface = Colors.white;
  static const _darkSurface = Color(0xFF0E1116);

  static ColorScheme _neutralScheme(Brightness b, {bool black = false}) {
    if (b == Brightness.light) {
      return const ColorScheme.light().copyWith(
        surface: _lightSurface,
        onSurface: const Color(0xFF16191E),
        onSurfaceVariant: const Color(0xFF5C6470),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF7F8FA),
        surfaceContainer: const Color(0xFFF2F4F6),
        surfaceContainerHigh: const Color(0xFFECEFF2),
        surfaceContainerHighest: const Color(0xFFE5E9ED),
        outline: const Color(0xFFC9CFD6),
        outlineVariant: const Color(0xFFE3E7EB),
        inverseSurface: const Color(0xFF2A2F36),
        onInverseSurface: const Color(0xFFF2F4F6),
        surfaceTint: Colors.transparent,
        scrim: Colors.black,
      );
    }
    var s = const ColorScheme.dark().copyWith(
      surface: _darkSurface,
      onSurface: const Color(0xFFE9EDF1),
      onSurfaceVariant: const Color(0xFF9AA4B0),
      surfaceContainerLowest: const Color(0xFF0B0E12),
      surfaceContainerLow: const Color(0xFF14181E),
      surfaceContainer: const Color(0xFF181D24),
      surfaceContainerHigh: const Color(0xFF1F252D),
      surfaceContainerHighest: const Color(0xFF272E37),
      outline: const Color(0xFF39414B),
      outlineVariant: const Color(0xFF252B33),
      inverseSurface: const Color(0xFFE9EDF1),
      onInverseSurface: const Color(0xFF16191E),
      surfaceTint: Colors.transparent,
      scrim: Colors.black,
    );
    if (black) {
      s = s.copyWith(
        surface: const Color(0xFF000000),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF111111),
        surfaceContainerHigh: const Color(0xFF191919),
        surfaceContainerHighest: const Color(0xFF222222),
        outline: const Color(0xFF2E2E2E),
        outlineVariant: const Color(0xFF1E1E1E),
      );
    }
    return s;
  }

  // ---- Accent resolution ----------------------------------------------------

  /// Two accents from one seed. The brand seed yields orange + blue; any other
  /// seed yields the seed itself plus a deeper, slightly hue-shifted companion.
  static (Color, Color) _accentsFor(Color seed) {
    if (seed.toARGB32() == AppColors.customSeed.toARGB32()) {
      return (AppColors.orange, AppColors.blue);
    }
    final hsl = HSLColor.fromColor(seed);
    final a = hsl.withLightness(hsl.lightness.clamp(0.42, 0.58)).toColor();
    final b = hsl
        .withHue((hsl.hue + 24) % 360)
        .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
        .withLightness(0.40)
        .toColor();
    return (a, b);
  }

  static AppPalette _palette(Brightness b, ColorScheme scheme, Color seed) {
    final (accent, info) = _accentsFor(seed);
    final surface = scheme.surface;
    final dark = b == Brightness.dark;
    final tintAlpha = dark ? 0.20 : 0.12;

    final accentInk = readableInk(accent, surface);
    final infoInk = readableInk(info, surface);

    final success = dark ? const Color(0xFF5FCB8A) : const Color(0xFF1E7F3F);
    final warning = dark ? const Color(0xFFF0B860) : const Color(0xFF9A5B00);
    final danger = dark ? const Color(0xFFF19A90) : const Color(0xFFC0392B);

    final series = dark
        ? <Color>[
            accentInk,
            infoInk,
            const Color(0xFF7FA8F5),
            const Color(0xFF5FCB8A),
            const Color(0xFFB394F0),
            const Color(0xFFF08BB5),
            const Color(0xFF4FD1BF),
            const Color(0xFF9CA3AF),
          ]
        : <Color>[
            accentInk,
            infoInk,
            const Color(0xFF2F6FDE),
            const Color(0xFF1F8A4C),
            const Color(0xFF7C4DBF),
            const Color(0xFFB23A6B),
            const Color(0xFF0F8C7E),
            const Color(0xFF6B7280),
          ];

    return AppPalette(
      accent: accent,
      onAccent: onColor(accent),
      accentInk: accentInk,
      accentTint: tintOf(accent, surface, alpha: tintAlpha),
      info: info,
      onInfo: onColor(info),
      infoInk: infoInk,
      infoTint: tintOf(info, surface, alpha: tintAlpha),
      success: success,
      successInk: readableInk(success, surface),
      successTint: tintOf(success, surface, alpha: tintAlpha),
      warning: warning,
      warningInk: readableInk(warning, surface),
      warningTint: tintOf(warning, surface, alpha: tintAlpha + 0.04),
      danger: danger,
      dangerInk: readableInk(danger, surface),
      dangerTint: tintOf(danger, surface, alpha: tintAlpha),
      series: series,
    );
  }

  // ---- Build ----------------------------------------------------------------

  static ThemeData _build(Brightness brightness,
      {Color seed = AppColors.seed, bool black = false}) {
    var scheme = _neutralScheme(brightness, black: black);
    final p = _palette(brightness, scheme, seed);

    scheme = scheme.copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accentTint,
      onPrimaryContainer: p.accentInk,
      secondary: p.info,
      onSecondary: p.onInfo,
      secondaryContainer: p.infoTint,
      onSecondaryContainer: p.infoInk,
      tertiary: p.info,
      onTertiary: p.onInfo,
      tertiaryContainer: p.infoTint,
      onTertiaryContainer: p.infoInk,
      error: p.dangerInk,
      onError: onColor(p.dangerInk),
      errorContainer: p.dangerTint,
      onErrorContainer: p.dangerInk,
      inversePrimary: p.accentTint,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: fontFamily,
      extensions: [p],
    );
    final text = _typography(base.textTheme, scheme);

    final controlShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const controlSize = Size(64, 44);
    final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant, thickness: 1, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        titleSpacing: Spacing.lg,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accentTint,
        indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg)),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? p.accentInk
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            text.labelMedium!.copyWith(
              color: states.contains(WidgetState.selected)
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: p.accentTint,
        indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg)),
        selectedIconTheme: IconThemeData(color: p.accentInk, size: 22),
        unselectedIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        selectedLabelTextStyle: text.labelMedium!
            .copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle:
            text.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
        useIndicator: true,
        minWidth: 80,
        minExtendedWidth: 220,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: controlShape,
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: controlShape,
          foregroundColor: p.accentInk,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: scheme.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 1,
        focusElevation: 1,
        hoverElevation: 2,
        highlightElevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg)),
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: 14),
        border: inputBorder(scheme.outline),
        enabledBorder: inputBorder(scheme.outline),
        disabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(p.accentInk, 1.5),
        errorBorder: inputBorder(p.dangerInk),
        focusedErrorBorder: inputBorder(p.dangerInk, 1.5),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle:
            text.labelMedium?.copyWith(color: p.accentInk),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: text.bodySmall?.copyWith(color: p.dangerInk),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(color: scheme.outlineVariant),
          )),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: p.accentTint,
        disabledColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm)),
        labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: p.accentInk),
        checkmarkColor: p.accentInk,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: true,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        minVerticalPadding: 10,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle:
            text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle:
            text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.onAccent : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? p.accent
                : scheme.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.accent : scheme.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.accentInk : Colors.transparent),
        checkColor: WidgetStatePropertyAll(onColor(p.accentInk)),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accentInk,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: p.accentInk,
        overlayColor: p.accentInk.withValues(alpha: 0.12),
        valueIndicatorColor: scheme.inverseSurface,
        valueIndicatorTextStyle:
            text.labelMedium?.copyWith(color: scheme.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accentInk,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.onInverseSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm)),
        insetPadding: const EdgeInsets.all(Spacing.lg),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: text.titleMedium?.copyWith(color: scheme.onSurface),
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        textStyle: text.labelMedium?.copyWith(color: scheme.onInverseSurface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: text.bodyMedium,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        tilePadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      ),
    );
  }

  /// Inter type scale. Weights are capped at 600; 700 is reserved for a single
  /// key figure per screen. Letter-spacing is neutral throughout.
  static TextTheme _typography(TextTheme base, ColorScheme scheme) {
    TextStyle s(double size, FontWeight w, double height,
            {Color? color}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: 0,
          color: color ?? scheme.onSurface,
        );
    return TextTheme(
      displayLarge: s(44, FontWeight.w600, 1.1),
      displayMedium: s(36, FontWeight.w600, 1.1),
      displaySmall: s(30, FontWeight.w600, 1.15),
      headlineLarge: s(28, FontWeight.w600, 1.2),
      headlineMedium: s(24, FontWeight.w600, 1.2),
      headlineSmall: s(22, FontWeight.w600, 1.25),
      titleLarge: s(20, FontWeight.w600, 1.3),
      titleMedium: s(16, FontWeight.w600, 1.35),
      titleSmall: s(14, FontWeight.w600, 1.35),
      bodyLarge: s(16, FontWeight.w400, 1.45),
      bodyMedium: s(14, FontWeight.w400, 1.45),
      bodySmall: s(12, FontWeight.w400, 1.4, color: scheme.onSurfaceVariant),
      labelLarge: s(14, FontWeight.w500, 1.3),
      labelMedium: s(12, FontWeight.w500, 1.3),
      labelSmall: s(11, FontWeight.w500, 1.3),
    );
  }
}

/// Tabular figures for numbers that should align in columns (money, GPA,
/// countdowns).
const tabularFigures = [FontFeature.tabularFigures()];

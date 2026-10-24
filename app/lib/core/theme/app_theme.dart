import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A transparent system-bar overlay whose icon brightness follows the APP theme
/// ([isDark]), not the OS setting, so the status/navigation bars show the app's
/// own background behind them.
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

/// Open Campus design tokens — a Material 3 Expressive interpretation.
///
/// The look: a soft off-white canvas, white rounded cards, and bold pastel
/// COLOUR CONTAINERS (lavender, peach, sky, mint, pink, lemon) that carry the
/// main takeaway of each screen, with near-black "ink" for text, the selected
/// navigation item and primary chips. The brand orange and blue from the logo
/// drive the accent fill and the peach/sky containers.
class AppColors {
  /// Brand orange (from the logo). The default accent fill.
  static const orange = Color(0xFFFF8007);

  /// Brand blue (from the logo).
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

/// Expressive shape scale. Small controls use [sm]; tiles and inner blocks use
/// [md]; cards use [lg]; hero containers use [xl]. Buttons, chips and the
/// navigation bar are fully rounded ([full]).
class Radii {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 32.0;
  static const full = 999.0;
}

/// Motion durations (functional: selection, expand/collapse, theme change).
class Motion {
  static const emphasized = Curves.easeOutCubic;
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 450);
}

/// Semantic tone of a badge / note / status / tile.
enum StatusTone { neutral, accent, info, success, warning, danger }

/// Decorative-but-meaningful colour containers, used to colour-code features
/// and to give each screen a focal block (Material 3 Expressive "mix
/// primary/secondary/tertiary containers to highlight the main takeaway").
enum Hue { lavender, peach, sky, mint, pink, lemon, aqua, rose }

/// The app's palette as a theme extension: every colour with meaning comes
/// from here.
class AppPalette extends ThemeExtension<AppPalette> {
  /// Accent fill (buttons, progress) and the readable text on it.
  final Color accent, onAccent;

  /// Contrast-safe text/icon colours on the page/card surface.
  final Color accentInk, infoInk, successInk, warningInk, dangerInk;

  /// Near-black ink for the navigation bar, selected chips and dark buttons,
  /// and the text drawn on it.
  final Color ink, onInk;

  /// The pastel container colours (by [Hue]) and the dark text drawn on them.
  final Map<Hue, Color> containers;
  final Color onContainer;

  /// Page canvas behind the white cards.
  final Color canvas;

  /// Chart / schedule series colours (pastel containers, dark text on top).
  final List<Color> series;

  const AppPalette({
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.infoInk,
    required this.successInk,
    required this.warningInk,
    required this.dangerInk,
    required this.ink,
    required this.onInk,
    required this.containers,
    required this.onContainer,
    required this.canvas,
    required this.series,
  });

  Color container(Hue h) => containers[h]!;

  /// The container hue that represents a semantic tone.
  static Hue hueFor(StatusTone tone) => switch (tone) {
        StatusTone.neutral => Hue.lavender,
        StatusTone.accent => Hue.peach,
        StatusTone.info => Hue.sky,
        StatusTone.success => Hue.mint,
        StatusTone.warning => Hue.lemon,
        StatusTone.danger => Hue.rose,
      };

  // Legacy names (badges/notes use the pastel container as their "tint").
  Color get accentTint => container(Hue.peach);
  Color get infoTint => container(Hue.sky);
  Color get successTint => container(Hue.mint);
  Color get warningTint => container(Hue.lemon);
  Color get dangerTint => container(Hue.rose);

  /// Readable text/icon colour for a [tone] on the card surface.
  Color inkFor(StatusTone tone, ColorScheme scheme) => switch (tone) {
        StatusTone.neutral => scheme.onSurfaceVariant,
        StatusTone.accent => accentInk,
        StatusTone.info => infoInk,
        StatusTone.success => successInk,
        StatusTone.warning => warningInk,
        StatusTone.danger => dangerInk,
      };

  /// Pastel background for a [tone].
  Color tintFor(StatusTone tone, ColorScheme scheme) =>
      tone == StatusTone.neutral
          ? scheme.surfaceContainerHigh
          : container(hueFor(tone));

  /// Solid fill for a [tone] (progress bars, dots).
  Color fillFor(StatusTone tone, ColorScheme scheme) => switch (tone) {
        StatusTone.neutral => scheme.onSurfaceVariant,
        StatusTone.accent => accent,
        _ => inkFor(tone, scheme),
      };

  @override
  AppPalette copyWith({List<Color>? series}) => AppPalette(
        accent: accent,
        onAccent: onAccent,
        accentInk: accentInk,
        infoInk: infoInk,
        successInk: successInk,
        warningInk: warningInk,
        dangerInk: dangerInk,
        ink: ink,
        onInk: onInk,
        containers: containers,
        onContainer: onContainer,
        canvas: canvas,
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
      infoInk: l(infoInk, other.infoInk),
      successInk: l(successInk, other.successInk),
      warningInk: l(warningInk, other.warningInk),
      dangerInk: l(dangerInk, other.dangerInk),
      ink: l(ink, other.ink),
      onInk: l(onInk, other.onInk),
      containers: {
        for (final h in Hue.values) h: l(containers[h]!, other.containers[h]!),
      },
      onContainer: l(onContainer, other.onContainer),
      canvas: l(canvas, other.canvas),
      series: [
        for (var i = 0; i < math.min(series.length, other.series.length); i++)
          l(series[i], other.series[i]),
      ],
    );
  }
}

/// Compatibility view for older `context.status` call sites.
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
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Near-black or white — whichever reads better on [fill].
Color onColor(Color fill) {
  const dark = Color(0xFF15161A);
  return contrastRatio(dark, fill) >= contrastRatio(Colors.white, fill)
      ? dark
      : Colors.white;
}

/// Backwards-compatible name for [onColor].
Color onAccent(Color accent) => onColor(accent);

/// Darken (on light surfaces) or lighten (on dark ones) [base] until it reaches
/// [min] contrast against [surface], keeping its hue.
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

/// An opaque soft tint of [base] over [surface].
Color tintOf(Color base, Color surface, {double alpha = 0.12}) =>
    Color.alphaBlend(base.withValues(alpha: alpha), surface);

class AppTheme {
  static const fontFamily = 'Google Sans Flex';

  static ThemeData light({Color seed = AppColors.seed}) =>
      _build(Brightness.light, seed: seed);
  static ThemeData dark({Color seed = AppColors.seed, bool black = false}) =>
      _build(Brightness.dark, seed: seed, black: black);

  static const _inkDark = Color(0xFF15161A);

  static Map<Hue, Color> _containers(Brightness b) => b == Brightness.light
      ? const {
          Hue.lavender: Color(0xFFCDBDFF),
          Hue.peach: Color(0xFFFFC688),
          Hue.sky: Color(0xFFAAD5FF),
          Hue.mint: Color(0xFFBDEBC5),
          Hue.pink: Color(0xFFF7BCEC),
          Hue.lemon: Color(0xFFFFE08A),
          Hue.aqua: Color(0xFFA5E4F1),
          Hue.rose: Color(0xFFFFC1BB),
        }
      : const {
          Hue.lavender: Color(0xFFB4A2F2),
          Hue.peach: Color(0xFFF2AE66),
          Hue.sky: Color(0xFF8EC0F2),
          Hue.mint: Color(0xFF9CD6A9),
          Hue.pink: Color(0xFFE39FD8),
          Hue.lemon: Color(0xFFEDCB66),
          Hue.aqua: Color(0xFF82CFE0),
          Hue.rose: Color(0xFFF0A49C),
        };

  static ColorScheme _neutralScheme(Brightness b, {bool black = false}) {
    if (b == Brightness.light) {
      return const ColorScheme.light().copyWith(
        surface: Colors.white,
        onSurface: _inkDark,
        onSurfaceVariant: const Color(0xFF5F6168),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF8F8FA),
        surfaceContainer: const Color(0xFFF1F1F5),
        surfaceContainerHigh: const Color(0xFFEBEBF0),
        surfaceContainerHighest: const Color(0xFFE3E3EA),
        outline: const Color(0xFFC9CAD2),
        outlineVariant: const Color(0xFFE8E8EE),
        inverseSurface: _inkDark,
        onInverseSurface: const Color(0xFFF4F4F7),
        surfaceTint: Colors.transparent,
        scrim: Colors.black,
      );
    }
    var s = const ColorScheme.dark().copyWith(
      surface: const Color(0xFF1A1B20),
      onSurface: const Color(0xFFF0F0F4),
      onSurfaceVariant: const Color(0xFFA4A6B0),
      surfaceContainerLowest: const Color(0xFF0F1013),
      surfaceContainerLow: const Color(0xFF1F2026),
      surfaceContainer: const Color(0xFF24252C),
      surfaceContainerHigh: const Color(0xFF2B2C34),
      surfaceContainerHighest: const Color(0xFF34363F),
      outline: const Color(0xFF4A4C57),
      outlineVariant: const Color(0xFF2E3038),
      inverseSurface: const Color(0xFFF0F0F4),
      onInverseSurface: _inkDark,
      surfaceTint: Colors.transparent,
      scrim: Colors.black,
    );
    if (black) {
      s = s.copyWith(
        surface: const Color(0xFF111111),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF161616),
        surfaceContainer: const Color(0xFF1C1C1C),
        surfaceContainerHigh: const Color(0xFF242424),
        surfaceContainerHighest: const Color(0xFF2E2E2E),
        outline: const Color(0xFF3A3A3A),
        outlineVariant: const Color(0xFF262626),
      );
    }
    return s;
  }

  static Color _canvas(Brightness b, bool black) => b == Brightness.light
      ? const Color(0xFFF4F4F7)
      : (black ? const Color(0xFF000000) : const Color(0xFF111216));

  /// Accent fill and the peach/sky container pair for a seed. The brand seed
  /// keeps the logo's orange + blue; other seeds derive a fill and a soft
  /// container of their own hue (and a companion hue for "info").
  static (Color, Color, Color, Color) _accentsFor(Color seed, Brightness b) {
    final containers = _containers(b);
    if (seed.toARGB32() == AppColors.customSeed.toARGB32()) {
      return (
        AppColors.orange,
        AppColors.blue,
        containers[Hue.peach]!,
        containers[Hue.sky]!,
      );
    }
    final hsl = HSLColor.fromColor(seed);
    final fill = hsl.withLightness(hsl.lightness.clamp(0.45, 0.6)).toColor();
    final info = hsl.withHue((hsl.hue + 30) % 360).toColor();
    final light = b == Brightness.light;
    Color soft(HSLColor c) => c
        .withSaturation((c.saturation * 0.85).clamp(0.35, 0.9))
        .withLightness(light ? 0.80 : 0.68)
        .toColor();
    return (fill, info, soft(hsl), soft(HSLColor.fromColor(info)));
  }

  static ThemeData _build(Brightness brightness,
      {Color seed = AppColors.seed, bool black = false}) {
    final dark = brightness == Brightness.dark;
    var scheme = _neutralScheme(brightness, black: black);
    final canvas = _canvas(brightness, black);
    final (accent, info, accentContainer, infoContainer) =
        _accentsFor(seed, brightness);
    final containers = {
      ..._containers(brightness),
      Hue.peach: accentContainer,
      Hue.sky: infoContainer,
    };
    final surface = scheme.surface;

    final success = dark ? const Color(0xFF6FD08F) : const Color(0xFF17703A);
    final warning = dark ? const Color(0xFFF2C063) : const Color(0xFF8A5300);
    final danger = dark ? const Color(0xFFFF9C92) : const Color(0xFFC0392B);

    final ink = dark ? const Color(0xFFF0F0F4) : _inkDark;
    final p = AppPalette(
      accent: accent,
      onAccent: onColor(accent),
      accentInk: readableInk(accent, surface),
      infoInk: readableInk(info, surface),
      successInk: readableInk(success, surface),
      warningInk: readableInk(warning, surface),
      dangerInk: readableInk(danger, surface),
      ink: ink,
      onInk: onColor(ink),
      containers: containers,
      onContainer: _inkDark,
      canvas: canvas,
      series: [
        containers[Hue.peach]!,
        containers[Hue.sky]!,
        containers[Hue.lavender]!,
        containers[Hue.mint]!,
        containers[Hue.pink]!,
        containers[Hue.lemon]!,
        containers[Hue.aqua]!,
        containers[Hue.rose]!,
      ],
    );

    scheme = scheme.copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accentTint,
      onPrimaryContainer: p.onContainer,
      secondary: info,
      onSecondary: onColor(info),
      secondaryContainer: p.infoTint,
      onSecondaryContainer: p.onContainer,
      tertiary: p.container(Hue.lavender),
      onTertiary: p.onContainer,
      tertiaryContainer: p.container(Hue.lavender),
      onTertiaryContainer: p.onContainer,
      error: p.dangerInk,
      onError: onColor(p.dangerInk),
      errorContainer: p.dangerTint,
      onErrorContainer: p.onContainer,
      inversePrimary: p.accentTint,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: fontFamily,
      extensions: [p],
    );
    final text = _typography(scheme);

    const pill = StadiumBorder();
    const controlSize = Size(64, 48);
    final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    OutlineInputBorder inputBorder(Color c, [double w = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
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
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.ink,
        indicatorColor: p.onInk,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: p.ink,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: IconThemeData(color: p.onInk, size: 22),
        unselectedIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        selectedLabelTextStyle: text.labelLarge!
            .copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle:
            text.labelLarge!.copyWith(color: scheme.onSurfaceVariant),
        useIndicator: true,
        minWidth: 88,
        minExtendedWidth: 232,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          shape: pill,
          side: BorderSide(color: scheme.outline, width: 1.2),
          foregroundColor: scheme.onSurface,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          shape: pill,
          foregroundColor: scheme.onSurface,
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
        backgroundColor: p.ink,
        foregroundColor: p.onInk,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg + 4, vertical: Spacing.lg),
        border: inputBorder(scheme.outlineVariant),
        enabledBorder: inputBorder(scheme.outlineVariant),
        disabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(p.ink, 2),
        errorBorder: inputBorder(p.dangerInk),
        focusedErrorBorder: inputBorder(p.dangerInk, 2),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle:
            text.labelLarge?.copyWith(color: scheme.onSurface),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: p.dangerInk),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyLarge,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md))),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: p.ink,
        disabledColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outlineVariant, width: 1.2),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: p.onInk),
        checkmarkColor: p.onInk,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg + 4),
        minVerticalPadding: 12,
        iconColor: scheme.onSurface,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodySmall,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.onInk : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? p.ink
                : scheme.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.ink : scheme.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.ink : Colors.transparent),
        checkColor: WidgetStatePropertyAll(p.onInk),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.ink,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: p.ink,
        overlayColor: p.ink.withValues(alpha: 0.10),
        valueIndicatorColor: p.ink,
        valueIndicatorTextStyle: text.labelMedium?.copyWith(color: p.onInk),
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.onInk),
        actionTextColor: p.container(Hue.peach),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md)),
        insetPadding: const EdgeInsets.all(Spacing.lg),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg)),
        titleTextStyle: text.titleLarge,
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
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(Radii.lg))),
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        textStyle: text.labelMedium?.copyWith(color: p.onInk),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md)),
        textStyle: text.bodyMedium,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: scheme.onSurface,
        collapsedIconColor: scheme.onSurfaceVariant,
        tilePadding: const EdgeInsets.symmetric(horizontal: Spacing.lg + 4),
      ),
    );
  }

  /// Type scale in Google Sans Flex (sharp). Strong weight contrast: ExtraBold
  /// display figures, Bold headlines, SemiBold titles, Regular body, Medium
  /// labels; large sizes are tightened.
  static TextTheme _typography(ColorScheme scheme) {
    TextStyle s(double size, FontWeight w, double height,
            {Color? color, double spacing = 0}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: spacing,
          color: color ?? scheme.onSurface,
        );
    return TextTheme(
      displayLarge: s(54, FontWeight.w800, 1.0, spacing: -1.6),
      displayMedium: s(44, FontWeight.w800, 1.05, spacing: -1.2),
      displaySmall: s(36, FontWeight.w800, 1.08, spacing: -0.9),
      headlineLarge: s(32, FontWeight.w700, 1.12, spacing: -0.7),
      headlineMedium: s(28, FontWeight.w700, 1.15, spacing: -0.5),
      headlineSmall: s(23, FontWeight.w700, 1.2, spacing: -0.3),
      titleLarge: s(20, FontWeight.w600, 1.25, spacing: -0.2),
      titleMedium: s(16.5, FontWeight.w600, 1.3, spacing: -0.1),
      titleSmall: s(14.5, FontWeight.w600, 1.3),
      bodyLarge: s(16, FontWeight.w400, 1.45),
      bodyMedium: s(14.5, FontWeight.w400, 1.45),
      bodySmall: s(12.5, FontWeight.w400, 1.4, color: scheme.onSurfaceVariant),
      labelLarge: s(14.5, FontWeight.w500, 1.3),
      labelMedium: s(12.5, FontWeight.w500, 1.3, spacing: 0.1),
      labelSmall: s(11.5, FontWeight.w600, 1.3, spacing: 0.3),
    );
  }
}

/// Tabular figures for numbers that should align in columns.
const tabularFigures = [FontFeature.tabularFigures()];

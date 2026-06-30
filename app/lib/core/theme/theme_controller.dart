import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// How dark the app goes.
///   light  — normal light scheme.
///   dark   — normal Material dark scheme (dark grey surfaces).
///   black  — AMOLED / pitch black: true #000 surfaces for OLED battery + look.
enum AppThemeMode { light, dark, black }

/// The user's chosen appearance: a single source color (à la Material You) plus
/// a theme mode. The whole tonal palette is derived from [seed].
class ThemePrefs {
  final Color seed;
  final AppThemeMode mode;
  const ThemePrefs({required this.seed, required this.mode});

  ThemePrefs copyWith({Color? seed, AppThemeMode? mode}) =>
      ThemePrefs(seed: seed ?? this.seed, mode: mode ?? this.mode);

  ThemeMode get materialMode =>
      mode == AppThemeMode.light ? ThemeMode.light : ThemeMode.dark;

  bool get isBlack => mode == AppThemeMode.black;
}

/// Source colors the user can pick. The first, [custom], is the dual-accent
/// brand theme (orange + blue) and the default. Every other entry renders the
/// SAME clean system (neutral surfaces, white cards) but with two shades of the
/// one picked hue as the accents — fully automatic.
class SeedSwatches {
  /// The Custom (default) seed — orange+blue brand scheme. Equals
  /// AppColors.customSeed so the theme builder applies the dual accents.
  static const custom = Color(0xFFFF8007);

  static const all = <(String, Color)>[
    ('Custom', custom), // orange + blue dual-accent brand theme
    ('Sky', Color(0xFF05BADD)),
    ('Amber', Color(0xFFE8A100)),
    ('Coral', Color(0xFFF4511E)),
    ('Rose', Color(0xFFE53268)),
    ('Magenta', Color(0xFFC2185B)),
    ('Purple', Color(0xFF7C3AED)),
    ('Indigo', Color(0xFF4F46E5)),
    ('Blue', Color(0xFF2563EB)),
    ('Teal', Color(0xFF009688)),
    ('Emerald', Color(0xFF10916B)),
    ('Forest', Color(0xFF2E7D32)),
    ('Slate', Color(0xFF546A7B)),
  ];
}

class ThemeController extends StateNotifier<ThemePrefs> {
  ThemeController()
      : super(const ThemePrefs(
            seed: SeedSwatches.custom, mode: AppThemeMode.light)) {
    _load();
  }

  static const _seedKey = 'oc_theme_seed';
  static const _modeKey = 'oc_theme_mode';

  // Older brand seeds; migrate anyone still on them to the new Custom seed so
  // they land on the refreshed orange+blue brand scheme.
  static const _legacySeeds = <int>[0xFFF08700];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final seedVal = prefs.getInt(_seedKey);
    final modeVal = prefs.getInt(_modeKey);
    Color seed = seedVal != null ? Color(seedVal) : SeedSwatches.custom;
    if (seedVal != null && _legacySeeds.contains(seedVal)) {
      seed = SeedSwatches.custom;
    }
    state = ThemePrefs(
      seed: seed,
      mode: modeVal != null && modeVal < AppThemeMode.values.length
          ? AppThemeMode.values[modeVal]
          : AppThemeMode.light,
    );
  }

  Future<void> setSeed(Color seed) async {
    state = state.copyWith(seed: seed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedKey, seed.toARGB32());
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemePrefs>((ref) {
  return ThemeController();
});

/// Convenience: the live ThemeData pair derived from current prefs.
///
/// Building a ThemeData is not free, and MaterialApp reads both `light` and
/// `dark` on every rebuild — so we MEMOIZE by (seed, isBlack). Repeated reads for
/// the same prefs return the cached ThemeData instantly; only an actual
/// seed/mode change rebuilds. This is what makes theme/accent switching feel
/// instant instead of janky.
ThemeData? _cachedLight;
Color? _cachedLightSeed;
ThemeData? _cachedDark;
Color? _cachedDarkSeed;
bool? _cachedDarkBlack;

extension ThemePrefsBuild on ThemePrefs {
  ThemeData get light {
    if (_cachedLight == null || _cachedLightSeed != seed) {
      _cachedLight = AppTheme.light(seed: seed);
      _cachedLightSeed = seed;
    }
    return _cachedLight!;
  }

  ThemeData get dark {
    if (_cachedDark == null ||
        _cachedDarkSeed != seed ||
        _cachedDarkBlack != isBlack) {
      _cachedDark = AppTheme.dark(seed: seed, black: isBlack);
      _cachedDarkSeed = seed;
      _cachedDarkBlack = isBlack;
    }
    return _cachedDark!;
  }
}

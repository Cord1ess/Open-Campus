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

/// Curated source colors the user can pick from. Each is chosen so
/// `ColorScheme.fromSeed(vibrant)` produces a vivid, well-contrasting scheme in
/// both light and dark; weak seeds that desaturate to mud or fail contrast were
/// dropped. Orange stays the brand default.
class SeedSwatches {
  static const orange = Color(0xFFF08700); // brand default
  static const all = <(String, Color)>[
    ('Orange', orange),
    ('Amber', Color(0xFFE8A100)), // warm gold, richer than pale yellow
    ('Coral', Color(0xFFF4511E)), // orange-red, energetic
    ('Rose', Color(0xFFE53268)), // vivid pink-red
    ('Magenta', Color(0xFFC2185B)),
    ('Purple', Color(0xFF7C3AED)),
    ('Indigo', Color(0xFF4F46E5)),
    ('Blue', Color(0xFF2563EB)),
    ('Sky', Color(0xFF0288D1)),
    ('Teal', Color(0xFF009688)),
    ('Emerald', Color(0xFF10916B)),
    ('Forest', Color(0xFF2E7D32)),
    ('Slate', Color(0xFF546A7B)), // neutral, calm
  ];
}

class ThemeController extends StateNotifier<ThemePrefs> {
  ThemeController()
      : super(const ThemePrefs(
            seed: SeedSwatches.orange, mode: AppThemeMode.light)) {
    _load();
  }

  static const _seedKey = 'oc_theme_seed';
  static const _modeKey = 'oc_theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final seedVal = prefs.getInt(_seedKey);
    final modeVal = prefs.getInt(_modeKey);
    state = ThemePrefs(
      seed: seedVal != null ? Color(seedVal) : SeedSwatches.orange,
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
extension ThemePrefsBuild on ThemePrefs {
  ThemeData get light => AppTheme.light(seed: seed);
  ThemeData get dark => AppTheme.dark(seed: seed, black: isBlack);
}

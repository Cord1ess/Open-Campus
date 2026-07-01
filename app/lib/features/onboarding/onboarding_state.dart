import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has completed the first-run walkthrough.
class OnboardingController extends StateNotifier<bool?> {
  // null = still loading the flag; true = seen; false = needs onboarding.
  OnboardingController() : super(null) {
    _load();
  }

  static const _key = 'oc_onboarding_seen';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (_) {
      // If storage is unavailable, fall back to "needs onboarding" rather than
      // leaving state == null forever (which would hang the launch flow on the
      // splash screen indefinitely — _Root gates on onboardingSeen != null).
      state = false;
    }
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = true;
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingController, bool?>((ref) {
  return OnboardingController();
});

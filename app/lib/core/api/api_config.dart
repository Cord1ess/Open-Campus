import 'package:flutter/foundation.dart';

/// Base URL of the Open Campus backend.
///
/// The hosted backend URL MUST be supplied at build/run time:
///   --dart-define=OC_API_BASE=https://your-api-host
///
/// In a release build this is REQUIRED — there is no usable default, because a
/// tester's device can't reach the developer's localhost. If it's missing we
/// surface a clear configuration error (see [missing]) instead of silently
/// pointing at an unreachable host.
///
/// In debug builds we fall back to local dev hosts for convenience:
///   - Web (Chrome):        http://127.0.0.1:8000
///   - Android emulator:    http://10.0.2.2:8000   (host loopback alias)
///   - iOS sim / desktop:   http://127.0.0.1:8000
class ApiConfig {
  static const String _override =
      String.fromEnvironment('OC_API_BASE', defaultValue: '');

  /// True when no backend URL was provided and we're not in a local debug build
  /// — i.e. a release build that would have nowhere to talk to. The UI shows a
  /// setup message in this case rather than failing opaquely.
  static bool get missing => _override.isEmpty && kReleaseMode;

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    // Release with no configured backend: there's no safe default. Return an
    // obviously-invalid sentinel; `missing` lets the app show a clear message.
    if (kReleaseMode) return 'https://api.invalid';

    // Local development fallbacks (debug only).
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}

import 'package:flutter/foundation.dart';

/// Base URL of the Open Campus backend.
///
/// Defaults to the hosted backend, so release builds and testers need no flags.
/// Override for a different host with:
///   --dart-define=OC_API_BASE=https://your-api-host
///
/// In debug builds we fall back to local dev hosts so `flutter run` against a
/// local backend just works:
///   - Web (Chrome):        http://127.0.0.1:8000
///   - Android emulator:    http://10.0.2.2:8000   (host loopback alias)
///   - iOS sim / desktop:   http://127.0.0.1:8000
class ApiConfig {
  /// The hosted backend. Used by release builds (and debug builds that don't
  /// pass --dart-define and aren't on a local-dev platform default below).
  static const String _hosted = 'https://open-campus-sdsw.onrender.com';

  /// The official UCAM portal (for the About page's "open the real site" link).
  static const String ucamUrl = 'https://ucam.uiu.ac.bd';

  static const String _override =
      String.fromEnvironment('OC_API_BASE', defaultValue: '');

  /// Retained for the login screen's setup check. Always false now that there's
  /// a real hosted default.
  static bool get missing => false;

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    // Release: always the hosted backend.
    if (kReleaseMode) return _hosted;

    // Debug: prefer local dev hosts so a local backend is reachable.
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}

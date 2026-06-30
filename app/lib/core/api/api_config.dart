import 'package:flutter/foundation.dart';

/// Base URL of the Open Campus backend.
///
/// Resolution order:
///   1. --dart-define=OC_API_BASE=https://your-api-host   (explicit override)
///   2. --dart-define=OC_LOCAL=true   → local dev backend (127.0.0.1:8000 /
///      10.0.2.2:8000 on Android). Opt-IN, only when you're running uvicorn.
///   3. Otherwise → the hosted backend, on BOTH release AND debug.
///
/// The hosted default in debug is deliberate: it means `flutter run` / F5 just
/// connects without any flag, so you never hit a "can't reach server" because a
/// debug build silently pointed at a localhost backend that isn't running. Pass
/// OC_LOCAL=true (or OC_API_BASE) when you actually want the local backend.
class ApiConfig {
  /// The hosted backend — the default everywhere unless explicitly overridden.
  static const String _hosted = 'https://open-campus-sdsw.onrender.com';

  /// The official UCAM portal (for the About page's "open the real site" link).
  static const String ucamUrl = 'https://ucam.uiu.ac.bd';

  static const String _override =
      String.fromEnvironment('OC_API_BASE', defaultValue: '');

  /// Opt-in to the local dev backend (only honoured in debug).
  static const bool _useLocal =
      bool.fromEnvironment('OC_LOCAL', defaultValue: false);

  /// Retained for the login screen's setup check. Always false now that there's
  /// a real hosted default.
  static bool get missing => false;

  static String get baseUrl {
    // 1. Explicit host override always wins.
    if (_override.isNotEmpty) return _override;

    // 2. Local dev backend — ONLY when explicitly opted in (debug only).
    if (!kReleaseMode && _useLocal) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8000'; // Android emulator host loopback
      }
      return 'http://127.0.0.1:8000';
    }

    // 3. Default everywhere: the hosted backend.
    return _hosted;
  }
}

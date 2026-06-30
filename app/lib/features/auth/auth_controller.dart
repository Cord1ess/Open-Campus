import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// Auth state for the app.
sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSignedOut extends AuthState {
  /// Optional message to show on the login screen (e.g. after a forced logout).
  final String? message;
  const AuthSignedOut({this.message});
}

class AuthSignedIn extends AuthState {
  final String roll;

  /// True when this state came from an interactive login THIS session (vs. a
  /// silently restored session on cold app-start). A fresh login should always
  /// run the blocking bootstrap (wait for all data) so the dashboard never
  /// appears empty and fills in card-by-card; a restored session can use the
  /// instant-shell path (show cached data immediately, refresh behind it).
  final bool fromLogin;

  const AuthSignedIn(this.roll, {this.fromLogin = false});
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref)..restore();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthLoading());
  final Ref _ref;

  /// Try to restore a saved session token on app start. Never throws — any
  /// storage failure (e.g. secure storage unavailable on web) just lands the
  /// user on the login screen instead of a blank app.
  Future<void> restore() async {
    try {
      final storage = _ref.read(tokenStorageProvider);
      final token = await storage.read();
      if (token == null || token.isEmpty) {
        state = const AuthSignedOut();
        return;
      }
      _ref.read(tokenProvider.notifier).state = token;
      // The dashboard's first fetch validates the token; if stale, screens
      // surface re-login.
      state = const AuthSignedIn('');
    } catch (_) {
      state = const AuthSignedOut();
    }
  }

  /// Returns an error message on failure, or null on success. When [remember]
  /// is true the credentials are saved on-device for 30 days (local only).
  Future<String?> login(String studentId, String password,
      {bool remember = false}) async {
    state = const AuthLoading();
    final api = _ref.read(apiClientProvider);
    final result = await api.login(studentId, password);
    switch (result) {
      case ApiOk(:final data):
        await _ref.read(tokenStorageProvider).save(data.token);
        final creds = _ref.read(credentialStoreProvider);
        if (remember) {
          await creds.save(studentId, password);
        } else {
          await creds.clear();
        }
        _ref.read(tokenProvider.notifier).state = data.token;
        state = AuthSignedIn(data.roll, fromLogin: true);
        return null;
      case ApiUnauthorized():
        state = const AuthSignedOut();
        return 'Invalid student ID or password.';
      case ApiUnavailable(:final message):
        state = const AuthSignedOut();
        return message;
      case ApiSessionExpired():
        state = const AuthSignedOut();
        return 'Please try again.';
    }
  }

  Future<void> logout({String? message}) async {
    final api = _ref.read(apiClientProvider);
    await api.logout();
    await _ref.read(tokenStorageProvider).clear();
    await _ref.read(credentialStoreProvider).clear(); // forget saved password
    await _ref.read(localCacheProvider).clearAll(); // clear on-device data
    _ref.read(tokenProvider.notifier).state = null;
    state = AuthSignedOut(message: message);
  }
}

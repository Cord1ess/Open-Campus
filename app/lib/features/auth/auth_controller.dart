import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/session_state.dart';
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

  /// Restore the session on app start. Never throws — any storage failure just
  /// lands the user on the login screen instead of a blank app.
  ///
  /// "Keep me signed in for 30 days" means exactly that: no re-login tap. Our
  /// backend token / UCAM session only lives ~60 min, so a restored JWT is
  /// almost always dead on a cold start — trusting it would show the app, then
  /// bounce the user to the session-expired overlay. Instead, if the user opted
  /// in and saved credentials exist (on-device, <=30 days), we SILENTLY log in
  /// again in the background to get a live session, and land the user straight
  /// in the app — cached data shows instantly, live data swaps in when ready.
  ///
  /// Only when there are no saved credentials do we fall back to the old
  /// restore-token path (or the login screen).
  Future<void> restore() async {
    try {
      final saved = await _ref.read(credentialStoreProvider).read();
      if (saved != null) {
        // Silent auto-login. On success we are genuinely signed in with a fresh
        // live session; on failure we surface the login screen (prefilled) with
        // a reason, and — if the password was actually rejected — the saved
        // creds are cleared so it can't loop.
        await _silentLogin(saved.id, saved.password);
        return;
      }

      // No saved credentials: best-effort restore of an existing token. The
      // first data fetch validates it; if the session died, screens surface the
      // re-login overlay.
      final storage = _ref.read(tokenStorageProvider);
      final token = await storage.read();
      if (token == null || token.isEmpty) {
        state = const AuthSignedOut();
        return;
      }
      _ref.read(tokenProvider.notifier).state = token;
      state = const AuthSignedIn('');
    } catch (_) {
      state = const AuthSignedOut();
    }
  }

  /// Background re-login using stored credentials (the "keep me signed in" path).
  /// Unlike an interactive [login], a success here is marked `fromLogin: false`
  /// so the launch flow uses the instant-shell path (show cached data, refresh
  /// behind it) rather than the blocking bootstrap screen — the user shouldn't
  /// see a full-screen loader just for reopening an app they never logged out of.
  Future<void> _silentLogin(String studentId, String password) async {
    final api = _ref.read(apiClientProvider);
    final result = await api.login(studentId, password);
    switch (result) {
      case ApiOk(:final data):
        await _ref.read(tokenStorageProvider).save(data.token);
        // Refresh the saved-credentials expiry window on a successful auto-login
        // so an actively-used app stays remembered, rolling 30 days forward.
        await _ref.read(credentialStoreProvider).save(studentId, password);
        _ref.read(tokenProvider.notifier).state = data.token;
        _ref.read(sessionProvider.notifier).reset();
        state = AuthSignedIn(data.roll, fromLogin: false);
      case ApiUnauthorized():
        // The saved password no longer works (changed / reset). Clear it so we
        // don't retry a doomed login every launch, and ask the user to sign in.
        await _ref.read(credentialStoreProvider).clear();
        state = const AuthSignedOut(
            message: 'Your saved password no longer works. Please sign in.');
      case ApiUnavailable(:final message):
        // Backend/network problem — keep the saved creds (they may be fine) and
        // let the user retry from the prefilled login screen.
        state = AuthSignedOut(message: message);
      case ApiSessionExpired():
        state = const AuthSignedOut(message: 'Please sign in again.');
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
        // Fresh, live session — clear any lingering "expired" flag.
        _ref.read(sessionProvider.notifier).reset();
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
    _ref.read(sessionProvider.notifier).reset();
    state = AuthSignedOut(message: message);
  }

  /// Triggered from the session-expired overlay. The UCAM session is dead, so
  /// the honest, safe action is a full sign-out: drop the stale token AND the
  /// stale on-device cache (so no out-of-date data survives), then send the user
  /// to the login screen. A fresh login refetches everything live. Saved
  /// credentials (if opted in) make the re-login one tap on the login screen.
  Future<void> relogin() async {
    await logout(message: 'Your session expired. Please log in again.');
  }
}

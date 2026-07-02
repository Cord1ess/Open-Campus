import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide session liveness.
///
///   active   — our token resolves to a live UCAM session.
///   expired  — the backend returned 409 on some call: the upstream UCAM session
///              died. This is a GLOBAL signal, flipped the instant ANY request
///              sees a 409, so the whole app can react at once (a blocking
///              re-login overlay) instead of each screen discovering it on its
///              own and meanwhile showing stale cached data.
enum SessionStatus { active, expired }

class SessionController extends StateNotifier<SessionStatus> {
  SessionController() : super(SessionStatus.active);

  /// Flip to expired. Idempotent — safe to call from many providers at once.
  void markExpired() {
    if (state != SessionStatus.expired) state = SessionStatus.expired;
  }

  /// Reset to active (after a successful re-login, or a fresh login/logout).
  void reset() {
    if (state != SessionStatus.active) state = SessionStatus.active;
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionStatus>((ref) {
  return SessionController();
});

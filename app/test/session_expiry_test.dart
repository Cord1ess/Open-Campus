import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_campus/core/auth/session_state.dart';

/// Tests for the global session-expiry signal that drives the app-wide
/// blocking overlay. The ApiClient fires onSessionExpired on any 409; these
/// verify the state machine that overlay/auth react to.
void main() {
  group('SessionController', () {
    test('starts active', () {
      final c = SessionController();
      expect(c.state, SessionStatus.active);
    });

    test('markExpired flips to expired and is idempotent', () {
      final c = SessionController();
      var notifications = 0;
      c.addListener((_) => notifications++, fireImmediately: false);
      c.markExpired();
      c.markExpired(); // second call must NOT re-notify
      expect(c.state, SessionStatus.expired);
      expect(notifications, 1);
    });

    test('reset returns to active', () {
      final c = SessionController()..markExpired();
      c.reset();
      expect(c.state, SessionStatus.active);
    });

    test('sessionProvider exposes the controller through a container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(sessionProvider), SessionStatus.active);
      container.read(sessionProvider.notifier).markExpired();
      expect(container.read(sessionProvider), SessionStatus.expired);
      container.read(sessionProvider.notifier).reset();
      expect(container.read(sessionProvider), SessionStatus.active);
    });
  });
}

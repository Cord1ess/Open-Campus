import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/brand_logo.dart';
import 'auth_controller.dart';

/// A full-screen, BLOCKING overlay shown the instant the UCAM session expires
/// (any 409). It sits above the whole app so no stale cached data can be
/// browsed while the session is dead. Re-logging in clears it and refreshes
/// everything live; the alternative is a full logout.
///
/// Only shown when signed in — a 409 while already signed out is meaningless.
class SessionExpiredOverlay extends ConsumerWidget {
  const SessionExpiredOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = ref.watch(sessionProvider) == SessionStatus.expired;
    final signedIn = ref.watch(authControllerProvider) is AuthSignedIn;
    if (!expired || !signedIn) return const SizedBox.shrink();

    final scheme = context.scheme;
    // A scrim + centered card. AbsorbPointer/opaque scrim blocks all taps to the
    // app underneath, so the user cannot interact with stale screens.
    return Positioned.fill(
      child: Material(
        color: scheme.scrim.withValues(alpha: 0.55),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              margin: const EdgeInsets.all(Spacing.xl),
              padding: const EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandIcon(size: 56),
                  const SizedBox(height: Spacing.lg),
                  Text('Session expired',
                      style: context.text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Your UCAM session ended, so the data on screen may be out of '
                    'date. Log in again to continue with fresh, live data.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Spacing.xl),
                  FilledButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).relogin(),
                    child: const Text('Log in again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

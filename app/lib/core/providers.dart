import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/credential_store.dart';
import 'auth/session_state.dart';
import 'auth/token_storage.dart';
import 'cache/local_cache.dart';

/// App-wide singletons.

final tokenStorageProvider = Provider((_) => TokenStorage());
final credentialStoreProvider = Provider((_) => CredentialStore());
final localCacheProvider = Provider((_) => LocalCache());

/// Holds the current token in memory so the dio interceptor can read it
/// synchronously. Mirrors secure storage; updated by the auth controller.
final tokenProvider = StateProvider<String?>((_) => null);

final apiClientProvider = Provider((ref) {
  return ApiClient(
    tokenProvider: () => ref.read(tokenProvider),
    // Any 409 (UCAM session died upstream) flips the global session state so the
    // whole app shows the blocking re-login overlay at once.
    onSessionExpired: () =>
        ref.read(sessionProvider.notifier).markExpired(),
  );
});

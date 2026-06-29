import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores the Open Campus JWT (our token, never the UCAM password).
/// Backed by Keychain (iOS), Keystore (Android), and an encrypted store on web.
class TokenStorage {
  static const _key = 'oc_token';
  final _storage = const FlutterSecureStorage();

  Future<void> save(String token) => _storage.write(key: _key, value: token);
  Future<String?> read() => _storage.read(key: _key);
  Future<void> clear() => _storage.delete(key: _key);
}

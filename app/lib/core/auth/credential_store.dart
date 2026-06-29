import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Optionally remembers the user's UCAM credentials ON THIS DEVICE ONLY, for a
/// limited window (default 30 days), so they don't have to retype them every
/// launch. This is purely local convenience — credentials are written to the
/// platform secure store (Keychain / Keystore / encrypted web store), never
/// sent anywhere except to log in, and never stored on our servers. The user
/// opts in with a checkbox; logging out or letting it expire clears it.
class CredentialStore {
  static const _key = 'oc_saved_credentials';
  final _storage = const FlutterSecureStorage();

  /// Persist credentials with an expiry [days] from now.
  Future<void> save(String studentId, String password,
      {int days = 30}) async {
    final expiry = DateTime.now().add(Duration(days: days));
    final blob = jsonEncode({
      'id': studentId,
      'pw': password,
      'exp': expiry.millisecondsSinceEpoch,
    });
    await _storage.write(key: _key, value: blob);
  }

  /// Returns saved (id, password) if present and not expired, else null.
  /// Expired entries are cleared lazily on read.
  Future<({String id, String password})?> read() async {
    try {
      final blob = await _storage.read(key: _key);
      if (blob == null || blob.isEmpty) return null;
      final map = jsonDecode(blob) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null ||
          DateTime.now().millisecondsSinceEpoch > exp) {
        await clear();
        return null;
      }
      return (id: map['id'] as String, password: map['pw'] as String);
    } catch (_) {
      // Corrupt blob or storage failure — treat as nothing saved.
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _key);
}

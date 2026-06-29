import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// On-device last-view cache.
///
/// The SERVER stores nothing — this is the only place data rests, and it's on
/// the user's own device. We keep the last successful payload per resource plus
/// when it was fetched, so the app launches instantly and can show a
/// "last seen" date if the live fetch fails. Cleared on logout.
class LocalCache {
  static const _prefix = 'oc_cache_';

  Future<void> put(String resource, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'fetched_at': DateTime.now().toIso8601String(),
      'data': json,
    };
    await prefs.setString('$_prefix$resource', jsonEncode(entry));
  }

  Future<CachedEntry?> get(String resource) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$resource');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return CachedEntry(
        fetchedAt: DateTime.parse(m['fetched_at'] as String),
        data: m['data'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Wipe all cached data (called on logout).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

class CachedEntry {
  final DateTime fetchedAt;
  final Map<String, dynamic> data;
  const CachedEntry({required this.fetchedAt, required this.data});
}

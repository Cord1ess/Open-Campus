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

  /// True if ANY resource has a cached copy — i.e. this isn't the user's very
  /// first launch. Lets the launch flow skip the blocking bootstrap and render
  /// the shell instantly (cards hydrate live behind their cached data).
  Future<bool> hasAny() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().any((k) => k.startsWith(_prefix));
  }

  /// A summary of what's currently stored on the device — how many resources are
  /// cached, roughly how many bytes they occupy, and the most-recent fetch time.
  /// Used by the Settings page to show the user what's stored and when it last
  /// synced, before they choose to clear it.
  Future<CacheSummary> summary() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    var count = 0;
    var bytes = 0;
    DateTime? newest;
    for (final k in keys) {
      final raw = prefs.getString(k);
      if (raw == null) continue;
      count++;
      bytes += raw.length;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final at = DateTime.parse(m['fetched_at'] as String);
        if (newest == null || at.isAfter(newest)) newest = at;
      } catch (_) {/* ignore malformed entry in the summary */}
    }
    return CacheSummary(resourceCount: count, bytes: bytes, lastSynced: newest);
  }

  /// Wipe all cached data (called on logout, and from Settings → Clear cached
  /// data). The server stores nothing, so this removes the only copy of the
  /// user's data that exists anywhere off UCAM.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

/// What the on-device cache currently holds, for the Settings disclosure.
class CacheSummary {
  final int resourceCount;
  final int bytes;
  final DateTime? lastSynced;
  const CacheSummary({
    required this.resourceCount,
    required this.bytes,
    required this.lastSynced,
  });

  bool get isEmpty => resourceCount == 0;
}

class CachedEntry {
  final DateTime fetchedAt;
  final Map<String, dynamic> data;
  const CachedEntry({required this.fetchedAt, required this.data});
}

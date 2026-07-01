import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';
import '../academics/advising_model.dart';
import '../academics/calendar_model.dart';
import '../academics/course_history_model.dart';
import '../academics/exam_routine_model.dart';
import '../academics/marks_model.dart';
import '../academics/uiu_notices_model.dart';
import '../finance/bill_model.dart';
import 'home_model.dart';
import 'models.dart';
import 'notices_model.dart';

/// A resource's loaded state: the parsed data + where it came from.
class Loaded<T> {
  final T data;
  final Freshness freshness;
  final DateTime? syncedAt;
  const Loaded(this.data, this.freshness, this.syncedAt);
}

/// One screen-state for a resource: loading / loaded(live|cached) / needsRelogin
/// / error. The UI renders cached data underneath a re-login banner when needed.
sealed class ResourceState<T> {
  const ResourceState();
}

class ResLoading<T> extends ResourceState<T> {
  const ResLoading();
}

class ResData<T> extends ResourceState<T> {
  final Loaded<T> loaded;
  /// True when the live fetch failed and we're showing device cache; if the
  /// failure was a session-expiry, the dashboard also shows a re-login banner.
  final bool sessionExpired;
  const ResData(this.loaded, {this.sessionExpired = false});
}

class ResError<T> extends ResourceState<T> {
  final String message;
  /// Distinguishes "your token died, go to login" from a transient error.
  final bool unauthorized;
  const ResError(this.message, {this.unauthorized = false});
}

/// Generic loader: try live → on failure, fall back to device cache.
class ResourceController<T> extends StateNotifier<ResourceState<T>> {
  ResourceController(
    this._ref, {
    required this.resource,
    required this.path,
    required this.parse,
    required this.toJson,
    this.freshFor = const Duration(minutes: 15),
  }) : super(const ResLoading());

  final Ref _ref;
  final String resource;
  final String path;
  final T Function(Map<String, dynamic>) parse;
  final Map<String, dynamic> Function(T) toJson;

  /// How long an on-device cached copy is considered fresh. Within this window a
  /// non-forced load (app launch, tab open, retry) serves the cache and SKIPS
  /// the network call entirely — this is what takes redundant scrape load off
  /// the backend, since reopening or revisiting the app no longer re-pulls UCAM
  /// every time. A user-initiated pull-to-refresh always passes force:true to
  /// bypass this and fetch live. The server stays stateless; the throttle lives
  /// entirely on the device.
  final Duration freshFor;

  bool _loading = false;
  bool _loadedOnce = false;

  /// Load only if we haven't successfully loaded yet (used by the shell to kick
  /// off the first fetch after the UI mounts, without re-fetching on rebuilds).
  Future<void> ensureLoaded() async {
    if (_loadedOnce || _loading) return;
    await load();
  }

  /// [force] = true bypasses the freshness window and always hits the network
  /// (pull-to-refresh). Default false respects [freshFor].
  Future<void> load({bool force = false}) async {
    if (_loading) return; // coalesce concurrent calls
    _loading = true;
    try {
      await _load(force: force);
    } finally {
      _loading = false;
    }
  }

  Future<void> _load({bool force = false}) async {
    final api = _ref.read(apiClientProvider);
    final cache = _ref.read(localCacheProvider);

    // Cache-first: if we have a saved copy, show it INSTANTLY (no skeleton) while
    // the live fetch happens behind it. Only show a skeleton on a true cold start.
    final cached = await cache.get(resource);
    if (cached != null) {
      try {
        state = ResData(
            Loaded(parse(cached.data), Freshness.cached, cached.fetchedAt));
        // Freshness throttle: if the cached copy is still within its window and
        // this isn't a forced refresh, serve it and SKIP the network entirely.
        // This is what removes redundant UCAM pulls — reopening the app or
        // revisiting a tab won't re-scrape until the data is actually stale.
        final age = DateTime.now().difference(cached.fetchedAt);
        if (!force && age < freshFor) {
          _loadedOnce = true;
          return;
        }
      } catch (_) {/* corrupt cache — ignore, fall through to skeleton */}
    }
    if (state is! ResData) {
      state = const ResLoading();
    }

    // Wait briefly for the auth token to be in memory. On app start the
    // dashboard can build a tick before restore() has populated the token,
    // which would make the first fetch fail and require a manual reload.
    await _awaitToken();

    // Transient failures (backend cold start, token-restore race) get one
    // automatic retry so the user doesn't have to pull-to-refresh.
    var result =
        await api.getJson<T>(path, (j) => parse(j as Map<String, dynamic>));
    if (result is ApiUnavailable<T>) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      result =
          await api.getJson<T>(path, (j) => parse(j as Map<String, dynamic>));
    }

    switch (result) {
      case ApiOk(:final data):
        await cache.put(resource, toJson(data));
        state = ResData(Loaded(data, Freshness.live, DateTime.now()));
        _loadedOnce = true;
      case ApiUnauthorized():
        state = const ResError('Session ended. Please log in again.',
            unauthorized: true);
      case ApiSessionExpired():
        await _fallbackToCache(sessionExpired: true);
      case ApiUnavailable(:final message):
        await _fallbackToCache(sessionExpired: false, errorMessage: message);
    }
  }

  /// Poll briefly (up to ~2s) for the in-memory token to appear, so the very
  /// first fetch after launch doesn't race token restoration.
  Future<void> _awaitToken() async {
    for (var i = 0; i < 20; i++) {
      final t = _ref.read(tokenProvider);
      if (t != null && t.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _fallbackToCache(
      {required bool sessionExpired, String? errorMessage}) async {
    final cache = _ref.read(localCacheProvider);
    final entry = await cache.get(resource);
    if (entry != null) {
      state = ResData(
        Loaded(parse(entry.data), Freshness.cached, entry.fetchedAt),
        sessionExpired: sessionExpired,
      );
    } else {
      state = ResError(errorMessage ??
          'Couldn\'t reach the university portal, and no saved copy exists yet.');
    }
  }
}

final resultsProvider =
    StateNotifierProvider<ResourceController<ResultsData>, ResourceState<ResultsData>>(
        (ref) {
  return ResourceController<ResultsData>(
    ref,
    resource: 'results',
    path: '/student/results',
    parse: ResultsData.fromJson,
    toJson: (d) => d.toJson(),
    // Published grades change at most a few times a trimester.
    freshFor: const Duration(minutes: 30),
  );
});

final attendanceProvider = StateNotifierProvider<
    ResourceController<AttendanceData>, ResourceState<AttendanceData>>((ref) {
  return ResourceController<AttendanceData>(
    ref,
    resource: 'attendance',
    path: '/student/attendance',
    parse: AttendanceData.fromJson,
    toJson: (d) => d.toJson(),
    // Updated per class; refresh a bit more eagerly.
    freshFor: const Duration(minutes: 10),
  );
});

final homeProvider = StateNotifierProvider<ResourceController<HomeSummary>,
    ResourceState<HomeSummary>>((ref) {
  return ResourceController<HomeSummary>(
    ref,
    resource: 'home',
    path: '/student/home',
    parse: HomeSummary.fromJson,
    toJson: (d) => d.toJson(),
    // Profile/term summary is very stable.
    freshFor: const Duration(minutes: 30),
  );
});

final noticesProvider = StateNotifierProvider<ResourceController<NoticesData>,
    ResourceState<NoticesData>>((ref) {
  return ResourceController<NoticesData>(
    ref,
    resource: 'notices',
    path: '/student/notices',
    parse: NoticesData.fromJson,
    toJson: (d) => d.toJson(),
  );
});

final courseHistoryProvider = StateNotifierProvider<
    ResourceController<CourseHistoryData>,
    ResourceState<CourseHistoryData>>((ref) {
  return ResourceController<CourseHistoryData>(
    ref,
    resource: 'course_history',
    path: '/student/course-history',
    parse: CourseHistoryData.fromJson,
    toJson: (d) => d.toJson(),
    // Full transcript — changes only at end of trimester.
    freshFor: const Duration(hours: 1),
  );
});

final billProvider =
    StateNotifierProvider<ResourceController<BillData>, ResourceState<BillData>>(
        (ref) {
  return ResourceController<BillData>(
    ref,
    resource: 'bill',
    path: '/student/bill',
    parse: BillData.fromJson,
    toJson: (d) => d.toJson(),
  );
});

final advisingProvider = StateNotifierProvider<ResourceController<AdvisingData>,
    ResourceState<AdvisingData>>((ref) {
  return ResourceController<AdvisingData>(
    ref,
    resource: 'advising',
    path: '/student/advising',
    parse: AdvisingData.fromJson,
    toJson: (d) => d.toJson(),
  );
});

/// Published exam-routine links (Google Sheets) by program. Fetched on demand.
final examRoutineProvider = FutureProvider<ExamRoutineData>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.getJson<ExamRoutineData>(
    '/student/exam-routine',
    (j) => ExamRoutineData.fromJson(j as Map<String, dynamic>),
  );
  return switch (res) {
    ApiOk(:final data) => data,
    ApiUnauthorized() => throw Exception('Session ended. Please log in again.'),
    ApiSessionExpired() => throw Exception('UCAM session expired.'),
    ApiUnavailable(:final message) => throw Exception(message),
  };
});

/// Public academic calendar (scraped from UIU, cached server-side). Read-only
/// and not per-student, so a plain FutureProvider is fine.
final academicCalendarProvider =
    FutureProvider<AcademicCalendarData>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.getJson<AcademicCalendarData>(
    '/calendar/academic',
    (j) => AcademicCalendarData.fromJson(j as Map<String, dynamic>),
  );
  return switch (res) {
    ApiOk(:final data) => data,
    ApiUnavailable(:final message) => throw Exception(message),
    _ => const AcademicCalendarData(calendars: []),
  };
});

/// Available trimesters for the item-wise marks picker.
final markTrimestersProvider =
    FutureProvider<List<TrimesterOption>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.getJson<List<TrimesterOption>>(
    '/student/marks/trimesters',
    (j) => (j as List)
        .whereType<Map>()
        .map((e) => TrimesterOption.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
  return switch (res) {
    ApiOk(:final data) => data,
    _ => <TrimesterOption>[],
  };
});

/// Public UIU notices, one page at a time (cached server-side). Keyed by page.
/// keepAlive so paging back and forth (Newer/Older) doesn't re-scrape a page the
/// user already loaded this session — the default autoDispose would drop each
/// page the moment it's off-screen and re-fetch on return.
final uiuNoticesProvider =
    FutureProvider.family<UiuNoticesData, int>((ref, page) async {
  ref.keepAlive();
  final api = ref.read(apiClientProvider);
  final res = await api.getJson<UiuNoticesData>(
    '/calendar/notices/uiu?page=$page',
    (j) => UiuNoticesData.fromJson(j as Map<String, dynamic>),
  );
  return switch (res) {
    ApiOk(:final data) => data,
    ApiUnavailable(:final message) => throw Exception(message),
    _ => const UiuNoticesData(),
  };
});

/// The COURSE LIST for a trimester (no marks yet), so the app can show courses
/// immediately and fetch each one's marks on demand. Keyed by trimester value.
final markCoursesProvider =
    FutureProvider.family<List<TrimesterOption>, String>((ref, trimester) async {
  // keepAlive: the marks cascade is N+1 UCAM postbacks; toggling between two
  // trimesters shouldn't re-walk a course list already fetched this session.
  ref.keepAlive();
  final api = ref.read(apiClientProvider);
  final res = await api.getJson<List<TrimesterOption>>(
    '/student/marks/courses?trimester=${Uri.encodeQueryComponent(trimester)}',
    (j) => (j as List)
        .whereType<Map>()
        .map((e) => TrimesterOption.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
  return switch (res) {
    ApiOk(:final data) => data,
    ApiUnauthorized() => throw Exception('Session ended. Please log in again.'),
    ApiSessionExpired() => throw Exception('UCAM session expired.'),
    ApiUnavailable(:final message) => throw Exception(message),
  };
});

/// ONE course's marks. Keyed by (trimester, course) so each course loads (and
/// pops in) independently. Null data = course has no marks entered yet.
typedef MarkCourseKey = ({String trimester, String course});

final markCourseProvider =
    FutureProvider.family<CourseMarks?, MarkCourseKey>((ref, key) async {
  // keepAlive: each course's marks are an expensive postback; re-opening a
  // course (or trimester) already fetched this session should be instant.
  ref.keepAlive();
  final api = ref.read(apiClientProvider);
  final res = await api.getJson<CourseMarks?>(
    '/student/marks/course?trimester=${Uri.encodeQueryComponent(key.trimester)}'
    '&course=${Uri.encodeQueryComponent(key.course)}',
    (j) => j == null ? null : CourseMarks.fromJson(j as Map<String, dynamic>),
  );
  return switch (res) {
    ApiOk(:final data) => data,
    ApiUnauthorized() => throw Exception('Session ended. Please log in again.'),
    ApiSessionExpired() => throw Exception('UCAM session expired.'),
    ApiUnavailable(:final message) => throw Exception(message),
  };
});

/// The student's profile photo bytes, proxied (with auth) through our backend.
/// Null while loading or if unavailable — the UI shows a person icon instead.
///
/// Watches ONLY whether a photo exists (via select on photoUrl), not the whole
/// home state — otherwise every home refresh (cached→live, pull-to-refresh) would
/// re-run this and re-fetch the image, making the avatar flicker/reload.
final avatarProvider = FutureProvider<List<int>?>((ref) async {
  final hasPhoto = ref.watch(homeProvider.select((s) =>
      s is ResData<HomeSummary> && s.loaded.data.photoUrl != null));
  if (!hasPhoto) return null;
  return ref.read(apiClientProvider).getBytes('/student/avatar');
});

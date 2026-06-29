import 'package:dio/dio.dart';

import 'api_config.dart';

/// Result of an authenticated data call, distinguishing the states the UI cares
/// about: success, session-expired (show re-login prompt), and upstream failure.
sealed class ApiResult<T> {
  const ApiResult();
}

class ApiOk<T> extends ApiResult<T> {
  final T data;
  const ApiOk(this.data);
}

/// 401 — our token is invalid/expired. Hard re-login.
class ApiUnauthorized<T> extends ApiResult<T> {
  const ApiUnauthorized();
}

/// 409 — the UCAM session expired upstream. Soft "tap to re-login" prompt;
/// the app can keep showing its on-device cached view.
class ApiSessionExpired<T> extends ApiResult<T> {
  const ApiSessionExpired();
}

/// 502 / network — couldn't reach the portal. Show cached view if available.
class ApiUnavailable<T> extends ApiResult<T> {
  final String message;
  const ApiUnavailable(this.message);
}

/// Liveness of the backend, as reported by [ApiClient.healthCheck].
enum ServerState { online, waking, offline }

class ServerStatus {
  final ServerState state;
  final int? latencyMs;
  const ServerStatus(this.state, {this.latencyMs});
}

/// Thin wrapper over dio. Injects the bearer token; maps status codes to
/// ApiResult so screens never deal with raw HTTP.
class ApiClient {
  ApiClient({String? Function()? tokenProvider})
      : _tokenProvider = tokenProvider,
        _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          // A free-tier backend (e.g. Render) can be asleep and take 30–50s to
          // wake on the first request. Generous timeouts so a cold start reads
          // as "waking up", not "unreachable".
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          // We handle non-2xx ourselves rather than throwing.
          validateStatus: (_) => true,
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  final Dio _dio;
  final String? Function()? _tokenProvider;

  /// Fire-and-forget warm-up. Pings /health so a sleeping free-tier backend
  /// starts waking while the user is still typing credentials. Never throws.
  Future<void> warmUp() async {
    try {
      await _dio.get('/health',
          options: Options(receiveTimeout: const Duration(seconds: 60)));
    } catch (_) {/* best effort */}
  }

  /// Pings /health and reports the server status with round-trip latency.
  /// Distinguishes "online", "waking" (slow first response on a free tier),
  /// and "offline". Used by the About page's status indicator.
  Future<ServerStatus> healthCheck() async {
    final sw = Stopwatch()..start();
    try {
      final r = await _dio.get('/health',
          options: Options(
            receiveTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 8),
          ));
      sw.stop();
      if (r.statusCode == 200) {
        // A slow first response usually means it just woke from sleep.
        final state = sw.elapsedMilliseconds > 3000
            ? ServerState.waking
            : ServerState.online;
        return ServerStatus(state, latencyMs: sw.elapsedMilliseconds);
      }
      return const ServerStatus(ServerState.offline);
    } on DioException catch (e) {
      sw.stop();
      // A timeout on the first hit is most likely a cold start, not a true down.
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const ServerStatus(ServerState.waking);
      }
      return const ServerStatus(ServerState.offline);
    } catch (_) {
      return const ServerStatus(ServerState.offline);
    }
  }

  /// POST /auth/login — returns the token on success. Retries once on a pure
  /// connection failure (the first request often just wakes a sleeping backend).
  Future<ApiResult<({String token, String roll})>> login(
      String studentId, String password) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await _dio.post('/auth/login', data: {
          'student_id': studentId,
          'password': password,
        });
        if (r.statusCode == 200) {
          final d = r.data;
          // Defensive: a 200 with an unexpected body shouldn't crash login.
          if (d is Map && d['token'] is String && d['roll'] is String) {
            return ApiOk(
                (token: d['token'] as String, roll: d['roll'] as String));
          }
          return const ApiUnavailable('Unexpected response from the server.');
        }
        if (r.statusCode == 401) return const ApiUnauthorized();
        return ApiUnavailable(_detail(r) ?? 'Login failed.');
      } on DioException catch (e) {
        final coldStart = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        // Retry once on a cold-start-shaped failure; otherwise report.
        if (coldStart && attempt == 0) continue;
        return ApiUnavailable(_dioMessage(e));
      }
    }
    return const ApiUnavailable('Network error. Please try again.');
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {/* best effort */}
  }

  /// Generic authenticated GET that maps status codes to ApiResult.
  Future<ApiResult<T>> getJson<T>(
      String path, T Function(dynamic json) parse) async {
    try {
      final r = await _dio.get(path);
      switch (r.statusCode) {
        case 200:
          try {
            return ApiOk(parse(r.data));
          } catch (e) {
            // Parsing failed (unexpected JSON shape) — surface it instead of
            // hanging the UI on a skeleton forever.
            return ApiUnavailable('Couldn\'t read the data: $e');
          }
        case 401:
          return const ApiUnauthorized();
        case 409:
          return const ApiSessionExpired();
        default:
          return ApiUnavailable(_detail(r) ?? 'Service unavailable.');
      }
    } on DioException catch (e) {
      return ApiUnavailable(_dioMessage(e));
    } catch (e) {
      return ApiUnavailable('Unexpected error: $e');
    }
  }

  /// Authenticated GET returning raw bytes (e.g. the avatar image proxy).
  /// Returns null on any non-200 so callers can fall back to a placeholder.
  Future<List<int>?> getBytes(String path) async {
    try {
      final r = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      // Treat an empty body as "no image" so the avatar falls back to the
      // placeholder icon instead of trying to decode 0 bytes (broken-image box).
      if (r.statusCode == 200 && r.data != null && r.data!.isNotEmpty) {
        return r.data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _detail(Response r) {
    final d = r.data;
    if (d is Map && d['detail'] is String) return d['detail'] as String;
    return null;
  }

  String _dioMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        // Most often a free-tier backend still waking from sleep.
        return 'The server is waking up — this can take up to a minute on the '
            'free tier. Please try again in a moment.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the Open Campus server. Check your connection and '
            'try again.';
      default:
        return 'Network error. Please try again.';
    }
  }
}

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

/// Thin wrapper over dio. Injects the bearer token; maps status codes to
/// ApiResult so screens never deal with raw HTTP.
class ApiClient {
  ApiClient({String? Function()? tokenProvider})
      : _tokenProvider = tokenProvider,
        _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 40),
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

  /// POST /auth/login — returns the token on success.
  Future<ApiResult<({String token, String roll})>> login(
      String studentId, String password) async {
    try {
      final r = await _dio.post('/auth/login', data: {
        'student_id': studentId,
        'password': password,
      });
      if (r.statusCode == 200) {
        final d = r.data as Map;
        return ApiOk((token: d['token'] as String, roll: d['roll'] as String));
      }
      if (r.statusCode == 401) return const ApiUnauthorized();
      return ApiUnavailable(_detail(r) ?? 'Login failed.');
    } on DioException catch (e) {
      return ApiUnavailable(_dioMessage(e));
    }
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
      if (r.statusCode == 200 && r.data != null) return r.data;
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
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the Open Campus server. Is the backend running?';
    }
    return 'Network error. Please try again.';
  }
}

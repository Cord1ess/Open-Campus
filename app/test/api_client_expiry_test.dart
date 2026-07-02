import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/core/api/api_client.dart';

/// A fake dio transport that returns a scripted sequence of HTTP status codes,
/// one per request, so we can drive the 409 retry-confirmation logic.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<int> statuses;
  int calls = 0;
  _ScriptedAdapter(this.statuses);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final code = statuses[calls.clamp(0, statuses.length - 1)];
    calls++;
    final body = code == 200 ? '{"ok": true}' : '{"detail": "x"}';
    return ResponseBody.fromString(
      body,
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient 409 retry-confirmation', () {
    test('a SINGLE transient 409 then 200 self-heals: no expiry, returns data',
        () async {
      var expiredFired = 0;
      final client = ApiClient(
        tokenProvider: () => 'tok',
        onSessionExpired: () => expiredFired++,
        adapter: _ScriptedAdapter([409, 200]), // blip, then success
      );
      final res =
          await client.getJson<Map>('/student/home', (j) => j as Map);
      expect(res, isA<ApiOk<Map>>());
      expect(expiredFired, 0, reason: 'transient 409 must NOT fire expiry');
    });

    test('TWO consecutive 409s = genuine expiry: fires callback once', () async {
      var expiredFired = 0;
      final client = ApiClient(
        tokenProvider: () => 'tok',
        onSessionExpired: () => expiredFired++,
        adapter: _ScriptedAdapter([409, 409]),
      );
      final res =
          await client.getJson<Map>('/student/home', (j) => j as Map);
      expect(res, isA<ApiSessionExpired<Map>>());
      expect(expiredFired, 1, reason: 'confirmed expiry fires exactly once');
    });

    test('a plain 200 never fires expiry', () async {
      var expiredFired = 0;
      final client = ApiClient(
        tokenProvider: () => 'tok',
        onSessionExpired: () => expiredFired++,
        adapter: _ScriptedAdapter([200]),
      );
      final res =
          await client.getJson<Map>('/student/home', (j) => j as Map);
      expect(res, isA<ApiOk<Map>>());
      expect(expiredFired, 0);
    });

    test('401 is unauthorized (hard), not a session-expiry retry', () async {
      var expiredFired = 0;
      final client = ApiClient(
        tokenProvider: () => 'tok',
        onSessionExpired: () => expiredFired++,
        adapter: _ScriptedAdapter([401]),
      );
      final res =
          await client.getJson<Map>('/student/home', (j) => j as Map);
      expect(res, isA<ApiUnauthorized<Map>>());
      expect(expiredFired, 0);
    });
  });
}

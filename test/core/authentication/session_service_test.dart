import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/authentication/http_session_service.dart';
import 'package:vendingapp/core/authentication/session_exception.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/storage/local_storage.dart';
import 'package:vendingapp/core/storage/secure_storage.dart';
import 'package:vendingapp/core/time/clock.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeClock clock;
  late MemorySecureStorage secureStorage;
  late MemoryLocalStorage localStorage;
  late RecordingAppLogger logger;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    secureStorage = MemorySecureStorage();
    localStorage = MemoryLocalStorage();
    logger = RecordingAppLogger();
  });

  HttpSessionService buildService(http.Client httpClient) {
    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-1'),
      httpClient: httpClient,
    );
    return HttpSessionService(
      apiClient: apiClient,
      secureStorage: secureStorage,
      logger: logger,
      clock: clock,
    );
  }

  test('createSession posts id_token + tenant_id and persists JWT', () async {
    late http.Request captured;
    final service = buildService(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'access_token': 'session-jwt-abc',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final session = await service.createSession(
      googleResult: fakeGoogleResult(idToken: 'fake-google-id-token'),
      tenantId: 'tenant-a',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/auth/session');
    expect(jsonDecode(captured.body), {
      'id_token': 'fake-google-id-token',
      'tenant_id': 'tenant-a',
    });
    expect(session.accessToken, 'session-jwt-abc');
    expect(session.tokenType, 'Bearer');
    expect(session.expiresIn, 3600);
    expect(service.hasValidSession, isTrue);

    final persisted = await secureStorage.read(
      HttpSessionService.defaultStorageKey,
    );
    expect(persisted, isNotNull);
    expect(persisted!.contains('session-jwt-abc'), isTrue);
    expect(
      await localStorage.read(HttpSessionService.defaultStorageKey),
      isNull,
    );
    expect(logger.hasSensitiveLeak, isFalse);
  });

  test('401 maps to SessionAuthenticationFailed', () async {
    final service = buildService(
      MockClient((request) async => http.Response('{"detail":"no"}', 401)),
    );

    expect(
      () => service.createSession(
        googleResult: fakeGoogleResult(),
        tenantId: 'tenant-a',
      ),
      throwsA(isA<SessionAuthenticationFailed>()),
    );
  });

  test('403 maps to SessionAccessDenied', () async {
    final service = buildService(
      MockClient(
        (request) async => http.Response('{"detail":"forbidden"}', 403),
      ),
    );

    expect(
      () => service.createSession(
        googleResult: fakeGoogleResult(),
        tenantId: 'tenant-a',
      ),
      throwsA(isA<SessionAccessDenied>()),
    );
  });

  test('restoreSession loads valid persisted session', () async {
    final service = buildService(
      MockClient((request) async => http.Response('{}', 500)),
    );
    final issued = fakeSession(
      accessToken: 'restored-token',
      issuedAt: clock.now(),
    );
    await secureStorage.write(
      HttpSessionService.defaultStorageKey,
      jsonEncode(issued.toJson()),
    );

    final restored = await service.restoreSession();

    expect(restored?.accessToken, 'restored-token');
    expect(service.hasValidSession, isTrue);
  });

  test('restoreSession clears expired session', () async {
    final service = buildService(
      MockClient((request) async => http.Response('{}', 500)),
    );
    final expired = fakeSession(
      accessToken: 'old-token',
      expiresAt: clock.now().subtract(const Duration(seconds: 1)),
      expiresIn: 1,
    );
    await secureStorage.write(
      HttpSessionService.defaultStorageKey,
      jsonEncode(expired.toJson()),
    );

    final restored = await service.restoreSession();

    expect(restored, isNull);
    expect(
      await secureStorage.read(HttpSessionService.defaultStorageKey),
      isNull,
    );
  });

  test('clearSession removes secure storage entry', () async {
    final service = buildService(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': 'to-clear',
            'token_type': 'Bearer',
            'expires_in': 60,
          }),
          200,
        );
      }),
    );
    await service.createSession(
      googleResult: fakeGoogleResult(),
      tenantId: 'tenant-a',
    );
    await service.clearSession();

    expect(service.currentSession, isNull);
    expect(
      await secureStorage.read(HttpSessionService.defaultStorageKey),
      isNull,
    );
  });

  test('expiration boundary: valid before, expired at expiresAt', () async {
    final service = buildService(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': 'boundary-token',
            'token_type': 'Bearer',
            'expires_in': 10,
          }),
          200,
        );
      }),
    );
    await service.createSession(
      googleResult: fakeGoogleResult(),
      tenantId: 'tenant-a',
    );

    clock.advance(const Duration(seconds: 9));
    expect(service.hasValidSession, isTrue);

    clock.advance(const Duration(seconds: 1));
    expect(service.hasValidSession, isFalse);
    expect(service.currentSession, isNull);
  });
}

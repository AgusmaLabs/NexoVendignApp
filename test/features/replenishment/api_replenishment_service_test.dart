import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/replenishment/data/api_replenishment_service.dart';
import 'package:vendingapp/features/replenishment/domain/replenishment_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  late RecordingAppLogger logger;
  late FakeClock clock;
  late FakeSessionService sessions;

  setUp(() {
    logger = RecordingAppLogger();
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    sessions = FakeSessionService(
      clock: clock,
      session: fakeSession(issuedAt: clock.now()),
    );
  });

  ApiReplenishmentService build(http.Client httpClient) {
    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-r'),
      credentialProvider: sessions,
      httpClient: httpClient,
    );
    return ApiReplenishmentService(apiClient: apiClient, logger: logger);
  }

  Map<String, Object?> replenishmentJson({
    String id = 'rep-1',
    String machineId = '11111111-1111-1111-1111-111111111111',
  }) => {
    'id': id,
    'machine_id': machineId,
    'operator_id': 'op-1',
    'status': 'IN_PROGRESS',
    'machine_type': 'SNACK',
    'started_at': '2026-09-15T12:00:00+00:00',
    'completed_at': null,
    'location': {
      'latitude': -35.4264,
      'longitude': -71.6554,
      'accuracy': 12.4,
    },
    'idempotency_key': 'idem-abc',
    'version': 1,
    'lines': <Object>[],
  };

  const location = DeviceLocation(
    latitude: -35.4264,
    longitude: -71.6554,
    accuracyMeters: 12.4,
  );

  test('POST /replenishments with Bearer, location, Idempotency-Key', () async {
    late http.Request captured;
    final service = build(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(replenishmentJson()),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final replenishment = await service.createReplenishment(
      machineId: '11111111-1111-1111-1111-111111111111',
      location: location,
      idempotencyKey: 'idem-abc',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/replenishments');
    expect(captured.headers['authorization'], 'Bearer test-session-token');
    expect(captured.headers['idempotency-key'], 'idem-abc');
    expect(captured.headers['x-request-id'], 'req-r');
    expect(captured.body.contains('fake-google-id-token'), isFalse);
    expect(captured.body.contains('operator_id'), isFalse);
    expect(captured.body.contains('tenant_id'), isFalse);

    final body = jsonDecode(captured.body) as Map<String, Object?>;
    expect(body['machine_id'], '11111111-1111-1111-1111-111111111111');
    final loc = body['location'] as Map<String, Object?>;
    expect(loc['latitude'], -35.4264);
    expect(loc['longitude'], -71.6554);
    expect(loc['accuracy'], 12.4);

    expect(replenishment.id, 'rep-1');
    expect(replenishment.status, 'IN_PROGRESS');
    expect(replenishment.lines, isEmpty);
    expect(logger.hasSensitiveLeak, isFalse);
  });

  test('empty machine id rejects without HTTP', () async {
    var calls = 0;
    final service = build(
      MockClient((request) async {
        calls += 1;
        return http.Response('{}', 201);
      }),
    );

    expect(
      () => service.createReplenishment(
        machineId: '  ',
        location: location,
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentMachineInvalid>()),
    );
    expect(calls, 0);
  });

  test('401 maps to ReplenishmentSessionExpired', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 401)),
    );
    expect(
      () => service.createReplenishment(
        machineId: 'm-1',
        location: location,
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentSessionExpired>()),
    );
  });

  test('403 maps to ReplenishmentAccessDenied', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 403)),
    );
    expect(
      () => service.createReplenishment(
        machineId: 'm-1',
        location: location,
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentAccessDenied>()),
    );
  });

  test('404 maps to ReplenishmentMachineUnavailable', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 404)),
    );
    expect(
      () => service.createReplenishment(
        machineId: 'm-1',
        location: location,
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentMachineUnavailable>()),
    );
  });

  test('409 maps to ReplenishmentConflict', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 409)),
    );
    expect(
      () => service.createReplenishment(
        machineId: 'm-1',
        location: location,
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentConflict>()),
    );
  });

  test('422 maps to ReplenishmentValidationFailed', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 422)),
    );
    expect(
      () => service.createReplenishment(
        machineId: 'm-1',
        location: location,
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentValidationFailed>()),
    );
  });

  test('5xx maps to ReplenishmentUnknownError', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 503)),
    );
    expect(
      () => service.createReplenishment(
        machineId: 'm-1',
        location: location,
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentUnknownError>()),
    );
  });

  test('timeout maps to ReplenishmentNetworkFailure', () async {
    final service = build(
      MockClient((request) async {
        throw TimeoutException('slow');
      }),
    );
    expect(
      () => service.createReplenishment(
        machineId: 'm-1',
        location: location,
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentNetworkFailure>()),
    );
  });

  test('does not call inventory endpoints', () async {
    final paths = <String>[];
    final service = build(
      MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode(replenishmentJson()), 201);
      }),
    );

    await service.createReplenishment(
      machineId: 'm-1',
      location: location,
      idempotencyKey: 'k',
    );

    expect(paths, ['/api/v1/replenishments']);
    expect(paths.any((p) => p.contains('inventory')), isFalse);
  });
}

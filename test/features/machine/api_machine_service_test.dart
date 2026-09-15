import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/data/api_machine_service.dart';
import 'package:vendingapp/features/machine/domain/machine.dart';
import 'package:vendingapp/features/machine/domain/machine_exception.dart';

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

  ApiMachineService build(http.Client httpClient) {
    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-m'),
      credentialProvider: sessions,
      httpClient: httpClient,
    );
    return ApiMachineService(apiClient: apiClient, logger: logger);
  }

  Map<String, Object?> machineJson() => {
    'machine_id': '11111111-1111-1111-1111-111111111111',
    'identifier': 'MIX-001',
    'machine_type': 'SNACK',
    'name': 'Lobby',
    'status': 'ACTIVE',
    'slots': <Object>[],
  };

  test('GET /machines/resolve with QR_CODE and Bearer', () async {
    late http.Request captured;
    final service = build(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(machineJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final machine = await service.resolveMachine('MIX-001');

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/machines/resolve');
    expect(captured.url.queryParameters['identifier_type'], 'QR_CODE');
    expect(captured.url.queryParameters['value'], 'MIX-001');
    expect(captured.headers['authorization'], 'Bearer test-session-token');
    expect(captured.body.contains('fake-google-id-token'), isFalse);
    expect(machine.identifier, 'MIX-001');
    expect(machine.name, 'Lobby');
    expect(logger.hasSensitiveLeak, isFalse);
  });

  test('UUID value uses INTERNAL_ID', () async {
    late http.Request captured;
    final service = build(
      MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(machineJson()), 200);
      }),
    );

    await service.resolveMachine('11111111-1111-1111-1111-111111111111');

    expect(captured.url.queryParameters['identifier_type'], 'INTERNAL_ID');
  });

  test('empty identifier rejects without HTTP', () async {
    var calls = 0;
    final service = build(
      MockClient((request) async {
        calls += 1;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => service.resolveMachine('   '),
      throwsA(isA<MachineIdentifierInvalid>()),
    );
    expect(calls, 0);
  });

  test('401 maps to MachineSessionExpired', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 401)),
    );
    expect(
      () => service.resolveMachine('MIX-001'),
      throwsA(isA<MachineSessionExpired>()),
    );
  });

  test('403 maps to MachineAccessDenied', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 403)),
    );
    expect(
      () => service.resolveMachine('MIX-001'),
      throwsA(isA<MachineAccessDenied>()),
    );
  });

  test('404 maps to MachineNotFound', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 404)),
    );
    expect(
      () => service.resolveMachine('MIX-001'),
      throwsA(isA<MachineNotFound>()),
    );
  });

  test('422 maps to MachineValidationFailed', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 422)),
    );
    expect(
      () => service.resolveMachine('MIX-001'),
      throwsA(isA<MachineValidationFailed>()),
    );
  });

  test('detectIdentifierType distinguishes UUID vs code', () {
    expect(
      detectIdentifierType('11111111-1111-1111-1111-111111111111'),
      MachineIdentifierType.internalId,
    );
    expect(detectIdentifierType('MIX-001'), MachineIdentifierType.qrCode);
  });
}

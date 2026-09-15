import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/data/api_machine_detail_service.dart';
import 'package:vendingapp/features/machine/data/api_machine_slot_service.dart';
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

  ApiMachineDetailService detailService(http.Client httpClient) {
    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-d'),
      credentialProvider: sessions,
      httpClient: httpClient,
    );
    return ApiMachineDetailService(apiClient: apiClient, logger: logger);
  }

  ApiMachineSlotService slotService(http.Client httpClient) {
    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-s'),
      credentialProvider: sessions,
      httpClient: httpClient,
    );
    return ApiMachineSlotService(apiClient: apiClient, logger: logger);
  }

  Map<String, Object?> detailJson({
    String machineId = '11111111-1111-1111-1111-111111111111',
  }) => {
    'machine_id': machineId,
    'identifier': 'MIX-001',
    'machine_type': 'SNACK',
    'name': 'Lobby',
    'status': 'ACTIVE',
  };

  Map<String, Object?> slotsJson({
    String machineId = '11111111-1111-1111-1111-111111111111',
    List<Map<String, Object?>>? slots,
  }) => {
    'machine_id': machineId,
    'slots':
        slots ??
        [
          {
            'slot_id': 'slot-a',
            'slot_number': 1,
            'capacity': 10,
            'status': 'ACTIVE',
            'preferred_product_id': 'prod-1',
            'selling_price': '1500',
            'current_quantity': 4,
          },
          {
            'slot_id': 'slot-b',
            'slot_number': 2,
            'capacity': 8,
            'status': 'ACTIVE',
            'preferred_product_id': null,
            'selling_price': null,
            'current_quantity': null,
          },
        ],
  };

  group('ApiMachineDetailService', () {
    test('GET /machines/{id} with Bearer and request id', () async {
      late http.Request captured;
      final service = detailService(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(detailJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final detail = await service.getMachineDetail(
        '11111111-1111-1111-1111-111111111111',
      );

      expect(captured.method, 'GET');
      expect(
        captured.url.path,
        '/api/v1/machines/11111111-1111-1111-1111-111111111111',
      );
      expect(captured.headers['authorization'], 'Bearer test-session-token');
      expect(captured.headers['x-request-id'], 'req-d');
      expect(captured.body.contains('fake-google-id-token'), isFalse);
      expect(detail.identifier, 'MIX-001');
      expect(logger.hasSensitiveLeak, isFalse);
    });

    test('empty machine id rejects without HTTP', () async {
      var calls = 0;
      final service = detailService(
        MockClient((request) async {
          calls += 1;
          return http.Response('{}', 200);
        }),
      );

      expect(
        () => service.getMachineDetail('   '),
        throwsA(isA<MachineIdentifierInvalid>()),
      );
      expect(calls, 0);
    });

    test('401 maps to MachineSessionExpired', () async {
      final service = detailService(
        MockClient((request) async => http.Response('{}', 401)),
      );
      expect(
        () => service.getMachineDetail('m-1'),
        throwsA(isA<MachineSessionExpired>()),
      );
    });

    test('403 maps to MachineAccessDenied', () async {
      final service = detailService(
        MockClient((request) async => http.Response('{}', 403)),
      );
      expect(
        () => service.getMachineDetail('m-1'),
        throwsA(isA<MachineAccessDenied>()),
      );
    });

    test('404 maps to MachineNotFound', () async {
      final service = detailService(
        MockClient((request) async => http.Response('{}', 404)),
      );
      expect(
        () => service.getMachineDetail('m-1'),
        throwsA(isA<MachineNotFound>()),
      );
    });

    test('5xx maps to MachineUnknownError', () async {
      final service = detailService(
        MockClient((request) async => http.Response('{}', 503)),
      );
      expect(
        () => service.getMachineDetail('m-1'),
        throwsA(isA<MachineUnknownError>()),
      );
    });
  });

  group('ApiMachineSlotService', () {
    test('GET /machines/{id}/slots preserves order and optionals', () async {
      late http.Request captured;
      final service = slotService(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(slotsJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final slots = await service.getSlots(
        '11111111-1111-1111-1111-111111111111',
      );

      expect(captured.method, 'GET');
      expect(
        captured.url.path,
        '/api/v1/machines/11111111-1111-1111-1111-111111111111/slots',
      );
      expect(captured.headers['authorization'], 'Bearer test-session-token');
      expect(captured.body.contains('fake-google-id-token'), isFalse);
      expect(slots.map((s) => s.slotId), ['slot-a', 'slot-b']);
      expect(slots.first.preferredProductId, 'prod-1');
      expect(slots.last.preferredProductId, isNull);
      expect(logger.hasSensitiveLeak, isFalse);
    });

    test('empty slots list is success', () async {
      final service = slotService(
        MockClient(
          (request) async => http.Response(
            jsonEncode(slotsJson(slots: const [])),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final slots = await service.getSlots('m-1');
      expect(slots, isEmpty);
    });

    test('empty machine id rejects without HTTP', () async {
      var calls = 0;
      final service = slotService(
        MockClient((request) async {
          calls += 1;
          return http.Response('{}', 200);
        }),
      );

      expect(
        () => service.getSlots(''),
        throwsA(isA<MachineIdentifierInvalid>()),
      );
      expect(calls, 0);
    });

    test('401 maps to MachineSessionExpired', () async {
      final service = slotService(
        MockClient((request) async => http.Response('{}', 401)),
      );
      expect(
        () => service.getSlots('m-1'),
        throwsA(isA<MachineSessionExpired>()),
      );
    });

    test('403 maps to MachineAccessDenied', () async {
      final service = slotService(
        MockClient((request) async => http.Response('{}', 403)),
      );
      expect(
        () => service.getSlots('m-1'),
        throwsA(isA<MachineAccessDenied>()),
      );
    });

    test('404 maps to MachineNotFound', () async {
      final service = slotService(
        MockClient((request) async => http.Response('{}', 404)),
      );
      expect(
        () => service.getSlots('m-1'),
        throwsA(isA<MachineNotFound>()),
      );
    });

    test('timeout maps to MachineNetworkFailure', () async {
      final service = slotService(
        MockClient((request) async {
          throw TimeoutException('slow');
        }),
      );
      expect(
        () => service.getSlots('m-1'),
        throwsA(isA<MachineNetworkFailure>()),
      );
    });
  });
}

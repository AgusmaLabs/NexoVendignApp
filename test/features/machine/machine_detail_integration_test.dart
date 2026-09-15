import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_detail_controller.dart';
import 'package:vendingapp/features/machine/application/machine_detail_state.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/machine/data/api_machine_detail_service.dart';
import 'package:vendingapp/features/machine/data/api_machine_service.dart';
import 'package:vendingapp/features/machine/data/api_machine_slot_service.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/operator/data/api_operator_service.dart';

import '../../support/test_doubles.dart';

void main() {
  test('session → operator → machine → detail → slots HTTP flow', () async {
    final logger = RecordingAppLogger();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(
      clock: clock,
      session: fakeSession(issuedAt: clock.now()),
    );

    const machineId = '11111111-1111-1111-1111-111111111111';
    final paths = <String>[];

    final httpClient = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.headers['authorization'], 'Bearer test-session-token');
      expect(request.body.contains('fake-google-id-token'), isFalse);

      if (request.url.path == '/api/v1/operators/me') {
        return http.Response(
          jsonEncode({
            'operator_id': 'op-1',
            'tenant_id': 'tenant-a',
            'role': 'OPERATOR',
            'status': 'ACTIVE',
            'provider': 'google',
            'subject': 'sub-1',
            'display_name': 'Ana',
            'email': 'ana@example.com',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/machines/resolve') {
        return http.Response(
          jsonEncode({
            'machine_id': machineId,
            'identifier': 'MIX-001',
            'machine_type': 'SNACK',
            'name': 'Lobby',
            'status': 'ACTIVE',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/machines/$machineId') {
        return http.Response(
          jsonEncode({
            'machine_id': machineId,
            'identifier': 'MIX-001',
            'machine_type': 'SNACK',
            'name': 'Lobby',
            'status': 'ACTIVE',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/machines/$machineId/slots') {
        return http.Response(
          jsonEncode({
            'machine_id': machineId,
            'slots': [
              {
                'slot_id': 'slot-1',
                'slot_number': 1,
                'capacity': 10,
                'status': 'ACTIVE',
                'preferred_product_id': 'prod-1',
                'selling_price': '1500',
                'current_quantity': 2,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-flow'),
      credentialProvider: sessions,
      httpClient: httpClient,
    );

    final operatorController = OperatorBootstrapController(
      operatorService: ApiOperatorService(apiClient: apiClient, logger: logger),
      sessionService: sessions,
      logger: logger,
    );
    final identifyController = MachineIdentificationController(
      machineService: ApiMachineService(apiClient: apiClient, logger: logger),
      sessionService: sessions,
      logger: logger,
    );
    final detailController = MachineDetailController(
      detailService: ApiMachineDetailService(
        apiClient: apiClient,
        logger: logger,
      ),
      slotService: ApiMachineSlotService(apiClient: apiClient, logger: logger),
      sessionService: sessions,
      logger: logger,
    );

    await operatorController.load();
    expect(operatorController.currentOperator?.displayName, 'Ana');

    await identifyController.identify('MIX-001');
    expect(identifyController.currentMachine?.machineId, machineId);

    await detailController.load(machineId);
    expect(detailController.state, isA<MachineDetailLoaded>());
    expect(detailController.currentDetail?.machineId, machineId);
    expect(detailController.currentSlots.single.slotId, 'slot-1');

    expect(paths, contains('/api/v1/operators/me'));
    expect(paths, contains('/api/v1/machines/resolve'));
    expect(paths, contains('/api/v1/machines/$machineId'));
    expect(paths, contains('/api/v1/machines/$machineId/slots'));
    expect(logger.hasSensitiveLeak, isFalse);
  });
}

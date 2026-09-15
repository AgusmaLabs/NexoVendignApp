import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_detail_controller.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/machine/data/api_machine_detail_service.dart';
import 'package:vendingapp/features/machine/data/api_machine_service.dart';
import 'package:vendingapp/features/machine/data/api_machine_slot_service.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/operator/data/api_operator_service.dart';
import 'package:vendingapp/features/products/application/product_lookup_controller.dart';
import 'package:vendingapp/features/products/data/api_product_lookup_service.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_add_line_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_add_line_state.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';
import 'package:vendingapp/features/replenishment/data/api_replenishment_line_service.dart';
import 'package:vendingapp/features/replenishment/data/api_replenishment_service.dart';

import '../../support/test_doubles.dart';

void main() {
  test(
    'session → machine → slots → replenishment → product → add line',
    () async {
      final logger = RecordingAppLogger();
      final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
      final sessions = FakeSessionService(
        clock: clock,
        session: fakeSession(issuedAt: clock.now()),
      );
      const machineId = '11111111-1111-1111-1111-111111111111';
      final paths = <String>[];
      final lineBodies = <String>[];

      final httpClient = MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['authorization'], 'Bearer test-session-token');
        expect(request.body.contains('fake-google-id-token'), isFalse);

        if (request.url.path == '/api/v1/operators/me') {
          return http.Response(
            jsonEncode({
              'operator_id': 'op-1',
              'tenant_id': 'tenant-a',
              'role': 'replenisher',
              'status': 'active',
              'provider': 'google',
              'subject': 'sub-1',
              'display_name': 'Ana',
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
              'location_label': 'Floor 1',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/machines/$machineId/slots') {
          return http.Response(
            jsonEncode({
              'slots': [
                {
                  'slot_id': 'slot-A01',
                  'slot_number': 1,
                  'capacity': 20,
                  'status': 'ACTIVE',
                  'preferred_product_id': 'prod-other',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/replenishments') {
          return http.Response(
            jsonEncode({
              'id': 'rep-1',
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
              'idempotency_key': 'idem',
              'version': 1,
              'lines': <Object>[],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/products/barcode/7801234567890') {
          return http.Response(
            jsonEncode({
              'product_id': 'prod-1',
              'barcode': '7801234567890',
              'name': 'Coca Cola 350 ml',
              'status': 'ACTIVE',
              'unit': 'CAN',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/replenishments/rep-1/lines') {
          lineBodies.add(request.body);
          expect(request.headers['idempotency-key'], isNotEmpty);
          return http.Response(
            jsonEncode({
              'id': 'rep-1',
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
              'idempotency_key': 'idem',
              'version': 2,
              'lines': [
                {
                  'id': 'line-1',
                  'slot_id': 'slot-A01',
                  'product_id': 'prod-1',
                  'quantity': 12,
                  'unit_price': '1500.00',
                  'occurred_at': '2026-09-15T12:05:00+00:00',
                  'product_description_snapshot': 'Coca Cola 350 ml',
                  'resolution_status': 'RESOLVED',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        fail('Unexpected path ${request.url.path}');
      });

      final apiClient = HttpApiClient(
        config: testConfig(apiBaseUrl: 'http://vending.test'),
        logger: logger,
        requestIdGenerator: SequenceRequestIdGenerator([
          'req-1',
          'req-2',
          'req-3',
          'req-4',
          'req-5',
          'req-6',
          'req-7',
        ]),
        credentialProvider: sessions,
        httpClient: httpClient,
      );

      final operatorController = OperatorBootstrapController(
        operatorService: ApiOperatorService(
          apiClient: apiClient,
          logger: logger,
        ),
        sessionService: sessions,
        logger: logger,
      );
      final machineController = MachineIdentificationController(
        machineService: ApiMachineService(apiClient: apiClient, logger: logger),
        sessionService: sessions,
        logger: logger,
      );
      final detailController = MachineDetailController(
        detailService: ApiMachineDetailService(
          apiClient: apiClient,
          logger: logger,
        ),
        slotService: ApiMachineSlotService(
          apiClient: apiClient,
          logger: logger,
        ),
        sessionService: sessions,
        logger: logger,
      );
      final creationController = ReplenishmentCreationController(
        replenishmentService: ApiReplenishmentService(
          apiClient: apiClient,
          logger: logger,
        ),
        machineIdentificationController: machineController,
        operatorBootstrapController: operatorController,
        locationService: const FixedLocationService(
          DeviceLocation(
            latitude: -35.4264,
            longitude: -71.6554,
            accuracyMeters: 12.4,
          ),
        ),
        sessionService: sessions,
        requestIdGenerator: FixedRequestIdGenerator('idem-create'),
        logger: logger,
      );
      final productController = ProductLookupController(
        productLookupService: ApiProductLookupService(
          apiClient: apiClient,
          logger: logger,
        ),
        barcodeScanner: FakeBarcodeScanner('7801234567890'),
        replenishmentCreationController: creationController,
        sessionService: sessions,
        logger: logger,
      );
      final addLineController = ReplenishmentAddLineController(
        lineService: ApiReplenishmentLineService(
          apiClient: apiClient,
          logger: logger,
        ),
        replenishmentCreationController: creationController,
        machineDetailController: detailController,
        sessionService: sessions,
        requestIdGenerator: FixedRequestIdGenerator('idem-line'),
        logger: logger,
      );

      await operatorController.load();
      await machineController.identify('MIX-001');
      await detailController.load(machineId);
      await creationController.start();
      await productController.lookup('7801234567890');

      final product = productController.lastFoundProduct!;
      addLineController.beginWithProduct(product, barcode: '7801234567890');
      addLineController.selectSlot('slot-A01');
      addLineController.setQuantity(12);
      await addLineController.submit();

      expect(addLineController.state, isA<ReplenishmentAddLineAdded>());
      expect(creationController.currentReplenishment?.id, 'rep-1');
      expect(creationController.currentReplenishment?.machineId, machineId);
      expect(creationController.currentReplenishment?.lines, hasLength(1));
      expect(
        creationController.currentReplenishment?.lines.single.productId,
        'prod-1',
      );

      final body = jsonDecode(lineBodies.single) as Map<String, Object?>;
      expect(body['product_id'], 'prod-1');
      expect(body['quantity'], 12);
      expect(body['slot_id'], 'slot-A01');
      expect(body.containsKey('tenant_id'), isFalse);

      // preferred_product_id on slot is not sent / not required to match.
      expect(body['product_id'], isNot('prod-other'));

      expect(paths, contains('/api/v1/replenishments/rep-1/lines'));
      expect(logger.hasSensitiveLeak, isFalse);
    },
  );

  test('line stays bound to its replenishment and machine', () async {
    final logger = RecordingAppLogger();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(clock: clock);
    final machines = FakeMachineService();
    final machineController = MachineIdentificationController(
      machineService: machines,
      sessionService: sessions,
      logger: logger,
    );
    final operatorController = OperatorBootstrapController(
      operatorService: FakeOperatorService(),
      sessionService: sessions,
      logger: logger,
    );
    final detailController = MachineDetailController(
      detailService: FakeMachineDetailService(),
      slotService: FakeMachineSlotService(
        slots: [fakeMachineSlot(slotId: 'slot-A01')],
      ),
      sessionService: sessions,
      logger: logger,
    );

    await operatorController.load();
    await machineController.identify('MIX-001');
    final machineId = machineController.currentMachine!.machineId;
    await detailController.load(machineId);

    final creationA = ReplenishmentCreationController(
      replenishmentService: FakeReplenishmentService(
        replenishment: fakeReplenishment(id: 'rep-a', machineId: machineId),
      ),
      machineIdentificationController: machineController,
      operatorBootstrapController: operatorController,
      locationService: const FixedLocationService(
        DeviceLocation(latitude: 1, longitude: 2),
      ),
      sessionService: sessions,
      requestIdGenerator: FixedRequestIdGenerator('a'),
      logger: logger,
    );
    final lines = FakeReplenishmentLineService();
    final addLine = ReplenishmentAddLineController(
      lineService: lines,
      replenishmentCreationController: creationA,
      machineDetailController: detailController,
      sessionService: sessions,
      requestIdGenerator: FixedRequestIdGenerator('line'),
      logger: logger,
    );

    await creationA.start();

    addLine.beginWithProduct(fakeProduct());
    addLine.selectSlot('slot-A01');
    addLine.setQuantity(3);
    await addLine.submit();

    expect(lines.replenishmentIds.single, 'rep-a');
    expect(creationA.currentReplenishment?.machineId, machineId);
    expect(creationA.currentReplenishment?.id, 'rep-a');
  });
}

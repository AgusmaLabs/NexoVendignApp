import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/machine/data/api_machine_service.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/operator/data/api_operator_service.dart';
import 'package:vendingapp/features/products/application/product_lookup_controller.dart';
import 'package:vendingapp/features/products/application/product_lookup_state.dart';
import 'package:vendingapp/features/products/data/api_product_lookup_service.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';
import 'package:vendingapp/features/replenishment/data/api_replenishment_service.dart';

import '../../support/test_doubles.dart';

void main() {
  test('session → replenishment → scan → product found', () async {
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
    final machineController = MachineIdentificationController(
      machineService: ApiMachineService(apiClient: apiClient, logger: logger),
      sessionService: sessions,
      logger: logger,
    );
    final replenishmentController = ReplenishmentCreationController(
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
      requestIdGenerator: FixedRequestIdGenerator('idem'),
      logger: logger,
    );
    final productController = ProductLookupController(
      productLookupService: ApiProductLookupService(
        apiClient: apiClient,
        logger: logger,
      ),
      barcodeScanner: FakeBarcodeScanner('7801234567890'),
      replenishmentCreationController: replenishmentController,
      sessionService: sessions,
      logger: logger,
    );

    await operatorController.load();
    await machineController.identify('MIX-001');
    await replenishmentController.start();
    expect(replenishmentController.currentReplenishment?.lines, isEmpty);

    await productController.scanAndLookup();

    expect(productController.state, isA<ProductLookupFound>());
    expect(productController.lastFoundProduct?.name, 'Coca Cola 350 ml');
    expect(replenishmentController.currentReplenishment?.lines, isEmpty);
    expect(paths, contains('/api/v1/products/barcode/7801234567890'));
    expect(paths.any((p) => p.contains('/lines')), isFalse);
    expect(logger.hasSensitiveLeak, isFalse);
  });
}

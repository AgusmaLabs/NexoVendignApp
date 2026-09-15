import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/products/application/product_lookup_controller.dart';
import 'package:vendingapp/features/products/application/product_lookup_state.dart';
import 'package:vendingapp/features/products/domain/product_exception.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeProductLookupService products;
  late FakeBarcodeScanner scanner;
  late FakeReplenishmentService replenishments;
  late ReplenishmentCreationController replenishmentController;
  late ProductLookupController controller;
  late RecordingAppLogger logger;

  setUp(() async {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(clock: clock);
    logger = RecordingAppLogger();
    products = FakeProductLookupService();
    scanner = FakeBarcodeScanner('7801234567890');
    replenishments = FakeReplenishmentService();

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
    replenishmentController = ReplenishmentCreationController(
      replenishmentService: replenishments,
      machineIdentificationController: machineController,
      operatorBootstrapController: operatorController,
      locationService: const FixedLocationService(
        DeviceLocation(latitude: 1, longitude: 2),
      ),
      sessionService: sessions,
      requestIdGenerator: FixedRequestIdGenerator('idem'),
      logger: logger,
    );
    controller = ProductLookupController(
      productLookupService: products,
      barcodeScanner: scanner,
      replenishmentCreationController: replenishmentController,
      sessionService: sessions,
      logger: logger,
    );

    await operatorController.load();
    await machineController.identify('MIX-001');
    await replenishmentController.start();
  });

  test('scan success starts lookup and finds product', () async {
    await controller.scanAndLookup();
    expect(controller.state, isA<ProductLookupFound>());
    expect(controller.lastFoundProduct?.barcode, '7801234567890');
    expect(scanner.callCount, 1);
    expect(products.callCount, 1);
  });

  test('scan cancelled does not lookup', () async {
    scanner.value = null;
    await controller.scanAndLookup();
    expect(controller.state, isA<ProductLookupIdle>());
    expect(products.callCount, 0);
  });

  test('manual lookup uses same service', () async {
    await controller.lookup('7809999999999');
    expect(products.barcodes.single, '7809999999999');
    expect(controller.state, isA<ProductLookupFound>());
  });

  test('404 becomes NotFound', () async {
    products.error = const ProductNotFound(barcode: '7800000');
    await controller.lookup('7800000111111');
    expect(controller.state, isA<ProductLookupNotFound>());
  });

  test('no replenishment blocks lookup', () async {
    await replenishmentController.clear();
    await controller.lookup('7801234567890');
    expect(controller.state, isA<ProductLookupNoReplenishment>());
    expect(products.callCount, 0);
  });

  test('double lookup while busy issues one request', () async {
    final gate = Completer<void>();
    products.pending = gate.future;

    final first = controller.lookup('7801234567890');
    await Future<void>.delayed(Duration.zero);
    final second = controller.lookup('7801234567890');
    await Future<void>.delayed(Duration.zero);

    expect(products.callCount, 1);
    gate.complete();
    await Future.wait([first, second]);
    expect(products.callCount, 1);
  });

  test('lookup does not mutate replenishment context', () async {
    final before = replenishmentController.currentReplenishment;
    await controller.lookup('7801234567890');
    expect(replenishmentController.currentReplenishment?.id, before?.id);
    expect(replenishments.callCount, 1); // only create from setUp
  });

  test('401 clears session', () async {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(
      clock: clock,
      session: fakeSession(issuedAt: clock.now()),
    );
    var expired = false;
    controller = ProductLookupController(
      productLookupService: products,
      barcodeScanner: scanner,
      replenishmentCreationController: replenishmentController,
      sessionService: sessions,
      logger: logger,
      onSessionExpired: () async {
        expired = true;
      },
    );
    products.error = const ProductSessionExpired();

    await controller.lookup('7801234567890');

    expect(controller.state, isA<ProductLookupSessionExpired>());
    expect(sessions.clearCallCount, greaterThan(0));
    expect(expired, isTrue);
  });
}

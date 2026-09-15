import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/products/application/product_lookup_controller.dart';
import 'package:vendingapp/features/products/domain/product_exception.dart';
import 'package:vendingapp/features/products/presentation/product_lookup_page.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeProductLookupService products;
  late FakeBarcodeScanner scanner;
  late ProductLookupController controller;

  setUp(() async {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(clock: clock);
    final logger = RecordingAppLogger();
    products = FakeProductLookupService(
      product: fakeProduct(name: 'Coca Cola 350 ml'),
    );
    scanner = FakeBarcodeScanner('7801234567890');

    final machineController = MachineIdentificationController(
      machineService: FakeMachineService(),
      sessionService: sessions,
      logger: logger,
    );
    final operatorController = OperatorBootstrapController(
      operatorService: FakeOperatorService(),
      sessionService: sessions,
      logger: logger,
    );
    final replenishmentController = ReplenishmentCreationController(
      replenishmentService: FakeReplenishmentService(),
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

  Widget wrap() {
    return MaterialApp(home: ProductLookupPage(controller: controller));
  }

  testWidgets('idle shows scan and manual entry', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Escanear'), findsOneWidget);
    expect(find.text('Código de barras'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });

  testWidgets('manual search shows found product', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), '7801234567890');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Producto encontrado'), findsOneWidget);
    expect(find.text('Coca Cola 350 ml'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('scan button looks up via scanner', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();

    expect(find.text('Producto encontrado'), findsOneWidget);
    expect(scanner.callCount, 1);
  });

  testWidgets('not found shows retry actions', (tester) async {
    products.error = const ProductNotFound(barcode: '7800000111111');
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), '7800000111111');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Producto no encontrado'), findsOneWidget);
    expect(find.text('Escanear nuevamente'), findsOneWidget);
    expect(find.text('Ingresar código'), findsOneWidget);
  });

  testWidgets('network failure shows retry', (tester) async {
    products.error = const ProductNetworkFailure();
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), '7801234567890');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(
      find.text('No fue posible consultar el producto en este momento.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

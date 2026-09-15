import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_detail_controller.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_add_line_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';
import 'package:vendingapp/features/replenishment/presentation/replenishment_add_line_page.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeReplenishmentLineService lines;
  late ReplenishmentAddLineController controller;
  late MachineDetailController detailController;

  setUp(() async {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(clock: clock);
    final logger = RecordingAppLogger();
    lines = FakeReplenishmentLineService();

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
    detailController = MachineDetailController(
      detailService: FakeMachineDetailService(),
      slotService: FakeMachineSlotService(
        slots: [
          fakeMachineSlot(slotId: 'slot-A01', slotNumber: 1),
          fakeMachineSlot(slotId: 'slot-A02', slotNumber: 2),
        ],
      ),
      sessionService: sessions,
      logger: logger,
    );
    final creationController = ReplenishmentCreationController(
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
    controller = ReplenishmentAddLineController(
      lineService: lines,
      replenishmentCreationController: creationController,
      machineDetailController: detailController,
      sessionService: sessions,
      requestIdGenerator: FixedRequestIdGenerator('line-idem'),
      logger: logger,
    );

    await operatorController.load();
    await machineController.identify('MIX-001');
    await detailController.load(machineController.currentMachine!.machineId);
    await creationController.start();
  });

  Widget wrap() {
    return MaterialApp(
      home: ReplenishmentAddLinePage(
        product: fakeProduct(name: 'Coca Cola 350 ml'),
        barcode: '7801234567890',
        controller: controller,
      ),
    );
  }

  testWidgets('shows product, quantity field and slots', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Coca Cola 350 ml'), findsOneWidget);
    expect(find.text('Cantidad'), findsOneWidget);
    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S2'), findsOneWidget);
    expect(find.text('Agregar'), findsOneWidget);
  });

  testWidgets('submit adds line and shows success', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('S1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Línea agregada'), findsOneWidget);
    expect(find.text('Cantidad: 12'), findsOneWidget);
    expect(lines.callCount, 1);
  });

  testWidgets('invalid quantity shows validation message', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('S1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(
      find.text('La cantidad debe ser un entero mayor que cero.'),
      findsOneWidget,
    );
    expect(lines.callCount, 0);
  });
}

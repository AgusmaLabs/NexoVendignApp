import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';
import 'package:vendingapp/features/replenishment/domain/replenishment_exception.dart';
import 'package:vendingapp/features/replenishment/presentation/replenishment_start_page.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeMachineService machines;
  late FakeOperatorService operators;
  late FakeReplenishmentService replenishments;
  late MachineIdentificationController machineController;
  late OperatorBootstrapController operatorController;
  late ReplenishmentCreationController controller;

  setUp(() async {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(clock: clock);
    machines = FakeMachineService();
    operators = FakeOperatorService();
    replenishments = FakeReplenishmentService();
    final logger = RecordingAppLogger();

    machineController = MachineIdentificationController(
      machineService: machines,
      sessionService: sessions,
      logger: logger,
    );
    operatorController = OperatorBootstrapController(
      operatorService: operators,
      sessionService: sessions,
      logger: logger,
    );
    controller = ReplenishmentCreationController(
      replenishmentService: replenishments,
      machineIdentificationController: machineController,
      operatorBootstrapController: operatorController,
      locationService: const FixedLocationService(
        DeviceLocation(latitude: -35.4, longitude: -71.6, accuracyMeters: 10),
      ),
      sessionService: sessions,
      requestIdGenerator: FixedRequestIdGenerator('idem-ui'),
      logger: logger,
    );

    await operatorController.load();
    await machineController.identify('MIX-001');
  });

  Widget wrap() {
    return MaterialApp(
      home: ReplenishmentStartPage(
        controller: controller,
        machine: machineController.currentMachine,
      ),
    );
  }

  testWidgets('initial shows machine and start button', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Lobby'), findsOneWidget);
    expect(find.text('MIX-001'), findsOneWidget);
    expect(find.text('Listo para reponer'), findsOneWidget);
    expect(find.text('Iniciar reposición'), findsOneWidget);
  });

  testWidgets('creating disables start and shows loading', (tester) async {
    final gate = Completer<void>();
    replenishments.pending = gate.future;

    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Iniciar reposición'));
    await tester.pump();

    expect(find.text('Creando reposición...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Iniciar reposición'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('success shows replenishment started', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Iniciar reposición'));
    await tester.pumpAndSettle();

    expect(find.text('Reposición iniciada'), findsOneWidget);
    expect(find.textContaining('IN_PROGRESS'), findsOneWidget);
    expect(find.text('Lista para agregar productos.'), findsOneWidget);
  });

  testWidgets('failure shows message and retry', (tester) async {
    replenishments.error = const ReplenishmentNetworkFailure();
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Iniciar reposición'));
    await tester.pumpAndSettle();

    expect(
      find.text('No fue posible iniciar la reposición en este momento.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);

    replenishments.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Reposición iniciada'), findsOneWidget);
  });

  testWidgets('403 shows access denied', (tester) async {
    replenishments.error = const ReplenishmentAccessDenied();
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Iniciar reposición'));
    await tester.pumpAndSettle();

    expect(
      find.text('No tienes permiso para reponer esta máquina.'),
      findsOneWidget,
    );
  });

  testWidgets('409 shows existing replenishment', (tester) async {
    replenishments.error = const ReplenishmentConflict();
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Iniciar reposición'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ya existe una reposición en curso para esta máquina.'),
      findsOneWidget,
    );
  });

  testWidgets('401 shows session expired', (tester) async {
    replenishments.error = const ReplenishmentSessionExpired();
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Iniciar reposición'));
    await tester.pumpAndSettle();

    expect(
      find.text('La sesión ha expirado. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });

  testWidgets('no machine blocks start', (tester) async {
    await machineController.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: ReplenishmentStartPage(
          controller: controller,
          machine: null,
        ),
      ),
    );

    expect(
      find.text('Identifica una máquina antes de iniciar la reposición.'),
      findsOneWidget,
    );
    expect(find.text('Iniciar reposición'), findsNothing);
  });
}

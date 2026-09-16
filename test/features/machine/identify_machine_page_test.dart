import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/networking/request_id.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_detail_controller.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/machine/domain/machine_exception.dart';
import 'package:vendingapp/features/machine/presentation/identify_machine_page.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_state.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';
import 'package:vendingapp/features/replenishment/application/visit_start_controller.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeMachineService machines;
  late FakeMachineDetailService details;
  late FakeMachineSlotService slots;
  late FakeReplenishmentService replenishments;
  late FakeOperatorService operators;
  late OperatorBootstrapController operatorBootstrap;
  late VisitStartController visitStart;

  setUp(() {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(
      clock: clock,
      session: fakeSession(issuedAt: clock.now()),
    );
    final logger = RecordingAppLogger();
    machines = FakeMachineService();
    details = FakeMachineDetailService();
    slots = FakeMachineSlotService();
    replenishments = FakeReplenishmentService();
    operators = FakeOperatorService();

    operatorBootstrap = OperatorBootstrapController(
      operatorService: operators,
      sessionService: sessions,
      logger: logger,
    );
    final machineIdentification = MachineIdentificationController(
      machineService: machines,
      sessionService: sessions,
      logger: logger,
    );
    final machineDetail = MachineDetailController(
      detailService: details,
      slotService: slots,
      sessionService: sessions,
      logger: logger,
    );
    final creation = ReplenishmentCreationController(
      replenishmentService: replenishments,
      machineIdentificationController: machineIdentification,
      operatorBootstrapController: operatorBootstrap,
      locationService: const FixedLocationService(
        DeviceLocation(
          latitude: -35.4264,
          longitude: -71.6554,
          accuracyMeters: 12.4,
        ),
      ),
      sessionService: sessions,
      requestIdGenerator: UuidRequestIdGenerator(),
      logger: logger,
    );
    visitStart = VisitStartController(
      machineIdentificationController: machineIdentification,
      machineDetailController: machineDetail,
      replenishmentCreationController: creation,
      operatorBootstrapController: operatorBootstrap,
      logger: logger,
    );
  });

  Future<void> loadOperator() async {
    await operatorBootstrap.load();
    expect(operatorBootstrap.state, isA<OperatorBootstrapLoaded>());
  }

  Widget wrap() {
    return MaterialApp(
      home: IdentifyMachinePage(controller: visitStart),
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('line-entry')),
        );
      },
    );
  }

  testWidgets('initial shows identifier field and start button', (tester) async {
    await loadOperator();
    await tester.pumpWidget(wrap());
    expect(find.text('Código / QR'), findsOneWidget);
    expect(find.text('Identificar e iniciar'), findsOneWidget);
  });

  testWidgets('empty input shows validation without HTTP', (tester) async {
    await loadOperator();
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Identificar e iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un identificador de máquina.'), findsOneWidget);
    expect(machines.callCount, 0);
  });

  testWidgets('success starts visit and navigates to line entry', (tester) async {
    await loadOperator();
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'MIX-001');
    await tester.tap(find.text('Identificar e iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('line-entry'), findsOneWidget);
    expect(replenishments.callCount, 1);
  });

  testWidgets('not found shows message and allows retry', (tester) async {
    await loadOperator();
    machines.error = const MachineNotFound();
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'MISSING');
    await tester.tap(find.text('Identificar e iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('Máquina no encontrada.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    machines.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('line-entry'), findsOneWidget);
  });

  testWidgets('403 shows access denied', (tester) async {
    await loadOperator();
    machines.error = const MachineAccessDenied();
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'MIX-001');
    await tester.tap(find.text('Identificar e iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('No tienes acceso a esta máquina.'), findsOneWidget);
  });

  testWidgets('loading shows phase text', (tester) async {
    await loadOperator();
    machines.delay = const Duration(milliseconds: 80);
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'MIX-001');
    await tester.tap(find.text('Identificar e iniciar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Identificando máquina...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });
}

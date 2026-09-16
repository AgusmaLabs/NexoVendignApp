import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/networking/request_id.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_detail_controller.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/machine/domain/machine_exception.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';
import 'package:vendingapp/features/replenishment/application/visit_start_controller.dart';
import 'package:vendingapp/features/replenishment/application/visit_start_state.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeMachineService machines;
  late FakeMachineDetailService details;
  late FakeMachineSlotService slots;
  late FakeReplenishmentService replenishments;
  late OperatorBootstrapController operatorBootstrap;
  late VisitStartController controller;

  setUp(() async {
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

    operatorBootstrap = OperatorBootstrapController(
      operatorService: FakeOperatorService(),
      sessionService: sessions,
      logger: logger,
    );
    await operatorBootstrap.load();

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
    controller = VisitStartController(
      machineIdentificationController: machineIdentification,
      machineDetailController: machineDetail,
      replenishmentCreationController: creation,
      operatorBootstrapController: operatorBootstrap,
      logger: logger,
    );
  });

  test('empty identifier is validation failure', () async {
    await controller.startFromIdentifier('  ');
    expect(controller.state, isA<VisitStartFailure>());
    final failure = controller.state as VisitStartFailure;
    expect(failure.isValidation, isTrue);
    expect(machines.callCount, 0);
  });

  test('happy path resolves machine, loads slots, creates visit', () async {
    await controller.startFromIdentifier('MIX-001');
    expect(controller.state, isA<VisitStartReady>());
    final ready = controller.state as VisitStartReady;
    expect(ready.machine.identifier, 'MIX-001');
    expect(ready.replenishment.machineId, ready.machine.machineId);
    expect(machines.callCount, 1);
    expect(details.callCount, 1);
    expect(slots.callCount, 1);
    expect(replenishments.callCount, 1);
  });

  test('machine not found stops before create', () async {
    machines.error = const MachineNotFound();
    await controller.startFromIdentifier('MISSING');
    expect(controller.state, isA<VisitStartFailure>());
    expect(replenishments.callCount, 0);
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_state.dart';
import 'package:vendingapp/features/replenishment/domain/replenishment_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeClock clock;
  late FakeSessionService sessions;
  late FakeMachineService machines;
  late FakeOperatorService operators;
  late FakeReplenishmentService replenishments;
  late RecordingAppLogger logger;
  late MachineIdentificationController machineController;
  late OperatorBootstrapController operatorController;
  late ReplenishmentCreationController controller;
  late SequenceRequestIdGenerator requestIds;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    sessions = FakeSessionService(clock: clock);
    machines = FakeMachineService();
    operators = FakeOperatorService();
    replenishments = FakeReplenishmentService();
    logger = RecordingAppLogger();
    requestIds = SequenceRequestIdGenerator(['key-1', 'key-2', 'key-3']);

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
        DeviceLocation(
          latitude: -35.4264,
          longitude: -71.6554,
          accuracyMeters: 12.4,
        ),
      ),
      sessionService: sessions,
      requestIdGenerator: requestIds,
      logger: logger,
    );

    await operatorController.load();
    await machineController.identify('MIX-001');
  });

  test('create success sets Current Replenishment', () async {
    final future = controller.start();
    expect(controller.state, isA<ReplenishmentCreationCreating>());
    await future;

    expect(controller.state, isA<ReplenishmentCreationCreated>());
    expect(controller.currentReplenishment?.status, 'IN_PROGRESS');
    expect(
      replenishments.machineIds.single,
      '11111111-1111-1111-1111-111111111111',
    );
    expect(replenishments.idempotencyKeys.single, 'key-1');
    expect(replenishments.lastLocation?.latitude, -35.4264);
  });

  test('no machine skips HTTP', () async {
    await machineController.clear();
    await controller.start();
    expect(controller.state, isA<ReplenishmentCreationNoMachine>());
    expect(replenishments.callCount, 0);
  });

  test('no operator skips HTTP', () async {
    await operatorController.clear();
    await controller.start();
    expect(controller.state, isA<ReplenishmentCreationNoOperator>());
    expect(replenishments.callCount, 0);
  });

  test('double tap while creating issues one POST', () async {
    final gate = Completer<void>();
    replenishments.pending = gate.future;

    final first = controller.start();
    await Future<void>.delayed(Duration.zero);
    final second = controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(replenishments.callCount, 1);
    gate.complete();
    await Future.wait([first, second]);
    expect(replenishments.callCount, 1);
  });

  test('retry reuses same idempotency key', () async {
    replenishments.error = const ReplenishmentNetworkFailure();
    await controller.start();
    expect(controller.state, isA<ReplenishmentCreationFailure>());
    expect(replenishments.idempotencyKeys, ['key-1']);

    replenishments.error = null;
    await controller.retry();
    expect(controller.state, isA<ReplenishmentCreationCreated>());
    expect(replenishments.idempotencyKeys, ['key-1', 'key-1']);
  });

  test('new machine gets a new idempotency key', () async {
    await controller.start();
    expect(replenishments.idempotencyKeys, ['key-1']);

    machines.machine = fakeMachine(
      machineId: '22222222-2222-2222-2222-222222222222',
      identifier: 'MIX-002',
      name: 'Cafe',
    );
    await machineController.identify('MIX-002');
    controller.resetToInitial();
    await controller.start();

    expect(replenishments.idempotencyKeys, ['key-1', 'key-2']);
    expect(
      replenishments.machineIds.last,
      '22222222-2222-2222-2222-222222222222',
    );
  });

  test('failure keeps previous Current Replenishment', () async {
    await controller.start();
    final previous = controller.currentReplenishment;
    expect(previous, isNotNull);

    controller.resetToInitial();
    replenishments.error = const ReplenishmentConflict();
    await controller.start();

    expect(controller.state, isA<ReplenishmentCreationFailure>());
    expect(controller.currentReplenishment?.id, previous!.id);
  });

  test('401 clears session', () async {
    sessions.session = fakeSession(issuedAt: clock.now());
    var expired = false;
    controller = ReplenishmentCreationController(
      replenishmentService: replenishments,
      machineIdentificationController: machineController,
      operatorBootstrapController: operatorController,
      locationService: const FixedLocationService(
        DeviceLocation(latitude: 1, longitude: 2),
      ),
      sessionService: sessions,
      requestIdGenerator: FixedRequestIdGenerator('fixed'),
      logger: logger,
      onSessionExpired: () async {
        expired = true;
      },
    );
    replenishments.error = const ReplenishmentSessionExpired();

    await controller.start();

    expect(controller.state, isA<ReplenishmentCreationSessionExpired>());
    expect(sessions.clearCallCount, greaterThan(0));
    expect(expired, isTrue);
  });

  test('stale response for machine A does not install over machine B', () async {
    final gate = Completer<void>();
    replenishments.pending = gate.future;
    replenishments.replenishment = fakeReplenishment(
      id: 'rep-a',
      machineId: '11111111-1111-1111-1111-111111111111',
    );

    final loadA = controller.start();
    await Future<void>.delayed(Duration.zero);

    machines.machine = fakeMachine(
      machineId: '22222222-2222-2222-2222-222222222222',
      identifier: 'MIX-002',
    );
    await machineController.identify('MIX-002');

    gate.complete();
    await loadA;

    expect(controller.currentReplenishment, isNull);
    expect(controller.state, isA<ReplenishmentCreationInitial>());
  });

  test('403 and 409 surface specific failures', () async {
    replenishments.error = const ReplenishmentAccessDenied();
    await controller.start();
    expect(
      (controller.state as ReplenishmentCreationFailure).message,
      contains('permiso'),
    );

    controller.resetToInitial();
    replenishments.error = const ReplenishmentConflict();
    await controller.start();
    expect(
      (controller.state as ReplenishmentCreationFailure).message,
      contains('reposición en curso'),
    );
  });
}

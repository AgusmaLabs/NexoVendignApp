import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_detail_controller.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_add_line_controller.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_add_line_state.dart';
import 'package:vendingapp/features/replenishment/application/replenishment_creation_controller.dart';
import 'package:vendingapp/features/replenishment/domain/replenishment_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeClock clock;
  late FakeSessionService sessions;
  late FakeMachineService machines;
  late FakeOperatorService operators;
  late FakeReplenishmentService replenishments;
  late FakeReplenishmentLineService lines;
  late FakeMachineDetailService details;
  late FakeMachineSlotService slots;
  late RecordingAppLogger logger;
  late MachineIdentificationController machineController;
  late MachineDetailController detailController;
  late OperatorBootstrapController operatorController;
  late ReplenishmentCreationController creationController;
  late ReplenishmentAddLineController controller;
  late SequenceRequestIdGenerator requestIds;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    sessions = FakeSessionService(clock: clock);
    machines = FakeMachineService();
    operators = FakeOperatorService();
    replenishments = FakeReplenishmentService();
    lines = FakeReplenishmentLineService();
    details = FakeMachineDetailService();
    slots = FakeMachineSlotService(
      slots: [
        fakeMachineSlot(slotId: 'slot-A01', slotNumber: 1),
        fakeMachineSlot(slotId: 'slot-A02', slotNumber: 2),
      ],
    );
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
    detailController = MachineDetailController(
      detailService: details,
      slotService: slots,
      sessionService: sessions,
      logger: logger,
    );
    creationController = ReplenishmentCreationController(
      replenishmentService: replenishments,
      machineIdentificationController: machineController,
      operatorBootstrapController: operatorController,
      locationService: const FixedLocationService(
        DeviceLocation(latitude: -35.4264, longitude: -71.6554),
      ),
      sessionService: sessions,
      requestIdGenerator: requestIds,
      logger: logger,
    );
    controller = ReplenishmentAddLineController(
      lineService: lines,
      replenishmentCreationController: creationController,
      machineDetailController: detailController,
      sessionService: sessions,
      requestIdGenerator: requestIds,
      logger: logger,
    );

    await operatorController.load();
    await machineController.identify('MIX-001');
    await detailController.load(
      machineController.currentMachine!.machineId,
    );
    await creationController.start();
    controller.beginWithProduct(fakeProduct());
  });

  test('add line success updates Current Replenishment', () async {
    controller.selectSlot('slot-A01');
    controller.setQuantity(12);

    final future = controller.submit();
    expect(controller.state, isA<ReplenishmentAddLineAdding>());
    await future;

    expect(controller.state, isA<ReplenishmentAddLineAdded>());
    expect(creationController.currentReplenishment?.lines, hasLength(1));
    expect(lines.callCount, 1);
    expect(lines.slotIds.single, 'slot-A01');
    expect(lines.quantities.single, 12);
    expect(lines.idempotencyKeys.single, 'key-2');
  });

  test('quantity <= 0 is validation failure without HTTP', () async {
    controller.selectSlot('slot-A01');
    controller.setQuantity(0);
    await controller.submit();

    expect(controller.state, isA<ReplenishmentAddLineValidationFailure>());
    expect(lines.callCount, 0);
  });

  test('missing slot is validation failure without HTTP', () async {
    controller.setQuantity(5);
    await controller.submit();

    expect(controller.state, isA<ReplenishmentAddLineValidationFailure>());
    expect(lines.callCount, 0);
  });

  test('no active replenishment skips HTTP', () async {
    await creationController.clear();
    controller.selectSlot('slot-A01');
    controller.setQuantity(3);
    await controller.submit();

    expect(controller.state, isA<ReplenishmentAddLineValidationFailure>());
    expect(lines.callCount, 0);
  });

  test('double tap while adding issues one POST', () async {
    final gate = Completer<void>();
    lines.pending = gate.future;
    controller.selectSlot('slot-A01');
    controller.setQuantity(4);

    final first = controller.submit();
    await Future<void>.delayed(Duration.zero);
    final second = controller.submit();
    gate.complete();
    await Future.wait([first, second]);

    expect(lines.callCount, 1);
    expect(controller.state, isA<ReplenishmentAddLineAdded>());
  });

  test('retry reuses the same idempotency key', () async {
    lines.error = const ReplenishmentNetworkFailure();
    controller.selectSlot('slot-A01');
    controller.setQuantity(7);
    await controller.submit();
    expect(controller.state, isA<ReplenishmentAddLineFailure>());
    final firstKey = controller.pendingIdempotencyKey;
    expect(firstKey, isNotNull);

    lines.error = null;
    await controller.retry();

    expect(lines.idempotencyKeys, [firstKey, firstKey]);
    expect(controller.state, isA<ReplenishmentAddLineAdded>());
  });

  test('401 clears session', () async {
    lines.error = const ReplenishmentSessionExpired();
    var expired = false;
    controller = ReplenishmentAddLineController(
      lineService: lines,
      replenishmentCreationController: creationController,
      machineDetailController: detailController,
      sessionService: sessions,
      requestIdGenerator: requestIds,
      logger: logger,
      onSessionExpired: () async {
        expired = true;
      },
    );
    controller.beginWithProduct(fakeProduct());
    controller.selectSlot('slot-A01');
    controller.setQuantity(2);
    await controller.submit();

    expect(controller.state, isA<ReplenishmentAddLineSessionExpired>());
    expect(sessions.session, isNull);
    expect(expired, isTrue);
  });

  test('add line does not invent inventory fields', () async {
    controller.selectSlot('slot-A01');
    controller.setQuantity(12);
    await controller.submit();

    final updated = creationController.currentReplenishment!;
    final json = updated.toJson();
    expect(json.containsKey('inventory'), isFalse);
    expect(json.containsKey('stock'), isFalse);
    expect(updated.lines.single.toJson().containsKey('stock_delta'), isFalse);
  });

  test('stale replenishment id is ignored', () async {
    lines.replenishment = fakeReplenishment(
      id: 'other-rep',
      lines: [fakeReplenishmentLine()],
    );
    controller.selectSlot('slot-A01');
    controller.setQuantity(1);
    await controller.submit();

    expect(controller.state, isA<ReplenishmentAddLineIdle>());
    expect(creationController.currentReplenishment?.lines, isEmpty);
  });
}

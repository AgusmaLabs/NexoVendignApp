import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_detail_controller.dart';
import 'package:vendingapp/features/machine/application/machine_detail_state.dart';
import 'package:vendingapp/features/machine/domain/machine_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeClock clock;
  late FakeSessionService sessions;
  late FakeMachineDetailService details;
  late FakeMachineSlotService slots;
  late RecordingAppLogger logger;
  late MachineDetailController controller;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    sessions = FakeSessionService(clock: clock);
    details = FakeMachineDetailService();
    slots = FakeMachineSlotService();
    logger = RecordingAppLogger();
    controller = MachineDetailController(
      detailService: details,
      slotService: slots,
      sessionService: sessions,
      logger: logger,
    );
  });

  test('Initial → Loading → Loaded sets detail and slots', () async {
    expect(controller.currentDetail, isNull);
    final future = controller.load('m-1');
    expect(controller.state, isA<MachineDetailLoading>());
    await future;

    expect(controller.state, isA<MachineDetailLoaded>());
    expect(controller.currentDetail?.machineId, 'm-1');
    expect(controller.currentSlots, isNotEmpty);
    expect(details.lastMachineId, 'm-1');
    expect(slots.lastMachineId, 'm-1');
  });

  test('empty machine id is failure without HTTP', () async {
    await controller.load('  ');
    expect(controller.state, isA<MachineDetailFailure>());
    expect(details.callCount, 0);
    expect(slots.callCount, 0);
  });

  test('empty slots list is Loaded with empty collection', () async {
    slots.slots = [];
    await controller.load('m-1');
    final state = controller.state;
    expect(state, isA<MachineDetailLoaded>());
    expect((state as MachineDetailLoaded).slots, isEmpty);
  });

  test('detail success + slots failure ends in Failure', () async {
    slots.error = const MachineNotFound();
    await controller.load('m-1');
    expect(controller.state, isA<MachineDetailFailure>());
    expect(controller.currentDetail, isNull);
  });

  test('detail failure + slots success ends in Failure', () async {
    details.error = const MachineAccessDenied();
    await controller.load('m-1');
    expect(controller.state, isA<MachineDetailFailure>());
    expect(
      (controller.state as MachineDetailFailure).message,
      'No tienes acceso a esta máquina.',
    );
  });

  test('401 clears session', () async {
    sessions.session = fakeSession(issuedAt: clock.now());
    var expired = false;
    controller = MachineDetailController(
      detailService: details,
      slotService: slots,
      sessionService: sessions,
      logger: logger,
      onSessionExpired: () async {
        expired = true;
      },
    );
    details.error = const MachineSessionExpired();

    await controller.load('m-1');

    expect(controller.state, isA<MachineDetailSessionExpired>());
    expect(sessions.clearCallCount, greaterThan(0));
    expect(expired, isTrue);
  });

  test('selectSlot is visual only and does not call services', () async {
    await controller.load('m-1');
    final beforeDetail = details.callCount;
    final beforeSlots = slots.callCount;

    controller.selectSlot('slot-1');
    expect(controller.selectedSlotId, 'slot-1');
    expect(details.callCount, beforeDetail);
    expect(slots.callCount, beforeSlots);

    controller.clearSelectedSlot();
    expect(controller.selectedSlotId, isNull);
  });

  test('load B supersedes stale response from A', () async {
    final gateA = Completer<void>();
    details.pending = gateA.future;
    slots.pending = gateA.future;

    final loadA = controller.load('machine-a');
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isA<MachineDetailLoading>());

    details.pending = null;
    slots.pending = null;
    details.detail = fakeMachineDetail(
      machineId: 'machine-b',
      identifier: 'B-001',
      name: 'Machine B',
    );
    slots.slots = [
      fakeMachineSlot(slotId: 'slot-b', slotNumber: 9),
    ];

    await controller.load('machine-b');
    expect(controller.currentDetail?.machineId, 'machine-b');
    expect(controller.currentSlots.single.slotId, 'slot-b');

    details.detail = fakeMachineDetail(
      machineId: 'machine-a',
      identifier: 'A-001',
      name: 'Machine A',
    );
    slots.slots = [
      fakeMachineSlot(slotId: 'slot-a', slotNumber: 1),
    ];
    gateA.complete();
    await loadA;

    expect(controller.currentDetail?.machineId, 'machine-b');
    expect(controller.currentSlots.single.slotId, 'slot-b');
  });

  test('clear resets context', () async {
    await controller.load('m-1');
    controller.selectSlot('slot-1');
    await controller.clear();
    expect(controller.currentDetail, isNull);
    expect(controller.currentSlots, isEmpty);
    expect(controller.selectedSlotId, isNull);
    expect(controller.state, isA<MachineDetailInitial>());
  });

  test('retry reloads last machine id', () async {
    details.error = const MachineNetworkFailure(
      message: 'No fue posible cargar la configuración de la máquina.',
    );
    await controller.load('m-retry');
    expect(controller.state, isA<MachineDetailFailure>());

    details.error = null;
    await controller.retry();
    expect(controller.currentDetail?.machineId, 'm-retry');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/machine/application/machine_identification_state.dart';
import 'package:vendingapp/features/machine/domain/machine_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeClock clock;
  late FakeSessionService sessions;
  late FakeMachineService machines;
  late RecordingAppLogger logger;
  late MachineIdentificationController controller;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    sessions = FakeSessionService(clock: clock);
    machines = FakeMachineService();
    logger = RecordingAppLogger();
    controller = MachineIdentificationController(
      machineService: machines,
      sessionService: sessions,
      logger: logger,
    );
  });

  test('Initial → Resolving → Resolved sets currentMachine', () async {
    expect(controller.currentMachine, isNull);
    final future = controller.identify('MIX-001');
    expect(controller.state, isA<MachineIdentificationResolving>());
    await future;
    expect(controller.state, isA<MachineIdentificationResolved>());
    expect(controller.currentMachine?.identifier, 'MIX-001');
  });

  test('empty identifier is validation failure without HTTP', () async {
    await controller.identify('  ');
    expect(controller.state, isA<MachineIdentificationFailure>());
    expect(machines.callCount, 0);
    expect(controller.currentMachine, isNull);
  });

  test('failed resolve keeps previous machine context', () async {
    await controller.identify('MIX-001');
    expect(controller.currentMachine?.identifier, 'MIX-001');

    machines.error = const MachineNotFound();
    await controller.identify('MISSING');

    expect(controller.state, isA<MachineIdentificationFailure>());
    expect(controller.currentMachine?.identifier, 'MIX-001');
  });

  test('401 clears session', () async {
    sessions.session = fakeSession(issuedAt: clock.now());
    var expired = false;
    controller = MachineIdentificationController(
      machineService: machines,
      sessionService: sessions,
      logger: logger,
      onSessionExpired: () async {
        expired = true;
      },
    );
    machines.error = const MachineSessionExpired();

    await controller.identify('MIX-001');

    expect(controller.state, isA<MachineIdentificationSessionExpired>());
    expect(sessions.clearCallCount, greaterThan(0));
    expect(expired, isTrue);
  });

  test('clear resets context', () async {
    await controller.identify('MIX-001');
    await controller.clear();
    expect(controller.currentMachine, isNull);
    expect(controller.state, isA<MachineIdentificationInitial>());
  });
}

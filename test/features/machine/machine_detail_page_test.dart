import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_detail_controller.dart';
import 'package:vendingapp/features/machine/application/machine_detail_state.dart';
import 'package:vendingapp/features/machine/domain/machine_exception.dart';
import 'package:vendingapp/features/machine/presentation/machine_detail_page.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeMachineDetailService details;
  late FakeMachineSlotService slots;
  late MachineDetailController controller;

  setUp(() {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    details = FakeMachineDetailService(
      detail: fakeMachineDetail(name: 'Lobby', identifier: 'MIX-001'),
    );
    slots = FakeMachineSlotService(
      slots: [
        fakeMachineSlot(slotId: 'slot-1', slotNumber: 1, capacity: 10),
        fakeMachineSlot(
          slotId: 'slot-2',
          slotNumber: 2,
          capacity: 8,
          preferredProductId: null,
        ),
      ],
    );
    controller = MachineDetailController(
      detailService: details,
      slotService: slots,
      sessionService: FakeSessionService(clock: clock),
      logger: RecordingAppLogger(),
    );
  });

  Widget wrap({bool autoLoad = true}) {
    return MaterialApp(
      home: MachineDetailPage(
        machineId: 'm-1',
        controller: controller,
        autoLoad: autoLoad,
      ),
    );
  }

  testWidgets('loading shows configuration message', (tester) async {
    await tester.pumpWidget(wrap());
    expect(
      find.text('Cargando configuración de la máquina...'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('loaded shows machine and all slots', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Lobby'), findsOneWidget);
    expect(find.text('MIX-001'), findsOneWidget);
    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S2'), findsOneWidget);
    expect(find.textContaining('Capacidad: 10'), findsOneWidget);
  });

  testWidgets('empty slots shows empty state', (tester) async {
    slots.slots = [];
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No hay slots configurados'), findsOneWidget);
  });

  testWidgets('slot selection is visual only', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final before = details.callCount + slots.callCount;
    await tester.tap(find.text('S1'));
    await tester.pump();

    expect(controller.selectedSlotId, 'slot-1');
    expect(find.text('Slot seleccionado (listo para reposición).'), findsOneWidget);
    expect(details.callCount + slots.callCount, before);
  });

  testWidgets('error shows message and retry', (tester) async {
    details.error = const MachineNotFound();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Máquina no encontrada.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    details.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Lobby'), findsOneWidget);
  });

  testWidgets('403 shows access denied', (tester) async {
    details.error = const MachineAccessDenied();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No tienes acceso a esta máquina.'), findsOneWidget);
  });

  testWidgets('401 shows session expired message', (tester) async {
    details.error = const MachineSessionExpired();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(controller.state, isA<MachineDetailSessionExpired>());
    expect(
      find.text('La sesión ha expirado. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });

  testWidgets('preloaded state renders without second auto load', (tester) async {
    await controller.load('m-1');
    final callsBefore = details.callCount;
    await tester.pumpWidget(wrap(autoLoad: true));
    await tester.pumpAndSettle();

    expect(find.text('Lobby'), findsOneWidget);
    expect(details.callCount, callsBefore);
  });
}

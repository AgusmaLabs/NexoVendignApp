import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/machine/domain/machine_exception.dart';
import 'package:vendingapp/features/machine/presentation/identify_machine_page.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeMachineService machines;
  late MachineIdentificationController controller;

  setUp(() {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    machines = FakeMachineService();
    controller = MachineIdentificationController(
      machineService: machines,
      sessionService: FakeSessionService(clock: clock),
      logger: RecordingAppLogger(),
    );
  });

  Widget wrap() {
    return MaterialApp(home: IdentifyMachinePage(controller: controller));
  }

  testWidgets('initial shows identifier field and button', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Identificador de máquina'), findsOneWidget);
    expect(find.text('Identificar máquina'), findsOneWidget);
  });

  testWidgets('empty input shows validation without HTTP', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Identificar máquina'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un identificador de máquina.'), findsOneWidget);
    expect(machines.callCount, 0);
  });

  testWidgets('success shows machine details', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'MIX-001');
    await tester.tap(find.text('Identificar máquina'));
    await tester.pumpAndSettle();

    expect(find.text('Máquina identificada'), findsOneWidget);
    expect(find.text('Lobby'), findsOneWidget);
    expect(find.text('MIX-001'), findsOneWidget);
  });

  testWidgets('not found shows message and allows retry', (tester) async {
    machines.error = const MachineNotFound();
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'MISSING');
    await tester.tap(find.text('Identificar máquina'));
    await tester.pumpAndSettle();

    expect(find.text('Máquina no encontrada.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    machines.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Máquina identificada'), findsOneWidget);
  });

  testWidgets('403 shows access denied', (tester) async {
    machines.error = const MachineAccessDenied();
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'MIX-001');
    await tester.tap(find.text('Identificar máquina'));
    await tester.pumpAndSettle();

    expect(find.text('No tienes acceso a esta máquina.'), findsOneWidget);
  });

  testWidgets('loading disables button', (tester) async {
    machines.delay = const Duration(milliseconds: 80);
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'MIX-001');
    await tester.tap(find.text('Identificar máquina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Resolviendo máquina...'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Identificar máquina'),
    );
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });
}

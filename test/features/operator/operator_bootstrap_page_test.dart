import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/app/app.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/authentication/application/authentication_controller.dart';
import 'package:vendingapp/features/authentication/application/authentication_state.dart';
import 'package:vendingapp/features/authentication/presentation/login_page.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_state.dart';
import 'package:vendingapp/features/operator/domain/operator_exception.dart';
import 'package:vendingapp/features/operator/presentation/operator_bootstrap_page.dart';

import '../../support/test_doubles.dart';

void main() {
  testWidgets('loading shows indicator', (tester) async {
    final operators = FakeOperatorService(
      delay: const Duration(milliseconds: 80),
    );
    final deps = testDependencies(operatorService: operators);
    await tester.pumpWidget(VendingApp(dependencies: deps));
    await tester.pumpAndSettle();

    // Do not await signIn — FakeOperatorService delay needs tester.pump.
    final pending = deps.authenticationController.signIn();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Cargando operador...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await pending;
    await tester.pumpAndSettle();
  });

  testWidgets('loaded operator shows welcome', (tester) async {
    final deps = testDependencies(
      operatorService: FakeOperatorService(operator: fakeOperator()),
    );
    await tester.pumpWidget(VendingApp(dependencies: deps));
    await tester.pumpAndSettle();

    await deps.authenticationController.signIn();
    await tester.pumpAndSettle();

    expect(find.textContaining('Bienvenido'), findsOneWidget);
    expect(find.textContaining('Ada Operator'), findsOneWidget);
  });

  testWidgets('network failure shows retry', (tester) async {
    final operators = FakeOperatorService(
      error: const OperatorNetworkFailure(),
    );
    final deps = testDependencies(operatorService: operators);
    await tester.pumpWidget(VendingApp(dependencies: deps));
    await tester.pumpAndSettle();

    await deps.authenticationController.signIn();
    await tester.pumpAndSettle();

    expect(find.text('No fue posible cargar tu información.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    operators.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bienvenido'), findsOneWidget);
  });

  testWidgets('403 shows access denied', (tester) async {
    final deps = testDependencies(
      operatorService: FakeOperatorService(error: const OperatorAccessDenied()),
    );
    await tester.pumpWidget(VendingApp(dependencies: deps));
    await tester.pumpAndSettle();

    await deps.authenticationController.signIn();
    await tester.pumpAndSettle();

    expect(
      find.text('No tienes acceso a la aplicación de operaciones.'),
      findsOneWidget,
    );
    expect(find.textContaining('Bienvenido'), findsNothing);
  });

  testWidgets('401 returns to authentication flow', (tester) async {
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    final sessions = FakeSessionService(clock: clock);
    final operators = FakeOperatorService(
      error: const OperatorSessionExpired(),
    );
    late AuthenticationController auth;
    final bootstrap = OperatorBootstrapController(
      operatorService: operators,
      sessionService: sessions,
      logger: RecordingAppLogger(),
      onSessionExpired: () => auth.handleSessionExpired(),
    );
    auth = AuthenticationController(
      googleSignInService: FakeGoogleSignInService(),
      sessionService: sessions,
      config: testConfig(),
      logger: RecordingAppLogger(),
      afterSessionEstablished: bootstrap.load,
      afterSessionCleared: bootstrap.clear,
    );
    final deps = testDependencies(
      sessionService: sessions,
      operatorService: operators,
      operatorBootstrapController: bootstrap,
      authenticationController: auth,
      clock: clock,
      wireOperatorBootstrap: false,
    );

    await tester.pumpWidget(VendingApp(dependencies: deps));
    await tester.pumpAndSettle();
    await auth.signIn();
    await tester.pumpAndSettle();

    expect(auth.state, isA<SessionExpired>());
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.textContaining('sesión ha expirado'), findsOneWidget);
  });

  testWidgets('logout clears session and operator', (tester) async {
    final deps = testDependencies();
    await tester.pumpWidget(VendingApp(dependencies: deps));
    await tester.pumpAndSettle();

    await deps.authenticationController.signIn();
    await tester.pumpAndSettle();
    expect(find.byType(OperatorHomePage), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      deps.operatorBootstrapController.state,
      isA<OperatorBootstrapUnknown>(),
    );
    expect(deps.authenticationController.state, isA<Unauthenticated>());
  });
}

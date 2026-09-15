import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/authentication/authentication_exception.dart';
import 'package:vendingapp/core/authentication/session_exception.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/authentication/application/authentication_controller.dart';
import 'package:vendingapp/features/authentication/presentation/login_page.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeClock clock;
  late FakeSessionService sessions;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    sessions = FakeSessionService(clock: clock);
  });

  AuthenticationController controller({FakeGoogleSignInService? google}) {
    return AuthenticationController(
      googleSignInService: google ?? FakeGoogleSignInService(),
      sessionService: sessions,
      config: testConfig(),
      logger: RecordingAppLogger(),
    );
  }

  Widget wrap(AuthenticationController auth) {
    return MaterialApp(home: LoginPage(controller: auth));
  }

  testWidgets('shows Continuar con Google initially', (tester) async {
    await tester.pumpWidget(wrap(controller()));

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Inicia sesión para continuar'), findsOneWidget);
  });

  testWidgets('shows Authenticating and disables button while Google loads', (
    tester,
  ) async {
    final auth = controller(
      google: FakeGoogleSignInService(
        signInDelay: const Duration(milliseconds: 50),
      ),
    );

    await tester.pumpWidget(wrap(auth));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();

    expect(find.text('Authenticating'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets('success updates UI without showing tokens', (tester) async {
    await tester.pumpWidget(wrap(controller()));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('fake-google-id-token'), findsNothing);
    expect(find.textContaining('test-session-token'), findsNothing);
  });

  testWidgets('session failure shows user-facing message', (tester) async {
    sessions.createError = const SessionAccessDenied();
    await tester.pumpWidget(wrap(controller()));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No tienes acceso'), findsOneWidget);
    expect(find.textContaining('test-session-token'), findsNothing);
  });

  testWidgets('cancellation returns to unauthenticated UI', (tester) async {
    await tester.pumpWidget(
      wrap(
        controller(
          google: FakeGoogleSignInService(
            error: const AuthenticationCancelled(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Sesión iniciada'), findsNothing);
  });

  testWidgets('error shows user-facing message without SDK details', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        controller(
          google: FakeGoogleSignInService(
            error: const AuthenticationFailed('sdk-internal-detail'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo iniciar sesión'), findsOneWidget);
    expect(find.textContaining('sdk-internal-detail'), findsNothing);
  });
}

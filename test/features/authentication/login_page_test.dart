import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/authentication/authentication_exception.dart';
import 'package:vendingapp/features/authentication/application/authentication_controller.dart';
import 'package:vendingapp/features/authentication/presentation/login_page.dart';

import '../../support/test_doubles.dart';

void main() {
  Widget wrap(AuthenticationController controller) {
    return MaterialApp(home: LoginPage(controller: controller));
  }

  testWidgets('shows Continuar con Google initially', (tester) async {
    final controller = AuthenticationController(
      googleSignInService: FakeGoogleSignInService(),
      logger: RecordingAppLogger(),
    );

    await tester.pumpWidget(wrap(controller));

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Inicia sesión para continuar'), findsOneWidget);
  });

  testWidgets('shows Authenticating and disables button while loading', (
    tester,
  ) async {
    final controller = AuthenticationController(
      googleSignInService: FakeGoogleSignInService(
        signInDelay: const Duration(milliseconds: 50),
      ),
      logger: RecordingAppLogger(),
    );

    await tester.pumpWidget(wrap(controller));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();

    expect(find.text('Authenticating'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets('success updates UI without showing id_token', (tester) async {
    final controller = AuthenticationController(
      googleSignInService: FakeGoogleSignInService(
        result: fakeGoogleResult(
          idToken: 'fake-google-id-token',
          email: 'operator@example.com',
        ),
      ),
      logger: RecordingAppLogger(),
    );

    await tester.pumpWidget(wrap(controller));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.text('Autenticado con Google'), findsOneWidget);
    expect(find.text('operator@example.com'), findsOneWidget);
    expect(find.textContaining('fake-google-id-token'), findsNothing);
  });

  testWidgets('cancellation returns to unauthenticated UI', (tester) async {
    final controller = AuthenticationController(
      googleSignInService: FakeGoogleSignInService(
        error: const AuthenticationCancelled(),
      ),
      logger: RecordingAppLogger(),
    );

    await tester.pumpWidget(wrap(controller));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Autenticado con Google'), findsNothing);
    expect(find.textContaining('fake-google-id-token'), findsNothing);
  });

  testWidgets('error shows user-facing message without SDK details', (
    tester,
  ) async {
    final controller = AuthenticationController(
      googleSignInService: FakeGoogleSignInService(
        error: const AuthenticationFailed('sdk-internal-detail'),
      ),
      logger: RecordingAppLogger(),
    );

    await tester.pumpWidget(wrap(controller));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo iniciar sesión'), findsOneWidget);
    expect(find.textContaining('sdk-internal-detail'), findsNothing);
    expect(find.textContaining('fake-google-id-token'), findsNothing);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/app/app.dart';
import 'package:vendingapp/core/authentication/authentication_exception.dart';
import 'package:vendingapp/features/authentication/application/authentication_state.dart';

import '../../support/test_doubles.dart';

void main() {
  testWidgets('login UI → Google → session → Authenticated', (tester) async {
    final google = FakeGoogleSignInService(
      result: fakeGoogleResult(idToken: 'fake-google-id-token'),
    );
    final logger = RecordingAppLogger();
    final dependencies = testDependencies(
      googleSignInService: google,
      logger: logger,
    );

    await tester.pumpWidget(VendingApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('Continuar con Google'), findsOneWidget);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(dependencies.authenticationController.state, isA<Authenticated>());
    expect(google.signInCallCount, 1);
    expect(find.textContaining('Bienvenido'), findsOneWidget);
    expect(find.textContaining('fake-google-id-token'), findsNothing);
    expect(find.textContaining('test-session-token'), findsNothing);
    expect(logger.hasSensitiveLeak, isFalse);
  });

  testWidgets(
    'cancelled Google Sign-In stays on login without error token leak',
    (tester) async {
      final dependencies = testDependencies(
        googleSignInService: FakeGoogleSignInService(
          error: const AuthenticationCancelled(),
        ),
      );

      await tester.pumpWidget(VendingApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(
        dependencies.authenticationController.state,
        isA<Unauthenticated>(),
      );
      expect(find.text('Continuar con Google'), findsOneWidget);
    },
  );
}

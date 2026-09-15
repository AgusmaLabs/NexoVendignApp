import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/authentication/authentication_exception.dart';
import 'package:vendingapp/features/authentication/application/authentication_controller.dart';
import 'package:vendingapp/features/authentication/application/authentication_state.dart';

import '../../support/test_doubles.dart';

void main() {
  group('AuthenticationController', () {
    test('Unauthenticated → Authenticating → Authenticated', () async {
      final service = FakeGoogleSignInService(
        signInDelay: const Duration(milliseconds: 20),
      );
      final logger = RecordingAppLogger();
      final controller = AuthenticationController(
        googleSignInService: service,
        logger: logger,
      );

      expect(controller.state, isA<Unauthenticated>());

      final future = controller.signIn();
      expect(controller.state, isA<Authenticating>());
      await future;

      expect(controller.state, isA<Authenticated>());
      final authenticated = controller.state as Authenticated;
      expect(authenticated.result.idToken, 'fake-google-id-token');
      expect(logger.containsMessage('authentication_started'), isTrue);
      expect(logger.hasSensitiveLeak, isFalse);
    });

    test('failure becomes AuthenticationFailure', () async {
      final controller = AuthenticationController(
        googleSignInService: FakeGoogleSignInService(
          error: const AuthenticationFailed('boom'),
        ),
        logger: RecordingAppLogger(),
      );

      await controller.signIn();

      expect(controller.state, isA<AuthenticationFailure>());
      final failure = controller.state as AuthenticationFailure;
      expect(failure.message.toLowerCase(), contains('google'));
      expect(failure.message, isNot(contains('boom')));
    });

    test('cancellation returns to Unauthenticated', () async {
      final logger = RecordingAppLogger();
      final controller = AuthenticationController(
        googleSignInService: FakeGoogleSignInService(
          error: const AuthenticationCancelled(),
        ),
        logger: logger,
      );

      await controller.signIn();

      expect(controller.state, isA<Unauthenticated>());
      expect(logger.containsMessage('authentication_cancelled'), isTrue);
    });

    test('ignores concurrent signIn while authenticating', () async {
      final service = FakeGoogleSignInService(
        signInDelay: const Duration(milliseconds: 40),
      );
      final controller = AuthenticationController(
        googleSignInService: service,
        logger: RecordingAppLogger(),
      );

      final first = controller.signIn();
      final second = controller.signIn();
      await Future.wait([first, second]);

      expect(service.signInCallCount, 1);
      expect(controller.state, isA<Authenticated>());
    });
  });
}

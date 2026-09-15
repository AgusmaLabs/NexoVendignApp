import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/authentication/authentication_exception.dart';
import 'package:vendingapp/core/authentication/session_exception.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/authentication/application/authentication_controller.dart';
import 'package:vendingapp/features/authentication/application/authentication_state.dart';

import '../../support/test_doubles.dart';

void main() {
  group('AuthenticationController', () {
    late FakeClock clock;
    late FakeSessionService sessions;
    late RecordingAppLogger logger;

    setUp(() {
      clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
      sessions = FakeSessionService(clock: clock);
      logger = RecordingAppLogger();
    });

    AuthenticationController build({FakeGoogleSignInService? google}) {
      return AuthenticationController(
        googleSignInService: google ?? FakeGoogleSignInService(),
        sessionService: sessions,
        config: testConfig(),
        logger: logger,
      );
    }

    test(
      'Google → CreatingSession → Authenticated with Vending session',
      () async {
        final google = FakeGoogleSignInService(
          signInDelay: const Duration(milliseconds: 20),
        );
        final controller = build(google: google);

        expect(controller.state, isA<Unauthenticated>());

        final future = controller.signIn();
        expect(controller.state, isA<Authenticating>());
        await future;

        expect(controller.state, isA<Authenticated>());
        final authenticated = controller.state as Authenticated;
        expect(authenticated.session.accessToken, 'test-session-token');
        expect(sessions.createCallCount, 1);
        expect(sessions.lastTenantId, 'tenant-a');
        expect(logger.containsMessage('authentication_started'), isTrue);
        expect(logger.hasSensitiveLeak, isFalse);
      },
    );

    test('Google failure becomes AuthenticationFailure', () async {
      final controller = build(
        google: FakeGoogleSignInService(
          error: const AuthenticationFailed('boom'),
        ),
      );

      await controller.signIn();

      expect(controller.state, isA<AuthenticationFailure>());
      final failure = controller.state as AuthenticationFailure;
      expect(failure.message.toLowerCase(), contains('google'));
      expect(failure.message, isNot(contains('boom')));
      expect(sessions.createCallCount, 0);
    });

    test('session 401 becomes SessionFailure', () async {
      sessions.createError = const SessionAuthenticationFailed();
      final controller = build();

      await controller.signIn();

      expect(controller.state, isA<SessionFailure>());
      expect(sessions.createCallCount, 1);
    });

    test('cancellation returns to Unauthenticated', () async {
      final controller = build(
        google: FakeGoogleSignInService(error: const AuthenticationCancelled()),
      );

      await controller.signIn();

      expect(controller.state, isA<Unauthenticated>());
      expect(logger.containsMessage('authentication_cancelled'), isTrue);
      expect(sessions.createCallCount, 0);
    });

    test('ignores concurrent signIn while busy', () async {
      final google = FakeGoogleSignInService(
        signInDelay: const Duration(milliseconds: 40),
      );
      final controller = build(google: google);

      final first = controller.signIn();
      final second = controller.signIn();
      await Future.wait([first, second]);

      expect(google.signInCallCount, 1);
      expect(controller.state, isA<Authenticated>());
    });

    test('restoreSession authenticates from storage', () async {
      sessions.restoreResult = fakeSession(issuedAt: clock.now());
      final controller = build();

      await controller.restoreSession();

      expect(controller.state, isA<Authenticated>());
    });

    test('restoreSession with no session stays Unauthenticated', () async {
      sessions.restoreResult = null;
      final controller = build();

      await controller.restoreSession();

      expect(controller.state, isA<Unauthenticated>());
    });

    test('signOut clears session', () async {
      final controller = build();
      await controller.signIn();
      expect(controller.state, isA<Authenticated>());

      await controller.signOut();

      expect(controller.state, isA<Unauthenticated>());
      expect(sessions.clearCallCount, 1);
    });
  });
}

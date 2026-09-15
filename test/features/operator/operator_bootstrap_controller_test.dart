import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/authentication/application/authentication_controller.dart';
import 'package:vendingapp/features/authentication/application/authentication_state.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_state.dart';
import 'package:vendingapp/features/operator/domain/operator_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  late FakeClock clock;
  late FakeSessionService sessions;
  late FakeOperatorService operators;
  late RecordingAppLogger logger;
  late AuthenticationController auth;
  late OperatorBootstrapController bootstrap;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    sessions = FakeSessionService(clock: clock);
    operators = FakeOperatorService();
    logger = RecordingAppLogger();
    late AuthenticationController authRef;
    bootstrap = OperatorBootstrapController(
      operatorService: operators,
      sessionService: sessions,
      logger: logger,
      onSessionExpired: () => authRef.handleSessionExpired(),
    );
    auth = AuthenticationController(
      googleSignInService: FakeGoogleSignInService(),
      sessionService: sessions,
      config: testConfig(),
      logger: logger,
      afterSessionEstablished: bootstrap.load,
      afterSessionCleared: bootstrap.clear,
    );
    authRef = auth;
  });

  test('Unknown → Loading → Loaded', () async {
    expect(bootstrap.state, isA<OperatorBootstrapUnknown>());
    final future = bootstrap.load();
    expect(bootstrap.state, isA<OperatorBootstrapLoading>());
    await future;
    expect(bootstrap.state, isA<OperatorBootstrapLoaded>());
    expect(bootstrap.currentOperator?.operatorId, 'op-1');
  });

  test('Loading → Failure allows retry', () async {
    operators.error = const OperatorNetworkFailure();
    await bootstrap.load();
    expect(bootstrap.state, isA<OperatorBootstrapFailure>());

    operators.error = null;
    await bootstrap.retry();
    expect(bootstrap.state, isA<OperatorBootstrapLoaded>());
  });

  test('403 access denied does not invent operator', () async {
    operators.error = const OperatorAccessDenied();
    await bootstrap.load();
    expect(bootstrap.state, isA<OperatorBootstrapAccessDenied>());
    expect(bootstrap.currentOperator, isNull);
  });

  test('not configured does not invent operator', () async {
    operators.error = const OperatorNotConfigured();
    await bootstrap.load();
    expect(bootstrap.state, isA<OperatorBootstrapNotConfigured>());
    expect(bootstrap.currentOperator, isNull);
  });

  test('401 clears session and notifies authentication', () async {
    sessions.session = fakeSession(issuedAt: clock.now());
    auth = AuthenticationController(
      googleSignInService: FakeGoogleSignInService(),
      sessionService: sessions,
      config: testConfig(),
      logger: logger,
    );
    bootstrap = OperatorBootstrapController(
      operatorService: operators,
      sessionService: sessions,
      logger: logger,
      onSessionExpired: auth.handleSessionExpired,
    );
    operators.error = const OperatorSessionExpired();

    await bootstrap.load();

    expect(bootstrap.state, isA<OperatorBootstrapSessionExpired>());
    expect(sessions.clearCallCount, greaterThan(0));
    expect(auth.state, isA<SessionExpired>());
  });

  test('signIn triggers operator bootstrap', () async {
    await auth.signIn();
    expect(auth.state, isA<Authenticated>());
    expect(operators.callCount, 1);
    expect(bootstrap.state, isA<OperatorBootstrapLoaded>());
  });

  test('signOut clears operator context', () async {
    await auth.signIn();
    expect(bootstrap.currentOperator, isNotNull);
    await auth.signOut();
    expect(bootstrap.state, isA<OperatorBootstrapUnknown>());
    expect(bootstrap.currentOperator, isNull);
  });
}

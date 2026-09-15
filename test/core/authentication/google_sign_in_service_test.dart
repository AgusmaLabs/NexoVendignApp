import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/authentication/authentication_exception.dart';
import 'package:vendingapp/core/authentication/google_authentication_result.dart';
import 'package:vendingapp/core/storage/local_storage.dart';
import 'package:vendingapp/core/storage/secure_storage.dart';

import '../../support/test_doubles.dart';

void main() {
  group('FakeGoogleSignInService contract', () {
    test('successful login returns id_token and profile fields', () async {
      final service = FakeGoogleSignInService(
        result: fakeGoogleResult(
          idToken: 'fake-google-id-token',
          email: 'a@b.com',
          displayName: 'A',
        ),
      );

      final result = await service.signIn();

      expect(result.idToken, 'fake-google-id-token');
      expect(result.email, 'a@b.com');
      expect(result.displayName, 'A');
      expect(await service.getCurrentUser(), same(result));
    });

    test('cancellation maps to AuthenticationCancelled', () async {
      final service = FakeGoogleSignInService(
        error: const AuthenticationCancelled(),
      );

      expect(service.signIn(), throwsA(isA<AuthenticationCancelled>()));
    });

    test('provider failure maps to AuthenticationFailed', () async {
      final service = FakeGoogleSignInService(
        error: const AuthenticationFailed('provider down'),
      );

      expect(service.signIn(), throwsA(isA<AuthenticationFailed>()));
    });

    test('signOut clears current user', () async {
      final service = FakeGoogleSignInService();
      await service.signIn();
      await service.signOut();
      expect(await service.getCurrentUser(), isNull);
      expect(service.signOutCallCount, 1);
    });
  });

  group('GoogleAuthenticationResult', () {
    test('rejects empty id_token', () {
      expect(
        () => GoogleAuthenticationResult(idToken: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toString does not include id_token', () {
      final result = fakeGoogleResult(idToken: 'fake-google-id-token');
      expect(result.toString(), isNot(contains('fake-google-id-token')));
      expect(result.toString(), contains('operator@example.com'));
    });
  });

  group('token security', () {
    test('successful auth does not persist id_token to storage', () async {
      final local = MemoryLocalStorage();
      final secure = MemorySecureStorage();
      final logger = RecordingAppLogger();
      final service = FakeGoogleSignInService(
        result: fakeGoogleResult(idToken: 'fake-google-id-token'),
      );

      final result = await service.signIn();
      logger.info('authentication_succeeded', context: {'email': result.email});

      expect(await local.read('id_token'), isNull);
      expect(await local.read('access_token'), isNull);
      expect(await secure.read('id_token'), isNull);
      expect(await secure.read('access_token'), isNull);
      expect(logger.hasSensitiveLeak, isFalse);
    });
  });
}

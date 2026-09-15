import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/authentication/session.dart';

void main() {
  final issuedAt = DateTime.utc(2026, 9, 15, 12);

  test('fromApiResponse derives expiresAt from issuedAt + expires_in', () {
    final session = Session.fromApiResponse({
      'access_token': 'jwt-1',
      'token_type': 'Bearer',
      'expires_in': 3600,
    }, issuedAt: issuedAt);

    expect(session.accessToken, 'jwt-1');
    expect(session.tokenType, 'Bearer');
    expect(session.expiresIn, 3600);
    expect(session.expiresAt, DateTime.utc(2026, 9, 15, 13));
  });

  test('isExpiredAt is false before expiresAt and true at/after', () {
    final session = Session(
      accessToken: 'jwt',
      tokenType: 'Bearer',
      expiresIn: 10,
      expiresAt: issuedAt.add(const Duration(seconds: 10)),
    );

    expect(
      session.isExpiredAt(issuedAt.add(const Duration(seconds: 9))),
      isFalse,
    );
    expect(
      session.isExpiredAt(issuedAt.add(const Duration(seconds: 10))),
      isTrue,
    );
    expect(
      session.isExpiredAt(issuedAt.add(const Duration(seconds: 11))),
      isTrue,
    );
  });

  test('authorizationHeader uses tokenType and accessToken', () {
    final session = Session(
      accessToken: 'secret-jwt',
      tokenType: 'Bearer',
      expiresIn: 60,
      expiresAt: issuedAt.add(const Duration(seconds: 60)),
    );

    expect(session.authorizationHeader, 'Bearer secret-jwt');
  });

  test('toString redacts accessToken', () {
    final session = Session(
      accessToken: 'secret-jwt-must-not-appear',
      tokenType: 'Bearer',
      expiresIn: 60,
      expiresAt: issuedAt.add(const Duration(seconds: 60)),
    );

    expect(session.toString(), isNot(contains('secret-jwt-must-not-appear')));
    expect(session.toString(), contains('<redacted>'));
  });

  test('round-trips through toJson/fromJson', () {
    final original = Session(
      accessToken: 'jwt-roundtrip',
      tokenType: 'Bearer',
      expiresIn: 120,
      expiresAt: issuedAt.add(const Duration(seconds: 120)),
    );

    final restored = Session.fromJson(original.toJson(), now: () => issuedAt);

    expect(restored.accessToken, original.accessToken);
    expect(restored.expiresIn, original.expiresIn);
    expect(restored.expiresAt, original.expiresAt);
  });
}

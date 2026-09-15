/// NexoVending session issued by `POST /api/v1/auth/session`.
///
/// Does not represent Google identity or Operator bootstrap (Commit 5).
final class Session {
  Session({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.expiresAt,
  }) {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError.value(
        accessToken,
        'accessToken',
        'must not be empty',
      );
    }
    if (tokenType.trim().isEmpty) {
      throw ArgumentError.value(tokenType, 'tokenType', 'must not be empty');
    }
    if (expiresIn <= 0) {
      throw ArgumentError.value(expiresIn, 'expiresIn', 'must be positive');
    }
  }

  /// Session JWT from NexoVending (sensitive).
  final String accessToken;

  /// Typically `Bearer`.
  final String tokenType;

  /// Lifetime in seconds as returned by the API.
  final int expiresIn;

  /// Absolute UTC expiration derived from [expiresIn] at issuance/restore.
  final DateTime expiresAt;

  bool isExpiredAt(DateTime instant) {
    return !instant.toUtc().isBefore(expiresAt);
  }

  /// Authorization header value (`Bearer <token>`).
  String get authorizationHeader => '$tokenType $accessToken';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'expires_at': expiresAt.toUtc().toIso8601String(),
    };
  }

  factory Session.fromJson(
    Map<String, Object?> json, {
    required DateTime Function() now,
  }) {
    final accessToken = json['access_token'] as String?;
    final tokenType = (json['token_type'] as String?) ?? 'Bearer';
    final expiresIn = json['expires_in'];
    final expiresAtRaw = json['expires_at'] as String?;

    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const FormatException('Session JSON missing access_token');
    }
    if (expiresIn is! int || expiresIn <= 0) {
      throw const FormatException('Session JSON missing valid expires_in');
    }

    final expiresAt = expiresAtRaw != null
        ? DateTime.parse(expiresAtRaw).toUtc()
        : now().toUtc().add(Duration(seconds: expiresIn));

    return Session(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
      expiresAt: expiresAt,
    );
  }

  /// Builds a [Session] from a successful `/auth/session` response body.
  factory Session.fromApiResponse(
    Map<String, Object?> json, {
    required DateTime issuedAt,
  }) {
    final accessToken = json['access_token'] as String?;
    final tokenType = (json['token_type'] as String?) ?? 'Bearer';
    final expiresIn = json['expires_in'];

    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const FormatException('Session response missing access_token');
    }
    if (expiresIn is! int || expiresIn <= 0) {
      throw const FormatException('Session response missing valid expires_in');
    }

    final issued = issuedAt.toUtc();
    return Session(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
      expiresAt: issued.add(Duration(seconds: expiresIn)),
    );
  }

  @override
  String toString() {
    return 'Session(tokenType: $tokenType, expiresIn: $expiresIn, '
        'expiresAt: $expiresAt, accessToken: <redacted>)';
  }
}

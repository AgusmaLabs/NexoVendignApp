/// Result of a successful Google identity authentication.
///
/// [idToken] is sensitive and must not be logged, shown in UI, or persisted in
/// Commit 3. A NexoVending session is **not** established here.
final class GoogleAuthenticationResult {
  GoogleAuthenticationResult({
    required this.idToken,
    this.email,
    this.displayName,
    this.photoUrl,
  }) {
    if (idToken.trim().isEmpty) {
      throw ArgumentError.value(
        idToken,
        'idToken',
        'must not be empty for a successful Google authentication',
      );
    }
  }

  /// Google OpenID Connect ID token (sensitive).
  final String idToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  @override
  String toString() {
    return 'GoogleAuthenticationResult('
        'email: $email, '
        'displayName: $displayName, '
        'photoUrl: ${photoUrl != null ? '<set>' : null}'
        ')';
  }
}

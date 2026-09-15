/// Supplies Bearer credentials for authenticated API calls.
abstract interface class SessionCredentialProvider {
  /// Returns `Bearer <token>` or `null` when no valid session exists.
  Future<String?> authorizationHeader();
}

/// Allows wiring [HttpApiClient] before [HttpSessionService] exists.
final class DelegatingSessionCredentialProvider
    implements SessionCredentialProvider {
  SessionCredentialProvider? delegate;

  @override
  Future<String?> authorizationHeader() async {
    return delegate?.authorizationHeader();
  }
}

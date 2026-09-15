import '../../../core/authentication/google_authentication_result.dart';

/// UI/application authentication state for Google identity only.
///
/// [Authenticated] means Google produced an `id_token`. It does **not** mean
/// VendingApp holds a valid NexoVending session JWT.
sealed class AuthenticationState {
  const AuthenticationState();
}

final class Unauthenticated extends AuthenticationState {
  const Unauthenticated();
}

final class Authenticating extends AuthenticationState {
  const Authenticating();
}

/// Google identity authenticated; NexoVending session is not established yet.
final class Authenticated extends AuthenticationState {
  const Authenticated(this.result);

  final GoogleAuthenticationResult result;
}

final class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure(this.message);

  /// User-facing message without tokens or SDK internals.
  final String message;
}

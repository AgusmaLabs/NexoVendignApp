import '../../../core/authentication/session.dart';

/// Application authentication/session state for the UI.
///
/// Distinguishes Google identity from a NexoVending session JWT.
sealed class AuthenticationState {
  const AuthenticationState();
}

final class Unauthenticated extends AuthenticationState {
  const Unauthenticated();
}

/// Restoring a persisted NexoVending session at startup.
final class RestoringSession extends AuthenticationState {
  const RestoringSession();
}

/// Google Sign-In in progress.
final class Authenticating extends AuthenticationState {
  const Authenticating();
}

/// Exchanging Google `id_token` for a NexoVending session.
final class CreatingSession extends AuthenticationState {
  const CreatingSession();
}

/// Valid local NexoVending session (operator bootstrap follows separately).
final class Authenticated extends AuthenticationState {
  const Authenticated(this.session);

  final Session session;
}

final class SessionExpired extends AuthenticationState {
  const SessionExpired();
}

final class SessionFailure extends AuthenticationState {
  const SessionFailure(this.message);

  /// User-facing message without tokens or SDK internals.
  final String message;
}

/// Google Sign-In failed before session exchange.
final class AuthenticationFailure extends AuthenticationState {
  const AuthenticationFailure(this.message);

  final String message;
}

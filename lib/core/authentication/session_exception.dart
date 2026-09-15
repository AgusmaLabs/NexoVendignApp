import '../errors/app_exception.dart';

/// Failures while creating or restoring a NexoVending session.
sealed class SessionException extends AppException {
  const SessionException(super.message, {super.cause});
}

/// `POST /auth/session` returned 401 / invalid credentials.
final class SessionAuthenticationFailed extends SessionException {
  const SessionAuthenticationFailed({
    String message = 'No se pudo autenticar la sesión con NexoVending.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// `POST /auth/session` returned 403 (operator not provisioned / denied).
final class SessionAccessDenied extends SessionException {
  const SessionAccessDenied({
    String message = 'No tienes acceso a este tenant en NexoVending.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Transport / timeout / unexpected network failure during session creation.
final class SessionNetworkFailure extends SessionException {
  const SessionNetworkFailure({
    String message = 'No se pudo contactar NexoVending. Revisa tu conexión.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Malformed session response or persisted payload.
final class SessionInvalidResponse extends SessionException {
  const SessionInvalidResponse({
    String message = 'La respuesta de sesión no es válida.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Local session JWT expired.
final class SessionExpiredException extends SessionException {
  const SessionExpiredException({
    String message = 'La sesión ha expirado. Vuelve a iniciar sesión.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Unexpected session failure.
final class SessionUnknownError extends SessionException {
  const SessionUnknownError({
    String message = 'No se pudo iniciar la sesión. Inténtalo de nuevo.',
    Object? cause,
  }) : super(message, cause: cause);
}

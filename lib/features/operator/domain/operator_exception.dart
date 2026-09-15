import '../../../core/errors/app_exception.dart';

/// Failures while bootstrapping the Vending operator.
sealed class OperatorException extends AppException {
  const OperatorException(super.message, {super.cause});
}

/// Session no longer valid (`401`).
final class OperatorSessionExpired extends OperatorException {
  const OperatorSessionExpired({
    String message = 'La sesión ha expirado. Vuelve a iniciar sesión.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Access denied (`403` without OPERATOR_NOT_FOUND).
final class OperatorAccessDenied extends OperatorException {
  const OperatorAccessDenied({
    String message = 'No tienes acceso a la aplicación de operaciones.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Authenticated identity has no Vending operator (`403 OPERATOR_NOT_FOUND` / `404`).
final class OperatorNotConfigured extends OperatorException {
  const OperatorNotConfigured({
    String message = 'Tu usuario todavía no está configurado como operador.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Transport / timeout while loading the operator.
final class OperatorNetworkFailure extends OperatorException {
  const OperatorNetworkFailure({
    String message = 'No fue posible cargar tu información.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Malformed `/operators/me` payload.
final class OperatorInvalidResponse extends OperatorException {
  const OperatorInvalidResponse({
    String message = 'La respuesta del operador no es válida.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Unexpected operator bootstrap failure.
final class OperatorUnknownError extends OperatorException {
  const OperatorUnknownError({
    String message = 'No fue posible cargar tu información.',
    Object? cause,
  }) : super(message, cause: cause);
}

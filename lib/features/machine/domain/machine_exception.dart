import '../../../core/errors/app_exception.dart';

/// Failures while identifying a Vending machine.
sealed class MachineException extends AppException {
  const MachineException(super.message, {super.cause});
}

/// Empty / whitespace identifier (no HTTP call).
final class MachineIdentifierInvalid extends MachineException {
  const MachineIdentifierInvalid({
    String message = 'Ingresa un identificador de máquina.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Session no longer valid (`401`).
final class MachineSessionExpired extends MachineException {
  const MachineSessionExpired({
    String message = 'La sesión ha expirado. Vuelve a iniciar sesión.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Operator cannot access the machine (`403`).
final class MachineAccessDenied extends MachineException {
  const MachineAccessDenied({
    String message = 'No tienes acceso a esta máquina.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Machine could not be resolved (`404`).
final class MachineNotFound extends MachineException {
  const MachineNotFound({
    String message = 'Máquina no encontrada.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Request validation failure (`422`).
final class MachineValidationFailed extends MachineException {
  const MachineValidationFailed({
    String message = 'El identificador de máquina no es válido.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Transport / timeout while resolving.
final class MachineNetworkFailure extends MachineException {
  const MachineNetworkFailure({
    String message = 'No fue posible cargar la máquina en este momento.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Malformed resolve response.
final class MachineInvalidResponse extends MachineException {
  const MachineInvalidResponse({
    String message = 'La respuesta de la máquina no es válida.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Unexpected resolve failure (including 5xx).
final class MachineUnknownError extends MachineException {
  const MachineUnknownError({
    String message = 'No fue posible cargar la máquina en este momento.',
    Object? cause,
  }) : super(message, cause: cause);
}

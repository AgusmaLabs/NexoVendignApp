import '../../../core/errors/app_exception.dart';

/// Failures while creating a replenishment session.
sealed class ReplenishmentException extends AppException {
  const ReplenishmentException(super.message, {super.cause});
}

/// Missing machine context (no HTTP).
final class ReplenishmentNoMachine extends ReplenishmentException {
  const ReplenishmentNoMachine({
    String message = 'Identifica una máquina antes de iniciar la reposición.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Missing operator context (no HTTP).
final class ReplenishmentNoOperator extends ReplenishmentException {
  const ReplenishmentNoOperator({
    String message = 'No hay un operador Vending válido.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Empty / invalid machine id (no HTTP).
final class ReplenishmentMachineInvalid extends ReplenishmentException {
  const ReplenishmentMachineInvalid({
    String message = 'Falta el identificador de la máquina.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Session no longer valid (`401`).
final class ReplenishmentSessionExpired extends ReplenishmentException {
  const ReplenishmentSessionExpired({
    String message = 'La sesión ha expirado. Vuelve a iniciar sesión.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Operator cannot replenish this machine (`403`).
final class ReplenishmentAccessDenied extends ReplenishmentException {
  const ReplenishmentAccessDenied({
    String message =
        'No tienes permiso para reponer esta máquina.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Machine no longer available (`404`).
final class ReplenishmentMachineUnavailable extends ReplenishmentException {
  const ReplenishmentMachineUnavailable({
    String message = 'La máquina ya no está disponible.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Conflict such as an existing in-progress replenishment (`409`).
final class ReplenishmentConflict extends ReplenishmentException {
  const ReplenishmentConflict({
    String message =
        'Ya existe una reposición en curso para esta máquina.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Request validation failure (`422`).
final class ReplenishmentValidationFailed extends ReplenishmentException {
  const ReplenishmentValidationFailed({
    String message = 'La solicitud de reposición no es válida.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Device location could not be obtained.
final class ReplenishmentLocationUnavailable extends ReplenishmentException {
  const ReplenishmentLocationUnavailable({
    String message = 'No fue posible obtener la ubicación GPS.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Transport / timeout.
final class ReplenishmentNetworkFailure extends ReplenishmentException {
  const ReplenishmentNetworkFailure({
    String message = 'No fue posible iniciar la reposición en este momento.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Malformed create response.
final class ReplenishmentInvalidResponse extends ReplenishmentException {
  const ReplenishmentInvalidResponse({
    String message = 'La respuesta de reposición no es válida.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Unexpected failure (including 5xx).
final class ReplenishmentUnknownError extends ReplenishmentException {
  const ReplenishmentUnknownError({
    String message = 'No fue posible iniciar la reposición en este momento.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Missing active replenishment for add-line (no HTTP).
final class ReplenishmentNoActiveSession extends ReplenishmentException {
  const ReplenishmentNoActiveSession({
    String message = 'Inicia una reposición antes de agregar productos.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Local quantity validation failed (no HTTP).
final class ReplenishmentQuantityInvalid extends ReplenishmentException {
  const ReplenishmentQuantityInvalid({
    String message = 'La cantidad debe ser un entero mayor que cero.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Slot required by contract but missing (no HTTP).
final class ReplenishmentSlotRequired extends ReplenishmentException {
  const ReplenishmentSlotRequired({
    String message = 'Selecciona un slot para agregar la línea.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Rate limited (`429`).
final class ReplenishmentRateLimited extends ReplenishmentException {
  const ReplenishmentRateLimited({
    String message = 'Demasiadas operaciones. Intenta de nuevo en un momento.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Replenishment / product / slot not found (`404`) during add-line.
final class ReplenishmentResourceNotFound extends ReplenishmentException {
  const ReplenishmentResourceNotFound({
    String message = 'No se encontró la reposición, el producto o el slot.',
    Object? cause,
  }) : super(message, cause: cause);
}

import '../../../core/errors/app_exception.dart';

/// Failures while looking up a product by barcode.
sealed class ProductException extends AppException {
  const ProductException(super.message, {super.cause});
}

/// Empty / invalid barcode format (no HTTP or 422).
final class ProductBarcodeInvalid extends ProductException {
  const ProductBarcodeInvalid({
    String message = 'El código de barras no es válido.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// No active replenishment context (no HTTP).
final class ProductNoReplenishment extends ProductException {
  const ProductNoReplenishment({
    String message =
        'Inicia una reposición antes de escanear productos.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Session no longer valid (`401`).
final class ProductSessionExpired extends ProductException {
  const ProductSessionExpired({
    String message = 'La sesión ha expirado. Vuelve a iniciar sesión.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Operator cannot look up products (`403`).
final class ProductAccessDenied extends ProductException {
  const ProductAccessDenied({
    String message = 'No tienes acceso al catálogo de productos.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Barcode not in tenant catalog (`404`).
final class ProductNotFound extends ProductException {
  const ProductNotFound({
    String message = 'Producto no encontrado',
    Object? cause,
    this.barcode,
  }) : super(message, cause: cause);

  final String? barcode;
}

/// Rate limited (`429`).
final class ProductRateLimited extends ProductException {
  const ProductRateLimited({
    String message = 'Demasiadas consultas. Intenta de nuevo en un momento.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Transport / timeout.
final class ProductNetworkFailure extends ProductException {
  const ProductNetworkFailure({
    String message = 'No fue posible consultar el producto en este momento.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Malformed lookup response.
final class ProductInvalidResponse extends ProductException {
  const ProductInvalidResponse({
    String message = 'La respuesta del producto no es válida.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Unexpected failure (including 5xx).
final class ProductUnknownError extends ProductException {
  const ProductUnknownError({
    String message = 'No fue posible consultar el producto en este momento.',
    Object? cause,
  }) : super(message, cause: cause);
}

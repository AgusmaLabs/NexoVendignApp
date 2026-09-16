/// Field observation when catalog identity is unknown (not a [Product]).
final class UnresolvedProduct {
  UnresolvedProduct({
    required String manualDescription,
    String? barcode,
  }) : manualDescription = ManualDescription.normalize(manualDescription),
       barcode = _normalizeOptionalBarcode(barcode) {
    ManualDescription.validate(this.manualDescription);
  }

  final String manualDescription;
  final String? barcode;

  static String? _normalizeOptionalBarcode(String? barcode) {
    if (barcode == null) {
      return null;
    }
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(barcode, 'barcode', 'must not be empty when set');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) {
    return other is UnresolvedProduct &&
        other.manualDescription == manualDescription &&
        other.barcode == barcode;
  }

  @override
  int get hashCode => Object.hash(manualDescription, barcode);

  @override
  String toString() {
    return 'UnresolvedProduct(barcode: $barcode, '
        'manualDescription: $manualDescription)';
  }
}

/// Client-side validation for PENDING `manual_description` (trim + non-empty).
abstract final class ManualDescription {
  /// Soft UX cap; backend accepts Text with no short maxLength.
  static const int maxLength = 500;

  static String normalize(String raw) => raw.trim();

  static void validate(String normalized) {
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        normalized,
        'manualDescription',
        'must not be empty',
      );
    }
    if (normalized.length > maxLength) {
      throw ArgumentError.value(
        normalized,
        'manualDescription',
        'must be at most $maxLength characters',
      );
    }
  }

  static String? validationMessage(String raw) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) {
      return 'Ingresa una descripción del producto.';
    }
    if (normalized.length > maxLength) {
      return 'La descripción no puede superar $maxLength caracteres.';
    }
    return null;
  }
}

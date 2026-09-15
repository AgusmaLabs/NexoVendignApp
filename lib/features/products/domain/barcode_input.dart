/// Normalizes and validates barcode strings for product lookup.
abstract final class BarcodeInput {
  /// Trims accidental whitespace. Does not invent commercial validity.
  static String normalize(String raw) => raw.trim();

  /// Client-side format gate only. Backend decides catalog membership.
  static bool isValidFormat(String barcode) {
    if (barcode.isEmpty) {
      return false;
    }
    if (barcode.length < 4 || barcode.length > 64) {
      return false;
    }
    return RegExp(r'^[0-9A-Za-z\-]+$').hasMatch(barcode);
  }
}

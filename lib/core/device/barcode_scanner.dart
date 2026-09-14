/// Abstraction over barcode / QR capture hardware.
abstract interface class BarcodeScanner {
  /// Returns the scanned value, or `null` when the user cancels.
  Future<String?> scan();
}

/// Placeholder scanner until camera integration is implemented.
final class UnsupportedBarcodeScanner implements BarcodeScanner {
  const UnsupportedBarcodeScanner();

  @override
  Future<String?> scan() {
    throw UnsupportedError('BarcodeScanner is not implemented yet');
  }
}

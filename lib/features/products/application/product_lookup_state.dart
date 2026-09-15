import '../domain/product.dart';

/// UI state for barcode product lookup.
sealed class ProductLookupState {
  const ProductLookupState();
}

final class ProductLookupIdle extends ProductLookupState {
  const ProductLookupIdle();
}

final class ProductLookupScanning extends ProductLookupState {
  const ProductLookupScanning();
}

final class ProductLookupLookingUp extends ProductLookupState {
  const ProductLookupLookingUp(this.barcode);

  final String barcode;
}

final class ProductLookupFound extends ProductLookupState {
  const ProductLookupFound({required this.barcode, required this.product});

  final String barcode;
  final Product product;
}

final class ProductLookupNotFound extends ProductLookupState {
  const ProductLookupNotFound(this.barcode);

  final String barcode;
}

final class ProductLookupFailure extends ProductLookupState {
  const ProductLookupFailure(this.message, {this.canRetry = true, this.barcode});

  final String message;
  final bool canRetry;
  final String? barcode;
}

final class ProductLookupNoReplenishment extends ProductLookupState {
  const ProductLookupNoReplenishment();
}

final class ProductLookupSessionExpired extends ProductLookupState {
  const ProductLookupSessionExpired();
}

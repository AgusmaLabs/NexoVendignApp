import '../domain/product.dart';
import '../domain/unresolved_product.dart';

/// UI states for barcode lookup + unresolved-product cascade.
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
  const ProductLookupFound({
    required this.barcode,
    required this.product,
  });

  final String barcode;
  final Product product;
}

final class ProductLookupNotFound extends ProductLookupState {
  const ProductLookupNotFound(this.barcode);

  final String barcode;
}

final class ProductLookupSearchingByDescription extends ProductLookupState {
  const ProductLookupSearchingByDescription({
    required this.query,
    this.barcode,
  });

  final String query;
  final String? barcode;
}

final class ProductLookupSearchResults extends ProductLookupState {
  const ProductLookupSearchResults({
    required this.query,
    required this.products,
    this.barcode,
  });

  final String query;
  final List<Product> products;
  final String? barcode;
}

final class ProductLookupSearchEmpty extends ProductLookupState {
  const ProductLookupSearchEmpty({
    required this.query,
    this.barcode,
  });

  final String query;
  final String? barcode;
}

final class ProductLookupEnteringManualDescription extends ProductLookupState {
  const ProductLookupEnteringManualDescription({
    this.barcode,
    this.draftDescription = '',
  });

  final String? barcode;
  final String draftDescription;
}

final class ProductLookupUnresolvedReady extends ProductLookupState {
  const ProductLookupUnresolvedReady(this.unresolved);

  final UnresolvedProduct unresolved;
}

final class ProductLookupPendingLineSubmitted extends ProductLookupState {
  const ProductLookupPendingLineSubmitted(this.unresolved);

  final UnresolvedProduct unresolved;
}

final class ProductLookupNoReplenishment extends ProductLookupState {
  const ProductLookupNoReplenishment();
}

final class ProductLookupSessionExpired extends ProductLookupState {
  const ProductLookupSessionExpired();
}

final class ProductLookupFailure extends ProductLookupState {
  const ProductLookupFailure(
    this.message, {
    this.canRetry = true,
    this.barcode,
  });

  final String message;
  final bool canRetry;
  final String? barcode;
}

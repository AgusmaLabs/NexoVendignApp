import 'product.dart';

/// Looks up catalog products by barcode via NexoVending.
abstract interface class ProductLookupService {
  /// `GET /api/v1/products/barcode/{barcode}` using the session JWT.
  Future<Product> lookupByBarcode(String barcode);
}

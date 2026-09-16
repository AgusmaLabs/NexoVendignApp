import 'product.dart';

/// Looks up catalog products via NexoVending (barcode + text search).
abstract interface class ProductLookupService {
  /// `GET /api/v1/products/barcode/{barcode}` using the session JWT.
  Future<Product> lookupByBarcode(String barcode);

  /// `GET /api/v1/products?q=&limit=&offset=` — empty list is success.
  Future<List<Product>> searchByText(
    String query, {
    int limit = 20,
    int offset = 0,
  });
}

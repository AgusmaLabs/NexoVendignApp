import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_exception.dart';
import '../domain/barcode_input.dart';
import '../domain/product.dart';
import '../domain/product_exception.dart';
import '../domain/product_lookup_service.dart';

/// `ProductLookupService` backed by `GET /api/v1/products/barcode/{barcode}`.
final class ApiProductLookupService implements ProductLookupService {
  ApiProductLookupService({required this.apiClient, required this.logger});

  final ApiClient apiClient;
  final AppLogger logger;

  @override
  Future<Product> lookupByBarcode(String barcode) async {
    final normalized = BarcodeInput.normalize(barcode);
    if (!BarcodeInput.isValidFormat(normalized)) {
      throw const ProductBarcodeInvalid();
    }

    logger.info('product_lookup_started');
    try {
      final encoded = Uri.encodeComponent(normalized);
      final response = await apiClient.get(
        '/api/v1/products/barcode/$encoded',
        authenticated: true,
      );
      final decoded = _decodeJsonObject(response.body);
      final product = Product.fromJson(decoded);
      logger.info(
        'product_lookup_succeeded',
        context: {
          'productId': product.productId,
          'barcode': product.barcode,
        },
      );
      return product;
    } on ProductException {
      rethrow;
    } on HttpException catch (error) {
      throw _mapHttp(error, barcode: normalized);
    } on TimeoutException catch (error) {
      throw ProductNetworkFailure(cause: error);
    } on NetworkException catch (error) {
      throw ProductNetworkFailure(cause: error);
    } on FormatException catch (error) {
      throw ProductInvalidResponse(cause: error);
    } on SerializationException catch (error) {
      throw ProductInvalidResponse(cause: error);
    } catch (error) {
      throw ProductUnknownError(cause: error);
    }
  }

  Map<String, Object?> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Product response is not a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  ProductException _mapHttp(HttpException error, {required String barcode}) {
    return switch (error.statusCode) {
      401 => ProductSessionExpired(cause: error),
      403 => ProductAccessDenied(cause: error),
      404 => ProductNotFound(cause: error, barcode: barcode),
      422 => ProductBarcodeInvalid(cause: error),
      429 => ProductRateLimited(cause: error),
      _ => ProductUnknownError(cause: error),
    };
  }
}

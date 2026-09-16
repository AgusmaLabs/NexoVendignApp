import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_exception.dart';
import '../domain/barcode_input.dart';
import '../domain/product.dart';
import '../domain/product_exception.dart';
import '../domain/product_lookup_service.dart';

/// `ProductLookupService` backed by barcode lookup + catalog text search.
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

  @override
  Future<List<Product>> searchByText(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const ProductSearchQueryInvalid();
    }
    if (limit < 1 || limit > 50 || offset < 0) {
      throw const ProductSearchQueryInvalid(
        message: 'Parámetros de búsqueda inválidos.',
      );
    }

    logger.info('product_search_started');
    try {
      final response = await apiClient.get(
        '/api/v1/products',
        authenticated: true,
        queryParameters: <String, String>{
          'q': trimmed,
          'limit': '$limit',
          'offset': '$offset',
        },
      );
      final products = _decodeProductList(response.body);
      logger.info(
        'product_search_succeeded',
        context: {'count': products.length},
      );
      return products;
    } on ProductException {
      rethrow;
    } on HttpException catch (error) {
      throw _mapSearchHttp(error);
    } on TimeoutException catch (error) {
      throw ProductNetworkFailure(
        message: 'No fue posible buscar productos en este momento.',
        cause: error,
      );
    } on NetworkException catch (error) {
      throw ProductNetworkFailure(
        message: 'No fue posible buscar productos en este momento.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw ProductInvalidResponse(cause: error);
    } on SerializationException catch (error) {
      throw ProductInvalidResponse(cause: error);
    } catch (error) {
      throw ProductUnknownError(
        message: 'No fue posible buscar productos en este momento.',
        cause: error,
      );
    }
  }

  List<Product> _decodeProductList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException('Product search response is not a JSON array');
    }
    return decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('Product search item is not a JSON object');
      }
      return Product.fromJson(Map<String, Object?>.from(item));
    }).toList(growable: false);
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

  ProductException _mapSearchHttp(HttpException error) {
    return switch (error.statusCode) {
      401 => ProductSessionExpired(cause: error),
      403 => ProductAccessDenied(
        message: 'No tienes acceso al catálogo de productos.',
        cause: error,
      ),
      422 => ProductSearchQueryInvalid(cause: error),
      429 => ProductRateLimited(cause: error),
      _ => ProductUnknownError(
        message: 'No fue posible buscar productos en este momento.',
        cause: error,
      ),
    };
  }
}

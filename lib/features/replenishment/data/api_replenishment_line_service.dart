import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_exception.dart';
import '../domain/replenishment.dart';
import '../domain/replenishment_exception.dart';
import '../domain/replenishment_line_service.dart';

/// `ReplenishmentLineService` backed by
/// `POST /api/v1/replenishments/{id}/lines`.
final class ApiReplenishmentLineService implements ReplenishmentLineService {
  ApiReplenishmentLineService({required this.apiClient, required this.logger});

  final ApiClient apiClient;
  final AppLogger logger;

  @override
  Future<Replenishment> addLine({
    required String replenishmentId,
    required String productId,
    required int quantity,
    required String slotId,
    required String idempotencyKey,
    String? replacementReason,
  }) async {
    final repId = replenishmentId.trim();
    final prodId = productId.trim();
    final slot = slotId.trim();
    final key = idempotencyKey.trim();

    if (repId.isEmpty) {
      throw const ReplenishmentValidationFailed(
        message: 'Falta el identificador de la reposición.',
      );
    }
    if (prodId.isEmpty) {
      throw const ReplenishmentValidationFailed(
        message: 'Falta el identificador del producto.',
      );
    }
    if (slot.isEmpty) {
      throw const ReplenishmentSlotRequired();
    }
    if (quantity <= 0) {
      throw const ReplenishmentQuantityInvalid();
    }
    if (key.isEmpty) {
      throw const ReplenishmentValidationFailed(
        message: 'Falta la clave de idempotencia.',
      );
    }

    logger.info('replenishment_add_line_started');
    try {
      final body = <String, Object?>{
        'slot_id': slot,
        'quantity': quantity,
        'product_id': prodId,
        if (replacementReason != null && replacementReason.trim().isNotEmpty)
          'replacement_reason': replacementReason.trim(),
      };
      final response = await apiClient.post(
        '/api/v1/replenishments/$repId/lines',
        authenticated: true,
        body: body,
        headers: <String, String>{'Idempotency-Key': key},
      );
      final decoded = _decodeJsonObject(response.body);
      final replenishment = Replenishment.fromJson(decoded);
      logger.info(
        'replenishment_add_line_succeeded',
        context: {
          'replenishmentId': replenishment.id,
          'lineCount': replenishment.lines.length,
          'status': replenishment.status,
        },
      );
      return replenishment;
    } on ReplenishmentException {
      rethrow;
    } on HttpException catch (error) {
      throw _mapHttp(error);
    } on TimeoutException catch (error) {
      throw ReplenishmentNetworkFailure(
        message: 'No fue posible agregar la línea en este momento.',
        cause: error,
      );
    } on NetworkException catch (error) {
      throw ReplenishmentNetworkFailure(
        message: 'No fue posible agregar la línea en este momento.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw ReplenishmentInvalidResponse(cause: error);
    } on SerializationException catch (error) {
      throw ReplenishmentInvalidResponse(cause: error);
    } catch (error) {
      throw ReplenishmentUnknownError(
        message: 'No fue posible agregar la línea en este momento.',
        cause: error,
      );
    }
  }

  Map<String, Object?> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException(
        'Replenishment line response is not a JSON object',
      );
    }
    return Map<String, Object?>.from(decoded);
  }

  ReplenishmentException _mapHttp(HttpException error) {
    return switch (error.statusCode) {
      401 => ReplenishmentSessionExpired(cause: error),
      403 => ReplenishmentAccessDenied(
        message: 'No tienes permiso para agregar líneas a esta reposición.',
        cause: error,
      ),
      404 => ReplenishmentResourceNotFound(cause: error),
      409 => ReplenishmentConflict(
        message: 'No fue posible agregar la línea por un conflicto de estado.',
        cause: error,
      ),
      422 => ReplenishmentValidationFailed(
        message: 'La línea de reposición no es válida.',
        cause: error,
      ),
      429 => ReplenishmentRateLimited(cause: error),
      _ => ReplenishmentUnknownError(
        message: 'No fue posible agregar la línea en este momento.',
        cause: error,
      ),
    };
  }
}

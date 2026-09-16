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
    required int quantity,
    required String slotId,
    required String idempotencyKey,
    String? productId,
    String? barcode,
    String? manualDescription,
    String? replacementReason,
  }) async {
    final repId = replenishmentId.trim();
    final slot = slotId.trim();
    final key = idempotencyKey.trim();
    final prodId = productId?.trim();
    final manual = manualDescription?.trim();
    final scanned = barcode?.trim();

    if (repId.isEmpty) {
      throw const ReplenishmentValidationFailed(
        message: 'Falta el identificador de la reposición.',
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

    final isPending = prodId == null || prodId.isEmpty;
    if (isPending) {
      if (manual == null || manual.isEmpty) {
        throw const ReplenishmentValidationFailed(
          message: 'Ingresa una descripción del producto.',
        );
      }
      if (replacementReason != null && replacementReason.trim().isNotEmpty) {
        throw const ReplenishmentValidationFailed(
          message: 'Una línea pendiente no admite motivo de reemplazo.',
        );
      }
    }

    logger.info('replenishment_add_line_started');
    try {
      final body = <String, Object?>{
        'slot_id': slot,
        'quantity': quantity,
        if (!isPending) 'product_id': prodId,
        if (isPending) 'product_id': null,
        if (isPending) 'manual_description': manual,
        if (scanned != null && scanned.isNotEmpty) 'barcode': scanned,
        if (!isPending &&
            replacementReason != null &&
            replacementReason.trim().isNotEmpty)
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
          'pending': isPending,
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

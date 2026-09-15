import 'dart:convert';

import '../../../core/device/location_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_exception.dart';
import '../domain/replenishment.dart';
import '../domain/replenishment_exception.dart';
import '../domain/replenishment_service.dart';

/// `ReplenishmentService` backed by `POST /api/v1/replenishments`.
final class ApiReplenishmentService implements ReplenishmentService {
  ApiReplenishmentService({required this.apiClient, required this.logger});

  final ApiClient apiClient;
  final AppLogger logger;

  @override
  Future<Replenishment> createReplenishment({
    required String machineId,
    required DeviceLocation location,
    required String idempotencyKey,
  }) async {
    final trimmed = machineId.trim();
    if (trimmed.isEmpty) {
      throw const ReplenishmentMachineInvalid();
    }
    final key = idempotencyKey.trim();
    if (key.isEmpty) {
      throw const ReplenishmentValidationFailed(
        message: 'Falta la clave de idempotencia.',
      );
    }

    logger.info('replenishment_create_started');
    try {
      final body = <String, Object?>{
        'machine_id': trimmed,
        'location': <String, Object?>{
          'latitude': location.latitude,
          'longitude': location.longitude,
          if (location.accuracyMeters != null)
            'accuracy': location.accuracyMeters,
        },
      };
      final response = await apiClient.post(
        '/api/v1/replenishments',
        authenticated: true,
        body: body,
        headers: <String, String>{'Idempotency-Key': key},
      );
      final decoded = _decodeJsonObject(response.body);
      final replenishment = Replenishment.fromJson(decoded);
      logger.info(
        'replenishment_create_succeeded',
        context: {
          'replenishmentId': replenishment.id,
          'machineId': replenishment.machineId,
          'status': replenishment.status,
        },
      );
      return replenishment;
    } on ReplenishmentException {
      rethrow;
    } on HttpException catch (error) {
      throw _mapHttp(error);
    } on TimeoutException catch (error) {
      throw ReplenishmentNetworkFailure(cause: error);
    } on NetworkException catch (error) {
      throw ReplenishmentNetworkFailure(cause: error);
    } on FormatException catch (error) {
      throw ReplenishmentInvalidResponse(cause: error);
    } on SerializationException catch (error) {
      throw ReplenishmentInvalidResponse(cause: error);
    } catch (error) {
      throw ReplenishmentUnknownError(cause: error);
    }
  }

  Map<String, Object?> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException(
        'Replenishment response is not a JSON object',
      );
    }
    return Map<String, Object?>.from(decoded);
  }

  ReplenishmentException _mapHttp(HttpException error) {
    return switch (error.statusCode) {
      401 => ReplenishmentSessionExpired(cause: error),
      403 => ReplenishmentAccessDenied(cause: error),
      404 => ReplenishmentMachineUnavailable(cause: error),
      409 => ReplenishmentConflict(cause: error),
      422 => ReplenishmentValidationFailed(cause: error),
      _ => ReplenishmentUnknownError(cause: error),
    };
  }
}

import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_exception.dart';
import '../domain/machine_exception.dart';
import '../domain/machine_slot.dart';
import '../domain/machine_slot_service.dart';

/// `MachineSlotService` backed by `GET /api/v1/machines/{id}/slots`.
final class ApiMachineSlotService implements MachineSlotService {
  ApiMachineSlotService({required this.apiClient, required this.logger});

  final ApiClient apiClient;
  final AppLogger logger;

  @override
  Future<List<MachineSlot>> getSlots(String machineId) async {
    final trimmed = machineId.trim();
    if (trimmed.isEmpty) {
      throw const MachineIdentifierInvalid(
        message: 'Falta el identificador de la máquina.',
      );
    }

    logger.info('machine_slots_started');
    try {
      final response = await apiClient.get(
        '/api/v1/machines/$trimmed/slots',
        authenticated: true,
      );
      final decoded = _decodeJsonObject(response.body);
      final rawSlots = decoded['slots'];
      if (rawSlots is! List) {
        throw const FormatException('Machine slots response missing slots list');
      }
      final slots = rawSlots.map((item) {
        if (item is! Map) {
          throw const FormatException('Machine slot entry is not an object');
        }
        return MachineSlot.fromJson(Map<String, Object?>.from(item));
      }).toList();
      // Preserve backend order; do not re-sort by id.
      logger.info(
        'machine_slots_succeeded',
        context: {'count': slots.length},
      );
      return slots;
    } on MachineException {
      rethrow;
    } on HttpException catch (error) {
      throw _mapHttp(error);
    } on TimeoutException catch (error) {
      throw MachineNetworkFailure(
        message: 'No fue posible cargar la configuración de la máquina.',
        cause: error,
      );
    } on NetworkException catch (error) {
      throw MachineNetworkFailure(
        message: 'No fue posible cargar la configuración de la máquina.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw MachineInvalidResponse(cause: error);
    } on SerializationException catch (error) {
      throw MachineInvalidResponse(cause: error);
    } catch (error) {
      throw MachineUnknownError(
        message: 'La configuración de la máquina no está disponible temporalmente.',
        cause: error,
      );
    }
  }

  Map<String, Object?> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Machine slots response is not a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  MachineException _mapHttp(HttpException error) {
    return switch (error.statusCode) {
      401 => MachineSessionExpired(cause: error),
      403 => MachineAccessDenied(cause: error),
      404 => MachineNotFound(cause: error),
      422 => MachineValidationFailed(cause: error),
      _ => MachineUnknownError(
        message:
            'La configuración de la máquina no está disponible temporalmente.',
        cause: error,
      ),
    };
  }
}

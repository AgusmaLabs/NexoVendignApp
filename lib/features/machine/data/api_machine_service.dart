import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_exception.dart';
import '../domain/machine.dart';
import '../domain/machine_exception.dart';
import '../domain/machine_service.dart';

/// `MachineService` backed by `GET /api/v1/machines/resolve`.
final class ApiMachineService implements MachineService {
  ApiMachineService({
    required this.apiClient,
    required this.logger,
    this.path = '/api/v1/machines/resolve',
  });

  final ApiClient apiClient;
  final AppLogger logger;
  final String path;

  @override
  Future<Machine> resolveMachine(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      throw const MachineIdentifierInvalid();
    }

    final type = detectIdentifierType(trimmed);
    logger.info(
      'machine_resolve_started',
      context: {'identifierType': type.apiValue},
    );

    try {
      final response = await apiClient.get(
        path,
        authenticated: true,
        queryParameters: <String, String>{
          'identifier_type': type.apiValue,
          'value': trimmed,
        },
      );
      final decoded = _decodeJsonObject(response.body);
      final machine = Machine.fromJson(decoded);
      logger.info(
        'machine_resolve_succeeded',
        context: {'machineId': machine.machineId, 'status': machine.status},
      );
      return machine;
    } on MachineException {
      rethrow;
    } on HttpException catch (error) {
      throw _mapHttp(error);
    } on TimeoutException catch (error) {
      throw MachineNetworkFailure(cause: error);
    } on NetworkException catch (error) {
      throw MachineNetworkFailure(cause: error);
    } on FormatException catch (error) {
      throw MachineInvalidResponse(cause: error);
    } on SerializationException catch (error) {
      throw MachineInvalidResponse(cause: error);
    } catch (error) {
      throw MachineUnknownError(cause: error);
    }
  }

  Map<String, Object?> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Machine response is not a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  MachineException _mapHttp(HttpException error) {
    return switch (error.statusCode) {
      401 => MachineSessionExpired(cause: error),
      403 => MachineAccessDenied(cause: error),
      404 => MachineNotFound(cause: error),
      422 => MachineValidationFailed(cause: error),
      _ => MachineUnknownError(cause: error),
    };
  }
}

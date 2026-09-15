import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_exception.dart';
import '../domain/operator.dart';
import '../domain/operator_exception.dart';
import '../domain/operator_service.dart';

/// `OperatorService` backed by `GET /api/v1/operators/me`.
final class ApiOperatorService implements OperatorService {
  ApiOperatorService({
    required this.apiClient,
    required this.logger,
    this.path = '/api/v1/operators/me',
  });

  final ApiClient apiClient;
  final AppLogger logger;
  final String path;

  @override
  Future<Operator> getCurrentOperator() async {
    logger.info('operator_bootstrap_started');
    try {
      final response = await apiClient.get(path, authenticated: true);
      final decoded = _decodeJsonObject(response.body);
      final operator = Operator.fromJson(decoded);
      logger.info(
        'operator_bootstrap_succeeded',
        context: {
          'operatorId': operator.operatorId,
          'role': operator.role,
          'status': operator.status,
        },
      );
      return operator;
    } on OperatorException {
      rethrow;
    } on HttpException catch (error) {
      throw _mapHttp(error);
    } on TimeoutException catch (error) {
      throw OperatorNetworkFailure(cause: error);
    } on NetworkException catch (error) {
      throw OperatorNetworkFailure(cause: error);
    } on FormatException catch (error) {
      throw OperatorInvalidResponse(cause: error);
    } on SerializationException catch (error) {
      throw OperatorInvalidResponse(cause: error);
    } catch (error) {
      throw OperatorUnknownError(cause: error);
    }
  }

  Map<String, Object?> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Operator response is not a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  OperatorException _mapHttp(HttpException error) {
    final code = _errorCode(error.body);
    return switch (error.statusCode) {
      401 => OperatorSessionExpired(cause: error),
      403 when code == 'OPERATOR_NOT_FOUND' => OperatorNotConfigured(
        cause: error,
      ),
      403 => OperatorAccessDenied(cause: error),
      404 => OperatorNotConfigured(cause: error),
      _ => OperatorUnknownError(cause: error),
    };
  }

  String? _errorCode(String? body) {
    if (body == null || body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['code'] is String) {
        return decoded['code'] as String;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

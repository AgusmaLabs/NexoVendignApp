import 'operator.dart';

/// Resolves the authenticated Vending operator from NexoVending.
abstract interface class OperatorService {
  /// `GET /api/v1/operators/me` using the session JWT via ApiClient.
  Future<Operator> getCurrentOperator();
}

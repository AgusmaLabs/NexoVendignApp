import '../../../core/device/location_service.dart';
import 'replenishment.dart';

/// Creates replenishment sessions via NexoVending.
abstract interface class ReplenishmentService {
  /// `POST /api/v1/replenishments` using the session JWT.
  Future<Replenishment> createReplenishment({
    required String machineId,
    required DeviceLocation location,
    required String idempotencyKey,
  });
}

import 'replenishment.dart';

/// Adds lines to an in-progress replenishment via NexoVending.
abstract interface class ReplenishmentLineService {
  /// `POST /api/v1/replenishments/{id}/lines` → updated `ReplenishmentOut`.
  ///
  /// Current contract requires [slotId].
  Future<Replenishment> addLine({
    required String replenishmentId,
    required String productId,
    required int quantity,
    required String slotId,
    required String idempotencyKey,
    String? replacementReason,
  });
}

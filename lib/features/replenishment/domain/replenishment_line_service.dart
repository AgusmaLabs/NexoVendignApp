import 'replenishment.dart';

/// Adds lines to an in-progress replenishment via NexoVending.
abstract interface class ReplenishmentLineService {
  /// `POST /api/v1/replenishments/{id}/lines` → updated `ReplenishmentOut`.
  ///
  /// Resolved: pass [productId].
  /// Pending: omit [productId], require [manualDescription] (and optional [barcode]).
  Future<Replenishment> addLine({
    required String replenishmentId,
    required int quantity,
    required String slotId,
    required String idempotencyKey,
    String? productId,
    String? barcode,
    String? manualDescription,
    String? replacementReason,
  });
}

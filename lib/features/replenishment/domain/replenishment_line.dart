/// A captured replenishment line from NexoVending `ReplenishmentLineOut`.
///
/// Creating a line is not an inventory movement.
final class ReplenishmentLine {
  ReplenishmentLine({
    required this.id,
    required this.slotId,
    required this.quantity,
    required this.unitPrice,
    required this.occurredAt,
    required this.productDescriptionSnapshot,
    required this.resolutionStatus,
    this.productId,
    this.preferredProductIdSnapshot,
    this.replacementReason,
    this.barcodeScanned,
    this.manualDescription,
    this.resolvedAt,
    this.resolvedByOperatorId,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (slotId.trim().isEmpty) {
      throw ArgumentError.value(slotId, 'slotId', 'must not be empty');
    }
    if (quantity == 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must not be zero');
    }
  }

  final String id;
  final String slotId;
  final String? productId;
  final int quantity;
  final String unitPrice;
  final String occurredAt;
  final String productDescriptionSnapshot;
  final String resolutionStatus;
  final String? preferredProductIdSnapshot;
  final String? replacementReason;
  final String? barcodeScanned;
  final String? manualDescription;
  final String? resolvedAt;
  final String? resolvedByOperatorId;

  factory ReplenishmentLine.fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final slotId = json['slot_id'] as String?;
    final quantity = json['quantity'];
    final unitPrice = json['unit_price'] as String?;
    final occurredAt = json['occurred_at'] as String?;
    final description = json['product_description_snapshot'] as String?;
    final resolutionStatus = json['resolution_status'] as String?;

    if (id == null ||
        slotId == null ||
        quantity is! int ||
        unitPrice == null ||
        occurredAt == null ||
        description == null ||
        resolutionStatus == null) {
      throw const FormatException(
        'ReplenishmentLine JSON missing required fields',
      );
    }

    return ReplenishmentLine(
      id: id,
      slotId: slotId,
      productId: json['product_id'] as String?,
      quantity: quantity,
      unitPrice: unitPrice,
      occurredAt: occurredAt,
      productDescriptionSnapshot: description,
      resolutionStatus: resolutionStatus,
      preferredProductIdSnapshot:
          json['preferred_product_id_snapshot'] as String?,
      replacementReason: json['replacement_reason'] as String?,
      barcodeScanned: json['barcode_scanned'] as String?,
      manualDescription: json['manual_description'] as String?,
      resolvedAt: json['resolved_at'] as String?,
      resolvedByOperatorId: json['resolved_by_operator_id'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'slot_id': slotId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'occurred_at': occurredAt,
      'product_description_snapshot': productDescriptionSnapshot,
      'resolution_status': resolutionStatus,
      'preferred_product_id_snapshot': preferredProductIdSnapshot,
      'replacement_reason': replacementReason,
      'barcode_scanned': barcodeScanned,
      'manual_description': manualDescription,
      'resolved_at': resolvedAt,
      'resolved_by_operator_id': resolvedByOperatorId,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ReplenishmentLine && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ReplenishmentLine(id: $id, slotId: $slotId, quantity: $quantity)';
  }
}

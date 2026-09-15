/// Physical slot configuration from NexoVending `MachineSlotOut`.
///
/// `preferredProductId` is configuration — not the product currently loaded.
final class MachineSlot {
  MachineSlot({
    required this.slotId,
    required this.slotNumber,
    required this.capacity,
    required this.status,
    this.preferredProductId,
    this.sellingPrice,
    this.currentQuantity,
  }) {
    if (slotId.trim().isEmpty) {
      throw ArgumentError.value(slotId, 'slotId', 'must not be empty');
    }
    if (status.trim().isEmpty) {
      throw ArgumentError.value(status, 'status', 'must not be empty');
    }
    if (capacity < 0) {
      throw ArgumentError.value(capacity, 'capacity', 'must not be negative');
    }
  }

  final String slotId;
  final int slotNumber;
  final int capacity;
  final String status;
  final String? preferredProductId;
  final String? sellingPrice;
  final int? currentQuantity;

  /// Display label for the physical position (backend `slot_number`).
  String get identifier => 'S$slotNumber';

  factory MachineSlot.fromJson(Map<String, Object?> json) {
    final slotId = json['slot_id'] as String?;
    final slotNumber = json['slot_number'];
    final capacity = json['capacity'];
    final status = json['status'] as String?;

    if (slotId == null || status == null) {
      throw const FormatException('MachineSlot JSON missing required fields');
    }
    if (slotNumber is! int || capacity is! int) {
      throw const FormatException('MachineSlot JSON missing numeric fields');
    }

    return MachineSlot(
      slotId: slotId,
      slotNumber: slotNumber,
      capacity: capacity,
      status: status,
      preferredProductId: json['preferred_product_id'] as String?,
      sellingPrice: json['selling_price'] as String?,
      currentQuantity: json['current_quantity'] as int?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'slot_id': slotId,
      'slot_number': slotNumber,
      'capacity': capacity,
      'status': status,
      'preferred_product_id': preferredProductId,
      'selling_price': sellingPrice,
      'current_quantity': currentQuantity,
    };
  }

  @override
  String toString() {
    return 'MachineSlot(slotId: $slotId, slotNumber: $slotNumber, '
        'capacity: $capacity, status: $status)';
  }
}

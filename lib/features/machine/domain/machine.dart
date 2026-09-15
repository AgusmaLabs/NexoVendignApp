/// Vending machine identity from `GET /api/v1/machines/resolve`.
///
/// Mirrors NexoVending `MachineOut` (without using slots in this commit).
final class Machine {
  Machine({
    required this.machineId,
    required this.identifier,
    required this.machineType,
    required this.name,
    required this.status,
  }) {
    if (machineId.trim().isEmpty) {
      throw ArgumentError.value(machineId, 'machineId', 'must not be empty');
    }
    if (identifier.trim().isEmpty) {
      throw ArgumentError.value(identifier, 'identifier', 'must not be empty');
    }
    if (machineType.trim().isEmpty) {
      throw ArgumentError.value(
        machineType,
        'machineType',
        'must not be empty',
      );
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (status.trim().isEmpty) {
      throw ArgumentError.value(status, 'status', 'must not be empty');
    }
  }

  final String machineId;
  final String identifier;
  final String machineType;
  final String name;
  final String status;

  factory Machine.fromJson(Map<String, Object?> json) {
    final machineId = json['machine_id'] as String?;
    final identifier = json['identifier'] as String?;
    final machineType = json['machine_type'] as String?;
    final name = json['name'] as String?;
    final status = json['status'] as String?;

    if (machineId == null ||
        identifier == null ||
        machineType == null ||
        name == null ||
        status == null) {
      throw const FormatException('Machine JSON missing required fields');
    }

    return Machine(
      machineId: machineId,
      identifier: identifier,
      machineType: machineType,
      name: name,
      status: status,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'machine_id': machineId,
      'identifier': identifier,
      'machine_type': machineType,
      'name': name,
      'status': status,
    };
  }

  @override
  String toString() {
    return 'Machine(machineId: $machineId, identifier: $identifier, '
        'name: $name, type: $machineType, status: $status)';
  }
}

/// Contract identifier types for `/machines/resolve`.
enum MachineIdentifierType {
  qrCode('QR_CODE'),
  internalId('INTERNAL_ID');

  const MachineIdentifierType(this.apiValue);
  final String apiValue;
}

/// Chooses [MachineIdentifierType] from raw user input (contract types only).
MachineIdentifierType detectIdentifierType(String value) {
  final trimmed = value.trim();
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if (uuid.hasMatch(trimmed)) {
    return MachineIdentifierType.internalId;
  }
  return MachineIdentifierType.qrCode;
}

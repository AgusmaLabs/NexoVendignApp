/// Machine detail from `GET /api/v1/machines/{machine_id}` (`MachineOut`).
final class MachineDetail {
  MachineDetail({
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
      throw ArgumentError.value(machineType, 'machineType', 'must not be empty');
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

  factory MachineDetail.fromJson(Map<String, Object?> json) {
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
      throw const FormatException('MachineDetail JSON missing required fields');
    }

    return MachineDetail(
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
    return 'MachineDetail(machineId: $machineId, identifier: $identifier, '
        'name: $name, type: $machineType, status: $status)';
  }
}

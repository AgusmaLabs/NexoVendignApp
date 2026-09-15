/// Geographic coordinates associated with a replenishment.
final class ReplenishmentLocation {
  const ReplenishmentLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;

  factory ReplenishmentLocation.fromJson(Map<String, Object?> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException(
        'ReplenishmentLocation JSON missing coordinates',
      );
    }
    final accuracy = json['accuracy'] ?? json['accuracy_m'];
    return ReplenishmentLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracy: accuracy is num ? accuracy.toDouble() : null,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
    };
  }
}

/// Replenishment session from NexoVending `ReplenishmentOut`.
///
/// Backend status values are preserved as-is (e.g. `IN_PROGRESS`).
final class Replenishment {
  Replenishment({
    required this.id,
    required this.machineId,
    required this.operatorId,
    required this.status,
    required this.machineType,
    required this.startedAt,
    required this.location,
    required this.idempotencyKey,
    required this.version,
    this.completedAt,
    this.lines = const <Object?>[],
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (machineId.trim().isEmpty) {
      throw ArgumentError.value(machineId, 'machineId', 'must not be empty');
    }
    if (operatorId.trim().isEmpty) {
      throw ArgumentError.value(operatorId, 'operatorId', 'must not be empty');
    }
    if (status.trim().isEmpty) {
      throw ArgumentError.value(status, 'status', 'must not be empty');
    }
  }

  final String id;
  final String machineId;
  final String operatorId;
  final String status;
  final String machineType;
  final String startedAt;
  final String? completedAt;
  final ReplenishmentLocation location;
  final String idempotencyKey;
  final int version;

  /// Lines are opaque in Commit 8 (always empty on create).
  final List<Object?> lines;

  factory Replenishment.fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final machineId = json['machine_id'] as String?;
    final operatorId = json['operator_id'] as String?;
    final status = json['status'] as String?;
    final machineType = json['machine_type'] as String?;
    final startedAt = json['started_at'] as String?;
    final idempotencyKey = json['idempotency_key'] as String?;
    final version = json['version'];
    final locationRaw = json['location'];

    if (id == null ||
        machineId == null ||
        operatorId == null ||
        status == null ||
        machineType == null ||
        startedAt == null ||
        idempotencyKey == null ||
        version is! int ||
        locationRaw is! Map) {
      throw const FormatException('Replenishment JSON missing required fields');
    }

    final linesRaw = json['lines'];
    return Replenishment(
      id: id,
      machineId: machineId,
      operatorId: operatorId,
      status: status,
      machineType: machineType,
      startedAt: startedAt,
      completedAt: json['completed_at'] as String?,
      location: ReplenishmentLocation.fromJson(
        Map<String, Object?>.from(locationRaw),
      ),
      idempotencyKey: idempotencyKey,
      version: version,
      lines: linesRaw is List ? List<Object?>.from(linesRaw) : const <Object?>[],
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'machine_id': machineId,
      'operator_id': operatorId,
      'status': status,
      'machine_type': machineType,
      'started_at': startedAt,
      'completed_at': completedAt,
      'location': location.toJson(),
      'idempotency_key': idempotencyKey,
      'version': version,
      'lines': lines,
    };
  }

  @override
  String toString() {
    return 'Replenishment(id: $id, machineId: $machineId, status: $status)';
  }
}

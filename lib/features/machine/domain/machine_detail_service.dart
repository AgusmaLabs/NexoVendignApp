import 'machine_detail.dart';

/// Loads machine detail via NexoVending.
abstract interface class MachineDetailService {
  /// `GET /api/v1/machines/{machineId}` using the session JWT.
  Future<MachineDetail> getMachineDetail(String machineId);
}

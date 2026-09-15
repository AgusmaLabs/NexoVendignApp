import 'machine_slot.dart';

/// Loads physical slot configuration via NexoVending.
abstract interface class MachineSlotService {
  /// `GET /api/v1/machines/{machineId}/slots` using the session JWT.
  Future<List<MachineSlot>> getSlots(String machineId);
}

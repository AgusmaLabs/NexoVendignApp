import 'machine.dart';

/// Resolves a Vending machine via NexoVending.
abstract interface class MachineService {
  /// `GET /api/v1/machines/resolve` using the session JWT via ApiClient.
  Future<Machine> resolveMachine(String identifier);
}

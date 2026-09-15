import 'package:flutter/foundation.dart';

import '../../../core/authentication/session_service.dart';
import '../../../core/device/location_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/networking/request_id.dart';
import '../../machine/application/machine_identification_controller.dart';
import '../../operator/application/operator_bootstrap_controller.dart';
import '../domain/replenishment.dart';
import '../domain/replenishment_exception.dart';
import '../domain/replenishment_service.dart';
import 'replenishment_creation_state.dart';

/// Creates a replenishment for the current machine and holds context.
final class ReplenishmentCreationController extends ChangeNotifier {
  ReplenishmentCreationController({
    required this.replenishmentService,
    required this.machineIdentificationController,
    required this.operatorBootstrapController,
    required this.locationService,
    required this.sessionService,
    required this.requestIdGenerator,
    required this.logger,
    this.onSessionExpired,
  });

  final ReplenishmentService replenishmentService;
  final MachineIdentificationController machineIdentificationController;
  final OperatorBootstrapController operatorBootstrapController;
  final LocationService locationService;
  final SessionService sessionService;
  final RequestIdGenerator requestIdGenerator;
  final AppLogger logger;
  final Future<void> Function()? onSessionExpired;

  ReplenishmentCreationState _state = const ReplenishmentCreationInitial();
  Replenishment? _currentReplenishment;
  String? _idempotencyKey;
  String? _idempotencyMachineId;
  var _createGeneration = 0;

  ReplenishmentCreationState get state => _state;

  Replenishment? get currentReplenishment => _currentReplenishment;

  bool get isCreating => _state is ReplenishmentCreationCreating;

  /// Exposed for tests — key reused across retries of the same intent.
  String? get pendingIdempotencyKey => _idempotencyKey;

  Future<void> start() async {
    if (isCreating) {
      return;
    }

    final operator = operatorBootstrapController.currentOperator;
    if (operator == null) {
      _setState(const ReplenishmentCreationNoOperator());
      return;
    }

    final machine = machineIdentificationController.currentMachine;
    if (machine == null) {
      _setState(const ReplenishmentCreationNoMachine());
      return;
    }

    final machineId = machine.machineId.trim();
    if (machineId.isEmpty) {
      _setState(
        const ReplenishmentCreationFailure(
          'Falta el identificador de la máquina.',
          canRetry: false,
        ),
      );
      return;
    }

    _ensureIdempotencyKey(machineId);
    final generation = ++_createGeneration;
    final key = _idempotencyKey!;
    _setState(const ReplenishmentCreationCreating());
    logger.info('replenishment_create_ui_started');

    try {
      final location = await locationService.getCurrentLocation();
      if (generation != _createGeneration) {
        return;
      }

      final replenishment = await replenishmentService.createReplenishment(
        machineId: machineId,
        location: location,
        idempotencyKey: key,
      );
      if (generation != _createGeneration) {
        return;
      }

      final currentMachine = machineIdentificationController.currentMachine;
      if (currentMachine == null ||
          currentMachine.machineId != replenishment.machineId) {
        logger.info(
          'replenishment_create_stale_ignored',
          context: {'machineId': replenishment.machineId},
        );
        _setState(const ReplenishmentCreationInitial());
        return;
      }

      _currentReplenishment = replenishment;
      _idempotencyKey = null;
      _idempotencyMachineId = null;
      _setState(ReplenishmentCreationCreated(replenishment));
    } on ReplenishmentSessionExpired {
      if (generation != _createGeneration) {
        return;
      }
      await sessionService.clearSession();
      _setState(const ReplenishmentCreationSessionExpired());
      await onSessionExpired?.call();
    } on ReplenishmentException catch (error) {
      if (generation != _createGeneration) {
        return;
      }
      logger.error(
        'replenishment_create_ui_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(ReplenishmentCreationFailure(error.message));
    } on UnsupportedError catch (error) {
      if (generation != _createGeneration) {
        return;
      }
      logger.error('replenishment_create_location_unavailable', error: error);
      _setState(
        const ReplenishmentCreationFailure(
          'No fue posible obtener la ubicación GPS.',
        ),
      );
    } catch (error, stackTrace) {
      if (generation != _createGeneration) {
        return;
      }
      logger.error(
        'replenishment_create_ui_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        const ReplenishmentCreationFailure(
          'No fue posible iniciar la reposición en este momento.',
        ),
      );
    }
  }

  Future<void> retry() async {
    await start();
  }

  /// Prepares UI for another create intent (new idempotency key).
  void resetToInitial() {
    _createGeneration += 1;
    _idempotencyKey = null;
    _idempotencyMachineId = null;
    _setState(const ReplenishmentCreationInitial());
  }

  Future<void> clear() async {
    _createGeneration += 1;
    _idempotencyKey = null;
    _idempotencyMachineId = null;
    _currentReplenishment = null;
    _setState(const ReplenishmentCreationInitial());
  }

  void _ensureIdempotencyKey(String machineId) {
    if (_idempotencyMachineId != machineId) {
      _idempotencyKey = requestIdGenerator.next();
      _idempotencyMachineId = machineId;
      return;
    }
    _idempotencyKey ??= requestIdGenerator.next();
  }

  void _setState(ReplenishmentCreationState next) {
    _state = next;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../machine/application/machine_detail_controller.dart';
import '../../machine/application/machine_detail_state.dart';
import '../../machine/application/machine_identification_controller.dart';
import '../../machine/application/machine_identification_state.dart';
import '../../operator/application/operator_bootstrap_controller.dart';
import 'replenishment_creation_controller.dart';
import 'replenishment_creation_state.dart';
import 'visit_start_state.dart';

/// Field entry: identify machine → load slots → create replenishment in one step.
final class VisitStartController extends ChangeNotifier {
  VisitStartController({
    required this.machineIdentificationController,
    required this.machineDetailController,
    required this.replenishmentCreationController,
    required this.operatorBootstrapController,
    required this.logger,
  });

  final MachineIdentificationController machineIdentificationController;
  final MachineDetailController machineDetailController;
  final ReplenishmentCreationController replenishmentCreationController;
  final OperatorBootstrapController operatorBootstrapController;
  final AppLogger logger;

  VisitStartState _state = const VisitStartIdle();
  String _lastIdentifier = '';
  var _generation = 0;

  VisitStartState get state => _state;

  bool get isStarting => _state is VisitStartStarting;

  Future<void> startFromIdentifier(String identifier) async {
    if (isStarting) {
      return;
    }

    final trimmed = identifier.trim();
    _lastIdentifier = trimmed;
    if (trimmed.isEmpty) {
      _setState(
        const VisitStartFailure(
          'Ingresa un identificador de máquina.',
          canRetry: false,
          isValidation: true,
        ),
      );
      return;
    }

    if (operatorBootstrapController.currentOperator == null) {
      _setState(const VisitStartNoOperator());
      return;
    }

    final generation = ++_generation;
    logger.info('visit_start_ui_started');

    _setState(const VisitStartStarting('Identificando máquina...'));
    await machineIdentificationController.identify(trimmed);
    if (generation != _generation) {
      return;
    }

    final identifyState = machineIdentificationController.state;
    if (identifyState is MachineIdentificationSessionExpired) {
      _setState(const VisitStartSessionExpired());
      return;
    }
    if (identifyState is MachineIdentificationFailure) {
      _setState(
        VisitStartFailure(
          identifyState.message,
          canRetry: identifyState.canRetry,
          isValidation: identifyState.isValidation,
        ),
      );
      return;
    }
    if (identifyState is! MachineIdentificationResolved) {
      _setState(
        const VisitStartFailure(
          'No fue posible identificar la máquina.',
        ),
      );
      return;
    }

    final machine = identifyState.machine;
    _setState(const VisitStartStarting('Cargando slots...'));
    await machineDetailController.load(machine.machineId);
    if (generation != _generation) {
      return;
    }

    final detailState = machineDetailController.state;
    if (detailState is MachineDetailSessionExpired) {
      _setState(const VisitStartSessionExpired());
      return;
    }
    if (detailState is MachineDetailFailure) {
      _setState(VisitStartFailure(detailState.message));
      return;
    }
    if (detailState is! MachineDetailLoaded) {
      _setState(
        const VisitStartFailure(
          'No fue posible cargar los slots de la máquina.',
        ),
      );
      return;
    }

    _setState(const VisitStartStarting('Iniciando reposición...'));
    await replenishmentCreationController.start();
    if (generation != _generation) {
      return;
    }

    final createState = replenishmentCreationController.state;
    if (createState is ReplenishmentCreationSessionExpired) {
      _setState(const VisitStartSessionExpired());
      return;
    }
    if (createState is ReplenishmentCreationNoOperator) {
      _setState(const VisitStartNoOperator());
      return;
    }
    if (createState is ReplenishmentCreationNoMachine) {
      _setState(
        const VisitStartFailure(
          'Falta el contexto de la máquina para iniciar la reposición.',
          canRetry: false,
        ),
      );
      return;
    }
    if (createState is ReplenishmentCreationFailure) {
      _setState(VisitStartFailure(createState.message));
      return;
    }
    if (createState is! ReplenishmentCreationCreated) {
      _setState(
        const VisitStartFailure(
          'No fue posible iniciar la reposición en este momento.',
        ),
      );
      return;
    }

    _setState(
      VisitStartReady(
        machine: machine,
        replenishment: createState.replenishment,
      ),
    );
  }

  Future<void> retry() => startFromIdentifier(_lastIdentifier);

  void resetToIdle() {
    _generation += 1;
    _setState(const VisitStartIdle());
  }

  Future<void> clear() async {
    _generation += 1;
    _lastIdentifier = '';
    _setState(const VisitStartIdle());
  }

  void _setState(VisitStartState next) {
    _state = next;
    notifyListeners();
  }
}

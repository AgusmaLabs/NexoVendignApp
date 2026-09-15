import 'package:flutter/foundation.dart';

import '../../../core/authentication/session_service.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/machine.dart';
import '../domain/machine_exception.dart';
import '../domain/machine_service.dart';
import 'machine_identification_state.dart';

/// Resolves and holds the current machine operational context.
final class MachineIdentificationController extends ChangeNotifier {
  MachineIdentificationController({
    required this.machineService,
    required this.sessionService,
    required this.logger,
    this.onSessionExpired,
  });

  final MachineService machineService;
  final SessionService sessionService;
  final AppLogger logger;
  final Future<void> Function()? onSessionExpired;

  MachineIdentificationState _state = const MachineIdentificationInitial();
  Machine? _currentMachine;
  String _lastIdentifier = '';

  MachineIdentificationState get state => _state;

  /// Selected machine context for future field operations (in-memory only).
  Machine? get currentMachine => _currentMachine;

  bool get isResolving => _state is MachineIdentificationResolving;

  Future<void> identify(String identifier) async {
    if (isResolving) {
      return;
    }

    final trimmed = identifier.trim();
    _lastIdentifier = trimmed;
    if (trimmed.isEmpty) {
      _setState(
        const MachineIdentificationFailure(
          'Ingresa un identificador de máquina.',
          canRetry: false,
          isValidation: true,
        ),
      );
      return;
    }

    _setState(const MachineIdentificationResolving());
    logger.info('machine_identify_ui_started');

    try {
      final machine = await machineService.resolveMachine(trimmed);
      _currentMachine = machine;
      _setState(MachineIdentificationResolved(machine));
    } on MachineSessionExpired {
      await sessionService.clearSession();
      _setState(const MachineIdentificationSessionExpired());
      await onSessionExpired?.call();
    } on MachineException catch (error) {
      logger.error(
        'machine_identify_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      // Keep previous valid machine context on failure (V1 policy).
      _setState(
        MachineIdentificationFailure(
          error.message,
          canRetry: error is! MachineIdentifierInvalid,
          isValidation: error is MachineIdentifierInvalid,
        ),
      );
    } catch (error, stackTrace) {
      logger.error(
        'machine_identify_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        const MachineIdentificationFailure(
          'No fue posible cargar la máquina en este momento.',
        ),
      );
    }
  }

  Future<void> retry() {
    return identify(_lastIdentifier);
  }

  Future<void> clear() async {
    _currentMachine = null;
    _lastIdentifier = '';
    _setState(const MachineIdentificationInitial());
  }

  void resetToInitial() {
    _setState(const MachineIdentificationInitial());
  }

  void _setState(MachineIdentificationState next) {
    _state = next;
    notifyListeners();
  }
}

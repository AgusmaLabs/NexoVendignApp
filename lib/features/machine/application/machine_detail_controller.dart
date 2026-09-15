import 'package:flutter/foundation.dart';

import '../../../core/authentication/session_service.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/machine_detail.dart';
import '../domain/machine_detail_service.dart';
import '../domain/machine_exception.dart';
import '../domain/machine_slot.dart';
import '../domain/machine_slot_service.dart';
import 'machine_detail_state.dart';

/// Loads machine detail + slots and holds operational machine context.
final class MachineDetailController extends ChangeNotifier {
  MachineDetailController({
    required this.detailService,
    required this.slotService,
    required this.sessionService,
    required this.logger,
    this.onSessionExpired,
  });

  final MachineDetailService detailService;
  final MachineSlotService slotService;
  final SessionService sessionService;
  final AppLogger logger;
  final Future<void> Function()? onSessionExpired;

  MachineDetailState _state = const MachineDetailInitial();
  String? _machineId;
  var _loadGeneration = 0;

  MachineDetailState get state => _state;

  MachineDetail? get currentDetail => switch (_state) {
    MachineDetailLoaded(:final detail) => detail,
    _ => null,
  };

  List<MachineSlot> get currentSlots => switch (_state) {
    MachineDetailLoaded(:final slots) => slots,
    _ => const <MachineSlot>[],
  };

  String? get selectedSlotId => switch (_state) {
    MachineDetailLoaded(:final selectedSlotId) => selectedSlotId,
    _ => null,
  };

  bool get isLoading => _state is MachineDetailLoading;

  Future<void> load(String machineId) async {
    final trimmed = machineId.trim();
    if (trimmed.isEmpty) {
      _setState(
        const MachineDetailFailure(
          'Falta el identificador de la máquina.',
          canRetry: false,
        ),
      );
      return;
    }

    final generation = ++_loadGeneration;
    _machineId = trimmed;
    _setState(const MachineDetailLoading());
    logger.info('machine_detail_ui_started');

    try {
      final results = await Future.wait<Object>([
        detailService.getMachineDetail(trimmed),
        slotService.getSlots(trimmed),
      ]);
      if (generation != _loadGeneration) {
        return;
      }
      final detail = results[0] as MachineDetail;
      final slots = results[1] as List<MachineSlot>;
      _setState(MachineDetailLoaded(detail: detail, slots: slots));
    } on MachineSessionExpired {
      if (generation != _loadGeneration) {
        return;
      }
      await sessionService.clearSession();
      _setState(const MachineDetailSessionExpired());
      await onSessionExpired?.call();
    } on MachineException catch (error) {
      if (generation != _loadGeneration) {
        return;
      }
      logger.error(
        'machine_detail_ui_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(MachineDetailFailure(error.message));
    } catch (error, stackTrace) {
      if (generation != _loadGeneration) {
        return;
      }
      logger.error(
        'machine_detail_ui_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        const MachineDetailFailure(
          'No fue posible cargar la configuración de la máquina.',
        ),
      );
    }
  }

  Future<void> retry() async {
    final id = _machineId;
    if (id == null) {
      return;
    }
    await load(id);
  }

  void selectSlot(String slotId) {
    final current = _state;
    if (current is! MachineDetailLoaded) {
      return;
    }
    final exists = current.slots.any((slot) => slot.slotId == slotId);
    if (!exists) {
      return;
    }
    _setState(current.copyWith(selectedSlotId: slotId));
  }

  void clearSelectedSlot() {
    final current = _state;
    if (current is! MachineDetailLoaded) {
      return;
    }
    _setState(current.copyWith(clearSelectedSlot: true));
  }

  Future<void> clear() async {
    _loadGeneration += 1;
    _machineId = null;
    _setState(const MachineDetailInitial());
  }

  void _setState(MachineDetailState next) {
    _state = next;
    notifyListeners();
  }
}

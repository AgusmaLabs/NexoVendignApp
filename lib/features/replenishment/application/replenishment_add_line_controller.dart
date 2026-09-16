import 'package:flutter/foundation.dart';

import '../../../core/authentication/session_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/networking/request_id.dart';
import '../../machine/application/machine_detail_controller.dart';
import '../../machine/domain/machine_slot.dart';
import '../../products/domain/product.dart';
import '../domain/replenishment_exception.dart';
import '../domain/replenishment_line.dart';
import '../domain/replenishment_line_service.dart';
import 'replenishment_add_line_state.dart';
import 'replenishment_creation_controller.dart';

/// Captures quantity + slot and posts a replenishment line.
final class ReplenishmentAddLineController extends ChangeNotifier {
  ReplenishmentAddLineController({
    required this.lineService,
    required this.replenishmentCreationController,
    required this.machineDetailController,
    required this.sessionService,
    required this.requestIdGenerator,
    required this.logger,
    this.onSessionExpired,
  });

  final ReplenishmentLineService lineService;
  final ReplenishmentCreationController replenishmentCreationController;
  final MachineDetailController machineDetailController;
  final SessionService sessionService;
  final RequestIdGenerator requestIdGenerator;
  final AppLogger logger;
  final Future<void> Function()? onSessionExpired;

  ReplenishmentAddLineState _state = const ReplenishmentAddLineIdle();
  Product? _product;
  String? _barcode;
  String? _selectedSlotId;
  int? _quantity;
  String? _idempotencyKey;
  var _addGeneration = 0;

  ReplenishmentAddLineState get state => _state;

  Product? get product => _product;

  String? get barcode => _barcode;

  String? get selectedSlotId => _selectedSlotId;

  int? get quantity => _quantity;

  List<MachineSlot> get availableSlots => machineDetailController.currentSlots;

  bool get isAdding => _state is ReplenishmentAddLineAdding;

  String? get pendingIdempotencyKey => _idempotencyKey;

  ReplenishmentLine? get lastAddedLine => switch (_state) {
    ReplenishmentAddLineAdded(:final line) => line,
    _ => null,
  };

  void beginWithProduct(Product product, {String? barcode}) {
    _product = product;
    _barcode = barcode;
    _selectedSlotId = null;
    _quantity = null;
    _idempotencyKey = null;
    _addGeneration += 1;
    _setState(const ReplenishmentAddLineIdle());
  }

  void selectSlot(String slotId) {
    final exists = availableSlots.any((slot) => slot.slotId == slotId);
    if (!exists) {
      return;
    }
    _selectedSlotId = slotId;
    notifyListeners();
  }

  void setQuantity(int? quantity) {
    _quantity = quantity;
    notifyListeners();
  }

  Future<void> submit() async {
    if (isAdding) {
      return;
    }

    final replenishment = replenishmentCreationController.currentReplenishment;
    if (replenishment == null) {
      _setState(
        const ReplenishmentAddLineValidationFailure(
          'Inicia una reposición antes de agregar productos.',
        ),
      );
      return;
    }

    final product = _product;
    if (product == null) {
      _setState(
        const ReplenishmentAddLineValidationFailure(
          'Selecciona un producto antes de agregar la línea.',
        ),
      );
      return;
    }

    final quantity = _quantity;
    if (quantity == null || quantity <= 0) {
      _setState(
        const ReplenishmentAddLineValidationFailure(
          'La cantidad debe ser un entero mayor que cero.',
        ),
      );
      return;
    }

    // Current NexoVending contract requires slot_id on every line.
    final slotId = _selectedSlotId?.trim();
    if (slotId == null || slotId.isEmpty) {
      _setState(
        const ReplenishmentAddLineValidationFailure(
          'Selecciona un slot para agregar la línea.',
        ),
      );
      return;
    }

    if (availableSlots.isEmpty) {
      _setState(
        const ReplenishmentAddLineValidationFailure(
          'No hay slots configurados para esta máquina.',
        ),
      );
      return;
    }

    _idempotencyKey ??= requestIdGenerator.next();
    final key = _idempotencyKey!;
    final generation = ++_addGeneration;
    _setState(const ReplenishmentAddLineAdding());
    logger.info('replenishment_add_line_ui_started');

    try {
      final previousIds = replenishment.lines.map((line) => line.id).toSet();
      final updated = await lineService.addLine(
        replenishmentId: replenishment.id,
        productId: product.productId,
        quantity: quantity,
        slotId: slotId,
        idempotencyKey: key,
      );
      if (generation != _addGeneration) {
        return;
      }

      final current = replenishmentCreationController.currentReplenishment;
      if (current == null || current.id != updated.id) {
        logger.info('replenishment_add_line_stale_ignored');
        _setState(const ReplenishmentAddLineIdle());
        return;
      }

      replenishmentCreationController.applyUpdatedReplenishment(updated);
      final line = updated.lines.reversed.firstWhere(
        (item) => !previousIds.contains(item.id),
        orElse: () => updated.lines.isNotEmpty
            ? updated.lines.last
            : throw StateError('No line returned'),
      );
      _idempotencyKey = null;
      _setState(
        ReplenishmentAddLineAdded(replenishment: updated, line: line),
      );
    } on ReplenishmentSessionExpired {
      if (generation != _addGeneration) {
        return;
      }
      await sessionService.clearSession();
      _setState(const ReplenishmentAddLineSessionExpired());
      await onSessionExpired?.call();
    } on ReplenishmentQuantityInvalid catch (error) {
      if (generation != _addGeneration) {
        return;
      }
      _setState(ReplenishmentAddLineValidationFailure(error.message));
    } on ReplenishmentSlotRequired catch (error) {
      if (generation != _addGeneration) {
        return;
      }
      _setState(ReplenishmentAddLineValidationFailure(error.message));
    } on ReplenishmentException catch (error) {
      if (generation != _addGeneration) {
        return;
      }
      logger.error(
        'replenishment_add_line_ui_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(ReplenishmentAddLineFailure(error.message));
    } catch (error, stackTrace) {
      if (generation != _addGeneration) {
        return;
      }
      logger.error(
        'replenishment_add_line_ui_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        const ReplenishmentAddLineFailure(
          'No fue posible agregar la línea en este momento.',
        ),
      );
    }
  }

  Future<void> retry() async {
    await submit();
  }

  void resetToIdle() {
    _addGeneration += 1;
    _idempotencyKey = null;
    _setState(const ReplenishmentAddLineIdle());
  }

  /// Clears product/slot/qty after a successful line so the operator can scan again.
  void prepareForNextLine() {
    _addGeneration += 1;
    _product = null;
    _barcode = null;
    _selectedSlotId = null;
    _quantity = null;
    _idempotencyKey = null;
    _setState(const ReplenishmentAddLineIdle());
  }

  Future<void> clear() async {
    _addGeneration += 1;
    _product = null;
    _barcode = null;
    _selectedSlotId = null;
    _quantity = null;
    _idempotencyKey = null;
    _setState(const ReplenishmentAddLineIdle());
  }

  void _setState(ReplenishmentAddLineState next) {
    _state = next;
    notifyListeners();
  }
}

import '../domain/machine_detail.dart';
import '../domain/machine_slot.dart';

/// Machine detail + slots screen state.
sealed class MachineDetailState {
  const MachineDetailState();
}

final class MachineDetailInitial extends MachineDetailState {
  const MachineDetailInitial();
}

final class MachineDetailLoading extends MachineDetailState {
  const MachineDetailLoading();
}

final class MachineDetailLoaded extends MachineDetailState {
  const MachineDetailLoaded({
    required this.detail,
    required this.slots,
    this.selectedSlotId,
  });

  final MachineDetail detail;
  final List<MachineSlot> slots;
  final String? selectedSlotId;

  MachineDetailLoaded copyWith({
    MachineDetail? detail,
    List<MachineSlot>? slots,
    String? selectedSlotId,
    bool clearSelectedSlot = false,
  }) {
    return MachineDetailLoaded(
      detail: detail ?? this.detail,
      slots: slots ?? this.slots,
      selectedSlotId: clearSelectedSlot
          ? null
          : (selectedSlotId ?? this.selectedSlotId),
    );
  }
}

final class MachineDetailFailure extends MachineDetailState {
  const MachineDetailFailure(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;
}

final class MachineDetailSessionExpired extends MachineDetailState {
  const MachineDetailSessionExpired();
}

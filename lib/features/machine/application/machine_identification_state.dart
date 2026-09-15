import '../domain/machine.dart';

/// Machine identification state machine.
sealed class MachineIdentificationState {
  const MachineIdentificationState();
}

final class MachineIdentificationInitial extends MachineIdentificationState {
  const MachineIdentificationInitial();
}

final class MachineIdentificationResolving extends MachineIdentificationState {
  const MachineIdentificationResolving();
}

final class MachineIdentificationResolved extends MachineIdentificationState {
  const MachineIdentificationResolved(this.machine);

  final Machine machine;
}

final class MachineIdentificationFailure extends MachineIdentificationState {
  const MachineIdentificationFailure(
    this.message, {
    this.canRetry = true,
    this.isValidation = false,
  });

  final String message;
  final bool canRetry;
  final bool isValidation;
}

final class MachineIdentificationSessionExpired
    extends MachineIdentificationState {
  const MachineIdentificationSessionExpired();
}

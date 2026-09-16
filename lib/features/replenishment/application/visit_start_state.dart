import '../../machine/domain/machine.dart';
import '../domain/replenishment.dart';

/// UI state for QR/identifier → machine resolve + slots + create replenishment.
sealed class VisitStartState {
  const VisitStartState();
}

final class VisitStartIdle extends VisitStartState {
  const VisitStartIdle();
}

final class VisitStartStarting extends VisitStartState {
  const VisitStartStarting(this.phase);

  /// Short operator-facing phase label (identificar / slots / crear visita).
  final String phase;
}

final class VisitStartReady extends VisitStartState {
  const VisitStartReady({
    required this.machine,
    required this.replenishment,
  });

  final Machine machine;
  final Replenishment replenishment;
}

final class VisitStartFailure extends VisitStartState {
  const VisitStartFailure(
    this.message, {
    this.canRetry = true,
    this.isValidation = false,
  });

  final String message;
  final bool canRetry;
  final bool isValidation;
}

final class VisitStartSessionExpired extends VisitStartState {
  const VisitStartSessionExpired();
}

final class VisitStartNoOperator extends VisitStartState {
  const VisitStartNoOperator();
}

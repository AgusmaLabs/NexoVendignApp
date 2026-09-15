import '../domain/replenishment.dart';

/// UI state for replenishment creation.
sealed class ReplenishmentCreationState {
  const ReplenishmentCreationState();
}

final class ReplenishmentCreationInitial extends ReplenishmentCreationState {
  const ReplenishmentCreationInitial();
}

final class ReplenishmentCreationCreating extends ReplenishmentCreationState {
  const ReplenishmentCreationCreating();
}

final class ReplenishmentCreationCreated extends ReplenishmentCreationState {
  const ReplenishmentCreationCreated(this.replenishment);

  final Replenishment replenishment;
}

final class ReplenishmentCreationFailure extends ReplenishmentCreationState {
  const ReplenishmentCreationFailure(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;
}

final class ReplenishmentCreationNoMachine extends ReplenishmentCreationState {
  const ReplenishmentCreationNoMachine();
}

final class ReplenishmentCreationNoOperator extends ReplenishmentCreationState {
  const ReplenishmentCreationNoOperator();
}

final class ReplenishmentCreationSessionExpired
    extends ReplenishmentCreationState {
  const ReplenishmentCreationSessionExpired();
}

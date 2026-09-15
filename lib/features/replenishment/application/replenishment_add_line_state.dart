import '../domain/replenishment.dart';
import '../domain/replenishment_line.dart';
import '../../products/domain/product.dart';

/// UI state for adding a replenishment line.
sealed class ReplenishmentAddLineState {
  const ReplenishmentAddLineState();
}

final class ReplenishmentAddLineIdle extends ReplenishmentAddLineState {
  const ReplenishmentAddLineIdle();
}

final class ReplenishmentAddLineAdding extends ReplenishmentAddLineState {
  const ReplenishmentAddLineAdding();
}

final class ReplenishmentAddLineAdded extends ReplenishmentAddLineState {
  const ReplenishmentAddLineAdded({
    required this.replenishment,
    required this.line,
  });

  final Replenishment replenishment;
  final ReplenishmentLine line;
}

final class ReplenishmentAddLineFailure extends ReplenishmentAddLineState {
  const ReplenishmentAddLineFailure(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;
}

final class ReplenishmentAddLineValidationFailure
    extends ReplenishmentAddLineState {
  const ReplenishmentAddLineValidationFailure(this.message);

  final String message;
}

final class ReplenishmentAddLineSessionExpired
    extends ReplenishmentAddLineState {
  const ReplenishmentAddLineSessionExpired();
}

/// Arguments passed from product lookup into the add-line screen.
final class AddLineArgs {
  const AddLineArgs({required this.product, this.barcode});

  final Product product;
  final String? barcode;
}

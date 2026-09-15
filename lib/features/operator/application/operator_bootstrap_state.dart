import '../domain/operator.dart';

/// Operator bootstrap state machine (session remains separate).
sealed class OperatorBootstrapState {
  const OperatorBootstrapState();
}

final class OperatorBootstrapUnknown extends OperatorBootstrapState {
  const OperatorBootstrapUnknown();
}

final class OperatorBootstrapLoading extends OperatorBootstrapState {
  const OperatorBootstrapLoading();
}

final class OperatorBootstrapLoaded extends OperatorBootstrapState {
  const OperatorBootstrapLoaded(this.operator);

  final Operator operator;
}

final class OperatorBootstrapAccessDenied extends OperatorBootstrapState {
  const OperatorBootstrapAccessDenied(this.message);

  final String message;
}

final class OperatorBootstrapNotConfigured extends OperatorBootstrapState {
  const OperatorBootstrapNotConfigured(this.message);

  final String message;
}

final class OperatorBootstrapFailure extends OperatorBootstrapState {
  const OperatorBootstrapFailure(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;
}

final class OperatorBootstrapSessionExpired extends OperatorBootstrapState {
  const OperatorBootstrapSessionExpired();
}

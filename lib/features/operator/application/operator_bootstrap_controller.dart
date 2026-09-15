import 'package:flutter/foundation.dart';

import '../../../core/authentication/session_service.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/operator.dart';
import '../domain/operator_exception.dart';
import '../domain/operator_service.dart';
import 'operator_bootstrap_state.dart';

/// Loads the Vending operator after a valid session exists.
final class OperatorBootstrapController extends ChangeNotifier {
  OperatorBootstrapController({
    required this.operatorService,
    required this.sessionService,
    required this.logger,
    this.onSessionExpired,
  });

  final OperatorService operatorService;
  final SessionService sessionService;
  final AppLogger logger;

  /// Notifies authentication layer that the session must be cleared (401).
  final Future<void> Function()? onSessionExpired;

  OperatorBootstrapState _state = const OperatorBootstrapUnknown();

  OperatorBootstrapState get state => _state;

  Operator? get currentOperator => switch (_state) {
    OperatorBootstrapLoaded(:final operator) => operator,
    _ => null,
  };

  bool get isLoading => _state is OperatorBootstrapLoading;

  Future<void> load() async {
    if (_state is OperatorBootstrapLoading) {
      return;
    }
    _setState(const OperatorBootstrapLoading());
    logger.info('operator_bootstrap_ui_started');

    try {
      final operator = await operatorService.getCurrentOperator();
      _setState(OperatorBootstrapLoaded(operator));
    } on OperatorSessionExpired {
      await sessionService.clearSession();
      _setState(const OperatorBootstrapSessionExpired());
      await onSessionExpired?.call();
    } on OperatorAccessDenied catch (error) {
      logger.error(
        'operator_bootstrap_access_denied',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(OperatorBootstrapAccessDenied(error.message));
    } on OperatorNotConfigured catch (error) {
      logger.error(
        'operator_bootstrap_not_configured',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(OperatorBootstrapNotConfigured(error.message));
    } on OperatorNetworkFailure catch (error) {
      logger.error(
        'operator_bootstrap_network',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(OperatorBootstrapFailure(error.message));
    } on OperatorException catch (error) {
      logger.error(
        'operator_bootstrap_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(OperatorBootstrapFailure(error.message));
    } catch (error, stackTrace) {
      logger.error(
        'operator_bootstrap_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        const OperatorBootstrapFailure('No fue posible cargar tu información.'),
      );
    }
  }

  Future<void> retry() => load();

  Future<void> clear() async {
    _setState(const OperatorBootstrapUnknown());
  }

  void _setState(OperatorBootstrapState next) {
    _state = next;
    notifyListeners();
  }
}

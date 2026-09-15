import 'package:flutter/foundation.dart';

import '../../../core/authentication/authentication_exception.dart';
import '../../../core/authentication/google_sign_in_service.dart';
import '../../../core/logging/app_logger.dart';
import 'authentication_state.dart';

/// Coordinates Google Sign-In for the UI without contacting NexoVending.
///
/// The Google `id_token` remains in memory only for Commit 3. It is never
/// written to LocalStorage or SecureStorage here.
final class AuthenticationController extends ChangeNotifier {
  AuthenticationController({
    required this.googleSignInService,
    required this.logger,
  });

  final GoogleSignInService googleSignInService;
  final AppLogger logger;

  AuthenticationState _state = const Unauthenticated();

  AuthenticationState get state => _state;

  bool get isAuthenticating => _state is Authenticating;

  Future<void> signIn() async {
    if (_state is Authenticating) {
      return;
    }

    _setState(const Authenticating());
    logger.info('authentication_started');

    try {
      final result = await googleSignInService.signIn();
      _setState(Authenticated(result));
    } on AuthenticationCancelled {
      logger.info('authentication_cancelled');
      _setState(const Unauthenticated());
    } on AuthenticationException catch (error) {
      logger.error(
        'authentication_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(AuthenticationFailure(_userMessage(error)));
    } catch (error, stackTrace) {
      logger.error(
        'authentication_failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setState(
        const AuthenticationFailure(
          'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
        ),
      );
    }
  }

  Future<void> signOut() async {
    await googleSignInService.signOut();
    _setState(const Unauthenticated());
  }

  void _setState(AuthenticationState next) {
    _state = next;
    notifyListeners();
  }

  String _userMessage(AuthenticationException error) {
    return switch (error) {
      AuthenticationCancelled() =>
        'Inicio de sesión cancelado. Puedes intentarlo de nuevo.',
      AuthenticationProviderUnavailable() =>
        'Google Sign-In no está disponible en este dispositivo.',
      AuthenticationFailed() || AuthenticationUnknownError() =>
        'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
    };
  }
}

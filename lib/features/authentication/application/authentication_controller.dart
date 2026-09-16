import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/authentication/authentication_exception.dart';
import '../../../core/authentication/google_sign_in_service.dart';
import '../../../core/authentication/session_exception.dart';
import '../../../core/authentication/session_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import 'authentication_state.dart';

/// Coordinates Google Sign-In and NexoVending session creation.
final class AuthenticationController extends ChangeNotifier {
  AuthenticationController({
    required this.googleSignInService,
    required this.sessionService,
    required this.config,
    required this.logger,
    this.afterSessionEstablished,
    this.afterSessionCleared,
  });

  final GoogleSignInService googleSignInService;
  final SessionService sessionService;
  final AppConfig config;
  final AppLogger logger;

  /// Invoked after a valid session is created or restored (operator bootstrap).
  Future<void> Function()? afterSessionEstablished;

  /// Invoked after local session is cleared (logout / expiry).
  Future<void> Function()? afterSessionCleared;

  AuthenticationState _state = const Unauthenticated();

  AuthenticationState get state => _state;

  bool get isBusy =>
      _state is Authenticating ||
      _state is CreatingSession ||
      _state is RestoringSession;

  /// Restore a persisted session at app startup.
  Future<void> restoreSession() async {
    if (_state is RestoringSession) {
      return;
    }
    _setState(const RestoringSession());
    logger.info('session_restore_ui_started');

    final session = await sessionService.restoreSession();
    if (session == null) {
      _setState(const Unauthenticated());
      return;
    }
    _setState(Authenticated(session));
    await afterSessionEstablished?.call();
  }

  Future<void> signIn() async {
    if (isBusy) {
      return;
    }

    _setState(const Authenticating());
    logger.info('authentication_started');

    String? googleSubject;
    try {
      final googleResult = await googleSignInService.signIn();
      googleSubject = _opaqueGoogleSubject(googleResult.idToken);
      _setState(const CreatingSession());
      logger.info(
        'session_exchange_started',
        context: {'googleSubject': googleSubject},
      );

      final session = await sessionService.createSession(
        googleResult: googleResult,
        tenantId: config.tenantId,
      );
      _setState(Authenticated(session));
      await afterSessionEstablished?.call();
    } on AuthenticationCancelled {
      logger.info('authentication_cancelled');
      _setState(const Unauthenticated());
    } on AuthenticationException catch (error) {
      logger.error(
        'authentication_failed',
        error: error,
        context: {'type': error.runtimeType.toString()},
      );
      _setState(AuthenticationFailure(_googleMessage(error)));
    } on SessionExpiredException {
      await sessionService.clearSession();
      await afterSessionCleared?.call();
      _setState(const SessionExpired());
    } on SessionException catch (error) {
      logger.error(
        'session_failed',
        error: error,
        context: {
          'type': error.runtimeType.toString(),
          'googleSubject': googleSubject,
        },
      );
      _setState(SessionFailure(_sessionMessage(error)));
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

  /// Decodes the opaque Google `sub` claim without logging the id_token.
  static String? _opaqueGoogleSubject(String idToken) {
    final parts = idToken.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is Map && payload['sub'] is String) {
        final sub = (payload['sub'] as String).trim();
        return sub.isEmpty ? null : sub;
      }
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
    return null;
  }

  Future<void> signOut() async {
    await sessionService.clearSession();
    await afterSessionCleared?.call();
    _setState(const Unauthenticated());
  }

  /// Called when a protected API reports session expiry (e.g. `/operators/me` 401).
  Future<void> handleSessionExpired() async {
    await sessionService.clearSession();
    await afterSessionCleared?.call();
    _setState(const SessionExpired());
  }

  void _setState(AuthenticationState next) {
    _state = next;
    notifyListeners();
  }

  String _googleMessage(AuthenticationException error) {
    return switch (error) {
      AuthenticationCancelled() =>
        'Inicio de sesión cancelado. Puedes intentarlo de nuevo.',
      AuthenticationProviderUnavailable() =>
        'Google Sign-In no está disponible en este dispositivo.',
      AuthenticationFailed() || AuthenticationUnknownError() =>
        'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
    };
  }

  String _sessionMessage(SessionException error) {
    return switch (error) {
      SessionAuthenticationFailed() => error.message,
      SessionAccessDenied() => error.message,
      SessionNetworkFailure() => error.message,
      SessionInvalidResponse() => error.message,
      SessionExpiredException() => error.message,
      SessionUnknownError() => error.message,
    };
  }
}

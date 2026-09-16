import 'package:google_sign_in/google_sign_in.dart';

import '../logging/app_logger.dart';
import 'authentication_exception.dart';
import 'google_authentication_result.dart';
import 'google_sign_in_config.dart';
import 'google_sign_in_service.dart';

/// Google Sign-In implementation backed by the official Flutter SDK.
final class SdkGoogleSignInService implements GoogleSignInService {
  SdkGoogleSignInService({
    required this.config,
    required this.logger,
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignInConfig config;
  final AppLogger logger;
  final GoogleSignIn _googleSignIn;

  GoogleAuthenticationResult? _current;
  Future<void>? _initialization;

  Future<void> _ensureInitialized() {
    return _initialization ??= _googleSignIn.initialize(
      clientId: config.iosClientId,
      serverClientId: config.serverClientId,
    );
  }

  @override
  Future<GoogleAuthenticationResult> signIn() async {
    try {
      await _ensureInitialized();

      if (!_googleSignIn.supportsAuthenticate()) {
        throw const AuthenticationProviderUnavailable(
          message:
              'Interactive Google Sign-In is not supported on this platform',
        );
      }

      final account = await _googleSignIn.authenticate();
      final result = _toResult(account);
      _current = result;
      logger.info(
        'authentication_succeeded',
        context: {
          'email': result.email,
          // Opaque Google subject used by Vending operator seeding (not the id_token).
          'googleSubject': account.id,
        },
      );
      return result;
    } on AuthenticationException {
      rethrow;
    } on GoogleSignInException catch (error, stackTrace) {
      throw _mapGoogleException(error, stackTrace);
    } catch (error, stackTrace) {
      logger.error(
        'authentication_failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AuthenticationUnknownError(
        'Unexpected Google Sign-In failure',
        cause: error,
      );
    }
  }

  @override
  Future<GoogleAuthenticationResult?> getCurrentUser() async {
    if (_current != null) {
      return _current;
    }

    try {
      await _ensureInitialized();
      final lightweight = _googleSignIn.attemptLightweightAuthentication();
      if (lightweight == null) {
        return null;
      }
      final account = await lightweight;
      if (account == null) {
        return null;
      }
      final result = _toResult(account);
      _current = result;
      return result;
    } on AuthenticationException {
      rethrow;
    } on GoogleSignInException catch (error, stackTrace) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw _mapGoogleException(error, stackTrace);
    } catch (error, stackTrace) {
      logger.error(
        'authentication_failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AuthenticationUnknownError(
        'Unexpected Google Sign-In failure',
        cause: error,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
    } on GoogleSignInException catch (error, stackTrace) {
      throw _mapGoogleException(error, stackTrace);
    } finally {
      _current = null;
    }
  }

  GoogleAuthenticationResult _toResult(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw const AuthenticationFailed(
        'Google Sign-In succeeded without an id_token',
      );
    }

    return GoogleAuthenticationResult(
      idToken: idToken,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }

  AuthenticationException _mapGoogleException(
    GoogleSignInException error,
    StackTrace stackTrace,
  ) {
    final providerContext = <String, Object?>{
      'providerCode': error.code.name,
      // Credential Manager often reports OAuth misconfig as "canceled".
      'description': error.description,
      'details': error.details?.toString(),
    };

    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        logger.info('authentication_cancelled', context: providerContext);
        return AuthenticationCancelled(cause: error);
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.uiUnavailable:
        logger.error(
          'authentication_failed',
          error: error,
          stackTrace: stackTrace,
          context: providerContext,
        );
        return AuthenticationProviderUnavailable(
          message: 'Google Sign-In UI is unavailable',
          cause: error,
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
      case GoogleSignInExceptionCode.userMismatch:
      case GoogleSignInExceptionCode.unknownError:
        logger.error(
          'authentication_failed',
          error: error,
          stackTrace: stackTrace,
          context: providerContext,
        );
        return AuthenticationFailed('Google Sign-In failed', cause: error);
    }
  }
}

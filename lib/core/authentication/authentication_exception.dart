import '../errors/app_exception.dart';

/// Authentication failures owned by VendingApp (not the Google SDK).
sealed class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.cause});
}

/// User dismissed or cancelled Google Sign-In.
final class AuthenticationCancelled extends AuthenticationException {
  const AuthenticationCancelled({
    String message = 'Google Sign-In was cancelled',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Google Sign-In completed without a usable identity / id_token.
final class AuthenticationFailed extends AuthenticationException {
  const AuthenticationFailed(super.message, {super.cause});
}

/// The Google Sign-In provider is unavailable on this device/platform.
final class AuthenticationProviderUnavailable extends AuthenticationException {
  const AuthenticationProviderUnavailable({
    String message = 'Google Sign-In is unavailable',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Unexpected authentication failure.
final class AuthenticationUnknownError extends AuthenticationException {
  const AuthenticationUnknownError(super.message, {super.cause});
}

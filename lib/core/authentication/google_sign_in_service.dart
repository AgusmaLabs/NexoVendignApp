import 'google_authentication_result.dart';

/// Abstraction over the Google Sign-In provider.
///
/// Hides the concrete Google SDK from features and UI.
abstract interface class GoogleSignInService {
  /// Starts interactive Google Sign-In and returns a result with [idToken].
  Future<GoogleAuthenticationResult> signIn();

  /// Returns the in-memory Google user if already signed in, otherwise null.
  Future<GoogleAuthenticationResult?> getCurrentUser();

  /// Signs out of the Google provider (does not clear a NexoVending session).
  Future<void> signOut();
}

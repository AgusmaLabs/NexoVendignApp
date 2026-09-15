import 'google_authentication_result.dart';
import 'session.dart';

/// Creates, restores, and clears NexoVending sessions.
abstract interface class SessionService {
  /// Current in-memory session after [createSession] / [restoreSession], if valid.
  Session? get currentSession;

  /// Exchange Google [idToken] + [tenantId] for a NexoVending session JWT.
  Future<Session> createSession({
    required GoogleAuthenticationResult googleResult,
    required String tenantId,
  });

  /// Load a non-expired session from secure storage, or `null`.
  Future<Session?> restoreSession();

  /// Whether a non-expired session is available in memory.
  bool get hasValidSession;

  /// Clear in-memory and persisted session material.
  Future<void> clearSession();
}

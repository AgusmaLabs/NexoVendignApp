import 'dart:convert';

import '../logging/app_logger.dart';
import '../networking/api_client.dart';
import '../networking/api_exception.dart';
import '../storage/secure_storage.dart';
import '../time/clock.dart';
import 'google_authentication_result.dart';
import 'session.dart';
import 'session_credential_provider.dart';
import 'session_exception.dart';
import 'session_service.dart';

/// Default [SessionService] using NexoVending `POST /api/v1/auth/session`.
final class HttpSessionService
    implements SessionService, SessionCredentialProvider {
  HttpSessionService({
    required this.apiClient,
    required this.secureStorage,
    required this.logger,
    required this.clock,
    this.sessionPath = '/api/v1/auth/session',
    this.storageKey = defaultStorageKey,
  });

  static const String defaultStorageKey = 'nexo.vending.session';

  final ApiClient apiClient;
  final SecureStorage secureStorage;
  final AppLogger logger;
  final Clock clock;
  final String sessionPath;
  final String storageKey;

  Session? _current;

  @override
  Session? get currentSession {
    final session = _current;
    if (session == null) {
      return null;
    }
    if (session.isExpiredAt(clock.now())) {
      return null;
    }
    return session;
  }

  @override
  bool get hasValidSession => currentSession != null;

  @override
  Future<String?> authorizationHeader() async {
    final session = currentSession;
    if (session == null) {
      return null;
    }
    return session.authorizationHeader;
  }

  @override
  Future<Session> createSession({
    required GoogleAuthenticationResult googleResult,
    required String tenantId,
  }) async {
    final trimmedTenant = tenantId.trim();
    if (trimmedTenant.isEmpty) {
      throw ArgumentError.value(tenantId, 'tenantId', 'must not be empty');
    }

    logger.info('session_create_started');

    try {
      final response = await apiClient.post(
        sessionPath,
        body: <String, Object?>{
          'id_token': googleResult.idToken,
          'tenant_id': trimmedTenant,
        },
      );

      final decoded = _decodeJsonObject(response.body);
      final session = Session.fromApiResponse(decoded, issuedAt: clock.now());
      await _persist(session);
      _current = session;
      logger.info(
        'session_create_succeeded',
        context: {'expiresIn': session.expiresIn},
      );
      return session;
    } on SessionException {
      rethrow;
    } on HttpException catch (error) {
      throw _mapHttp(error);
    } on TimeoutException catch (error) {
      throw SessionNetworkFailure(cause: error);
    } on NetworkException catch (error) {
      throw SessionNetworkFailure(cause: error);
    } on FormatException catch (error) {
      throw SessionInvalidResponse(cause: error);
    } on SerializationException catch (error) {
      throw SessionInvalidResponse(cause: error);
    } catch (error) {
      throw SessionUnknownError(cause: error);
    }
  }

  @override
  Future<Session?> restoreSession() async {
    logger.info('session_restore_started');
    final raw = await secureStorage.read(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      _current = null;
      logger.info('session_restore_empty');
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clearSession();
        return null;
      }
      final session = Session.fromJson(
        Map<String, Object?>.from(decoded),
        now: clock.now,
      );
      if (session.isExpiredAt(clock.now())) {
        logger.info('session_restore_expired');
        await clearSession();
        return null;
      }
      _current = session;
      logger.info('session_restore_succeeded');
      return session;
    } catch (error) {
      logger.warning(
        'session_restore_failed',
        context: {'type': error.runtimeType.toString()},
      );
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    _current = null;
    await secureStorage.remove(storageKey);
    logger.info('session_cleared');
  }

  Future<void> _persist(Session session) async {
    await secureStorage.write(storageKey, jsonEncode(session.toJson()));
  }

  Map<String, Object?> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Session response is not a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  SessionException _mapHttp(HttpException error) {
    return switch (error.statusCode) {
      401 => const SessionAuthenticationFailed(),
      403 => const SessionAccessDenied(),
      400 || 422 => const SessionInvalidResponse(),
      _ => SessionUnknownError(cause: error),
    };
  }
}

import 'package:vendingapp/app/bootstrap/app_dependencies.dart';
import 'package:vendingapp/core/authentication/authentication_exception.dart';
import 'package:vendingapp/core/authentication/google_authentication_result.dart';
import 'package:vendingapp/core/authentication/google_sign_in_config.dart';
import 'package:vendingapp/core/authentication/google_sign_in_service.dart';
import 'package:vendingapp/core/authentication/session.dart';
import 'package:vendingapp/core/authentication/session_credential_provider.dart';
import 'package:vendingapp/core/authentication/session_service.dart';
import 'package:vendingapp/core/config/app_config.dart';
import 'package:vendingapp/core/device/barcode_scanner.dart';
import 'package:vendingapp/core/device/connectivity_service.dart';
import 'package:vendingapp/core/device/location_service.dart';
import 'package:vendingapp/core/logging/app_logger.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/networking/api_request.dart';
import 'package:vendingapp/core/networking/api_response.dart';
import 'package:vendingapp/core/networking/request_id.dart';
import 'package:vendingapp/core/storage/local_storage.dart';
import 'package:vendingapp/core/storage/secure_storage.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/authentication/application/authentication_controller.dart';
import 'package:vendingapp/features/machine/application/machine_identification_controller.dart';
import 'package:vendingapp/features/machine/domain/machine.dart';
import 'package:vendingapp/features/machine/domain/machine_service.dart';
import 'package:vendingapp/features/operator/application/operator_bootstrap_controller.dart';
import 'package:vendingapp/features/operator/domain/operator.dart';
import 'package:vendingapp/features/operator/domain/operator_service.dart';

AppConfig testConfig({
  String apiBaseUrl = 'http://localhost:8080',
  String tenantId = 'tenant-a',
  Duration httpTimeout = const Duration(seconds: 30),
}) {
  return AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: apiBaseUrl,
    tenantId: tenantId,
    httpTimeout: httpTimeout,
  );
}

GoogleAuthenticationResult fakeGoogleResult({
  String idToken = 'fake-google-id-token',
  String? email = 'operator@example.com',
  String? displayName = 'Operator',
  String? photoUrl,
}) {
  return GoogleAuthenticationResult(
    idToken: idToken,
    email: email,
    displayName: displayName,
    photoUrl: photoUrl,
  );
}

Session fakeSession({
  String accessToken = 'test-session-token',
  String tokenType = 'Bearer',
  int expiresIn = 3600,
  DateTime? expiresAt,
  DateTime? issuedAt,
}) {
  final issued = (issuedAt ?? DateTime.utc(2026, 9, 15, 12)).toUtc();
  return Session(
    accessToken: accessToken,
    tokenType: tokenType,
    expiresIn: expiresIn,
    expiresAt: expiresAt ?? issued.add(Duration(seconds: expiresIn)),
  );
}

Operator fakeOperator({
  String operatorId = 'op-1',
  String tenantId = 'tenant-a',
  String role = 'replenisher',
  String status = 'active',
  String? displayName = 'Ada Operator',
  String? email = 'operator@example.com',
  String provider = 'google',
  String subject = 'google-sub-1',
}) {
  return Operator(
    operatorId: operatorId,
    tenantId: tenantId,
    role: role,
    status: status,
    displayName: displayName,
    email: email,
    provider: provider,
    subject: subject,
  );
}

Machine fakeMachine({
  String machineId = '11111111-1111-1111-1111-111111111111',
  String identifier = 'MIX-001',
  String machineType = 'SNACK',
  String name = 'Lobby',
  String status = 'ACTIVE',
}) {
  return Machine(
    machineId: machineId,
    identifier: identifier,
    machineType: machineType,
    name: name,
    status: status,
  );
}

AppDependencies testDependencies({
  AppConfig? config,
  GoogleSignInConfig? googleSignInConfig,
  AppLogger? logger,
  LocalStorage? localStorage,
  SecureStorage? secureStorage,
  ApiClient? apiClient,
  RequestIdGenerator? requestIdGenerator,
  ConnectivityService? connectivityService,
  LocationService? locationService,
  BarcodeScanner? barcodeScanner,
  GoogleSignInService? googleSignInService,
  SessionService? sessionService,
  OperatorService? operatorService,
  OperatorBootstrapController? operatorBootstrapController,
  MachineService? machineService,
  MachineIdentificationController? machineIdentificationController,
  AuthenticationController? authenticationController,
  Clock? clock,
  bool wireOperatorBootstrap = true,
}) {
  final resolvedConfig = config ?? testConfig();
  final resolvedLogger = logger ?? RecordingAppLogger();
  final resolvedGoogleSignIn = googleSignInService ?? FakeGoogleSignInService();
  final resolvedClock = clock ?? FakeClock(DateTime.utc(2026, 9, 15, 12));
  final resolvedSession =
      sessionService ?? FakeSessionService(clock: resolvedClock);
  final resolvedOperator = operatorService ?? FakeOperatorService();
  final resolvedMachine = machineService ?? FakeMachineService();

  late final AuthenticationController resolvedAuthController;
  final resolvedBootstrap =
      operatorBootstrapController ??
      OperatorBootstrapController(
        operatorService: resolvedOperator,
        sessionService: resolvedSession,
        logger: resolvedLogger,
        onSessionExpired: () => resolvedAuthController.handleSessionExpired(),
      );
  final resolvedMachineController =
      machineIdentificationController ??
      MachineIdentificationController(
        machineService: resolvedMachine,
        sessionService: resolvedSession,
        logger: resolvedLogger,
        onSessionExpired: () => resolvedAuthController.handleSessionExpired(),
      );

  resolvedAuthController =
      authenticationController ??
      AuthenticationController(
        googleSignInService: resolvedGoogleSignIn,
        sessionService: resolvedSession,
        config: resolvedConfig,
        logger: resolvedLogger,
        afterSessionEstablished: wireOperatorBootstrap
            ? resolvedBootstrap.load
            : null,
        afterSessionCleared: wireOperatorBootstrap
            ? () async {
                await resolvedBootstrap.clear();
                await resolvedMachineController.clear();
              }
            : null,
      );

  return AppDependencies(
    config: resolvedConfig,
    googleSignInConfig: googleSignInConfig ?? const GoogleSignInConfig(),
    logger: resolvedLogger,
    localStorage: localStorage ?? MemoryLocalStorage(),
    secureStorage: secureStorage ?? MemorySecureStorage(),
    apiClient: apiClient ?? _UnusedApiClient(),
    requestIdGenerator: requestIdGenerator ?? UuidRequestIdGenerator(),
    connectivityService:
        connectivityService ?? const UnsupportedConnectivityService(),
    locationService: locationService ?? const UnsupportedLocationService(),
    barcodeScanner: barcodeScanner ?? const UnsupportedBarcodeScanner(),
    googleSignInService: resolvedGoogleSignIn,
    sessionService: resolvedSession,
    operatorService: resolvedOperator,
    operatorBootstrapController: resolvedBootstrap,
    machineService: resolvedMachine,
    machineIdentificationController: resolvedMachineController,
    authenticationController: resolvedAuthController,
    clock: resolvedClock,
  );
}

final class RecordingAppLogger implements AppLogger {
  final List<LogEntry> entries = <LogEntry>[];

  @override
  void debug(String message, {Map<String, Object?>? context}) {
    entries.add(LogEntry(LogLevel.debug, message, context: context));
  }

  @override
  void info(String message, {Map<String, Object?>? context}) {
    entries.add(LogEntry(LogLevel.info, message, context: context));
  }

  @override
  void warning(String message, {Map<String, Object?>? context}) {
    entries.add(LogEntry(LogLevel.warning, message, context: context));
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    entries.add(
      LogEntry(
        LogLevel.error,
        message,
        context: context,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  bool containsMessage(String message) {
    return entries.any((entry) => entry.message == message);
  }

  bool get hasSensitiveLeak {
    for (final entry in entries) {
      final haystack = StringBuffer(entry.message);
      if (entry.context != null) {
        haystack.write(entry.context);
      }
      if (entry.error != null) {
        haystack.write(entry.error);
      }
      final text = haystack.toString().toLowerCase();
      if (text.contains('bearer secret-token') ||
          text.contains('super-secret-password') ||
          text.contains('id_token_value') ||
          text.contains('fake-google-id-token') ||
          text.contains('test-session-token') ||
          text.contains('authorization: bearer')) {
        return true;
      }
    }
    return false;
  }
}

final class LogEntry {
  const LogEntry(
    this.level,
    this.message, {
    this.context,
    this.error,
    this.stackTrace,
  });

  final LogLevel level;
  final String message;
  final Map<String, Object?>? context;
  final Object? error;
  final StackTrace? stackTrace;
}

final class FixedRequestIdGenerator implements RequestIdGenerator {
  FixedRequestIdGenerator(this.value);

  final String value;

  @override
  String next() => value;
}

/// Deterministic Google Sign-In double for unit/widget/integration tests.
final class FakeGoogleSignInService implements GoogleSignInService {
  FakeGoogleSignInService({
    GoogleAuthenticationResult? result,
    this.error,
    this.signInDelay = Duration.zero,
  }) : result = result ?? fakeGoogleResult();

  GoogleAuthenticationResult? result;
  Object? error;
  Duration signInDelay;
  GoogleAuthenticationResult? _current;
  var signInCallCount = 0;
  var signOutCallCount = 0;

  @override
  Future<GoogleAuthenticationResult> signIn() async {
    signInCallCount += 1;
    if (signInDelay > Duration.zero) {
      await Future<void>.delayed(signInDelay);
    }
    final failure = error;
    if (failure != null) {
      if (failure is Exception) {
        throw failure;
      }
      throw AuthenticationUnknownError('$failure');
    }
    final success = result;
    if (success == null) {
      throw const AuthenticationFailed('Fake Google result is null');
    }
    _current = success;
    return success;
  }

  @override
  Future<GoogleAuthenticationResult?> getCurrentUser() async => _current;

  @override
  Future<void> signOut() async {
    signOutCallCount += 1;
    _current = null;
  }
}

final class FakeSessionService
    implements SessionService, SessionCredentialProvider {
  FakeSessionService({
    required this.clock,
    this.session,
    this.createError,
    this.restoreResult,
  });

  final Clock clock;
  Session? session;
  Object? createError;
  Session? restoreResult;
  var createCallCount = 0;
  var clearCallCount = 0;
  GoogleAuthenticationResult? lastGoogleResult;
  String? lastTenantId;

  @override
  Session? get currentSession {
    final current = session;
    if (current == null) {
      return null;
    }
    if (current.isExpiredAt(clock.now())) {
      return null;
    }
    return current;
  }

  @override
  bool get hasValidSession => currentSession != null;

  @override
  Future<String?> authorizationHeader() async {
    final current = currentSession;
    return current?.authorizationHeader;
  }

  @override
  Future<Session> createSession({
    required GoogleAuthenticationResult googleResult,
    required String tenantId,
  }) async {
    createCallCount += 1;
    lastGoogleResult = googleResult;
    lastTenantId = tenantId;
    final failure = createError;
    if (failure != null) {
      if (failure is Exception) {
        throw failure;
      }
      throw Exception('$failure');
    }
    final created =
        session ??
        fakeSession(
          issuedAt: clock.now(),
          expiresAt: clock.now().add(const Duration(hours: 1)),
        );
    session = created;
    return created;
  }

  @override
  Future<Session?> restoreSession() async {
    if (restoreResult != null) {
      session = restoreResult;
      return restoreResult;
    }
    final current = session;
    if (current == null || current.isExpiredAt(clock.now())) {
      session = null;
      return null;
    }
    return current;
  }

  @override
  Future<void> clearSession() async {
    clearCallCount += 1;
    session = null;
  }
}

final class FakeOperatorService implements OperatorService {
  FakeOperatorService({this.operator, this.error, this.delay = Duration.zero});

  Operator? operator;
  Object? error;
  Duration delay;
  var callCount = 0;

  @override
  Future<Operator> getCurrentOperator() async {
    callCount += 1;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final failure = error;
    if (failure != null) {
      if (failure is Exception) {
        throw failure;
      }
      throw Exception('$failure');
    }
    return operator ?? fakeOperator();
  }
}

final class FakeMachineService implements MachineService {
  FakeMachineService({this.machine, this.error, this.delay = Duration.zero});

  Machine? machine;
  Object? error;
  Duration delay;
  var callCount = 0;
  String? lastIdentifier;

  @override
  Future<Machine> resolveMachine(String identifier) async {
    callCount += 1;
    lastIdentifier = identifier;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final failure = error;
    if (failure != null) {
      if (failure is Exception) {
        throw failure;
      }
      throw Exception('$failure');
    }
    return machine ?? fakeMachine();
  }
}

final class _UnusedApiClient implements ApiClient {
  Never _unused() => throw StateError('ApiClient was not provided to the test');

  @override
  Future<ApiResponse> send(ApiRequest request) async => _unused();

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    String? requestId,
    bool authenticated = false,
  }) async => _unused();

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  }) async => _unused();

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  }) async => _unused();

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  }) async => _unused();

  @override
  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
    bool authenticated = false,
  }) async => _unused();
}

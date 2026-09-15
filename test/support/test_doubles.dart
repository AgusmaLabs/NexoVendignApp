import 'package:vendingapp/app/bootstrap/app_dependencies.dart';
import 'package:vendingapp/core/authentication/authentication_exception.dart';
import 'package:vendingapp/core/authentication/google_authentication_result.dart';
import 'package:vendingapp/core/authentication/google_sign_in_config.dart';
import 'package:vendingapp/core/authentication/google_sign_in_service.dart';
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
import 'package:vendingapp/features/authentication/application/authentication_controller.dart';

AppConfig testConfig({
  String apiBaseUrl = 'http://localhost:8080',
  Duration httpTimeout = const Duration(seconds: 30),
}) {
  return AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: apiBaseUrl,
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
  AuthenticationController? authenticationController,
}) {
  final resolvedConfig = config ?? testConfig();
  final resolvedLogger = logger ?? RecordingAppLogger();
  final resolvedGoogleSignIn = googleSignInService ?? FakeGoogleSignInService();
  final resolvedAuthController =
      authenticationController ??
      AuthenticationController(
        googleSignInService: resolvedGoogleSignIn,
        logger: resolvedLogger,
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
    authenticationController: resolvedAuthController,
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
          text.contains('fake-google-id-token')) {
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
  }) async => _unused();

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
  }) async => _unused();

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
  }) async => _unused();

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
  }) async => _unused();

  @override
  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    String? requestId,
  }) async => _unused();
}

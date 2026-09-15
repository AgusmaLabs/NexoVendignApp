import 'package:flutter/widgets.dart';

import '../../core/authentication/google_sign_in_config.dart';
import '../../core/authentication/google_sign_in_service.dart';
import '../../core/authentication/sdk_google_sign_in_service.dart';
import '../../core/config/app_config.dart';
import '../../core/device/barcode_scanner.dart';
import '../../core/device/connectivity_service.dart';
import '../../core/device/location_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/networking/api_client.dart';
import '../../core/networking/request_id.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/authentication/application/authentication_controller.dart';

/// Composition root for VendingApp infrastructure dependencies.
///
/// Features must receive these collaborators via injection — never construct
/// HTTP clients, storage, or device services inside widgets.
final class AppDependencies {
  AppDependencies({
    required this.config,
    required this.googleSignInConfig,
    required this.logger,
    required this.localStorage,
    required this.secureStorage,
    required this.apiClient,
    required this.requestIdGenerator,
    required this.connectivityService,
    required this.locationService,
    required this.barcodeScanner,
    required this.googleSignInService,
    required this.authenticationController,
  });

  final AppConfig config;
  final GoogleSignInConfig googleSignInConfig;
  final AppLogger logger;
  final LocalStorage localStorage;
  final SecureStorage secureStorage;
  final ApiClient apiClient;
  final RequestIdGenerator requestIdGenerator;
  final ConnectivityService connectivityService;
  final LocationService locationService;
  final BarcodeScanner barcodeScanner;
  final GoogleSignInService googleSignInService;
  final AuthenticationController authenticationController;

  /// Builds the default production/development dependency graph.
  factory AppDependencies.create(AppConfig config) {
    final logger = ConsoleAppLogger(
      minimumLevel: config.environment == AppEnvironment.production
          ? LogLevel.info
          : LogLevel.debug,
    );
    final requestIdGenerator = UuidRequestIdGenerator();
    final apiClient = HttpApiClient(
      config: config,
      logger: logger,
      requestIdGenerator: requestIdGenerator,
    );
    final googleSignInConfig = GoogleSignInConfig.fromEnvironment(
      config.environment,
    );
    final googleSignInService = SdkGoogleSignInService(
      config: googleSignInConfig,
      logger: logger,
    );
    final authenticationController = AuthenticationController(
      googleSignInService: googleSignInService,
      logger: logger,
    );

    return AppDependencies(
      config: config,
      googleSignInConfig: googleSignInConfig,
      logger: logger,
      localStorage: MemoryLocalStorage(),
      secureStorage: MemorySecureStorage(),
      apiClient: apiClient,
      requestIdGenerator: requestIdGenerator,
      connectivityService: const UnsupportedConnectivityService(),
      locationService: const UnsupportedLocationService(),
      barcodeScanner: const UnsupportedBarcodeScanner(),
      googleSignInService: googleSignInService,
      authenticationController: authenticationController,
    );
  }
}

/// Exposes [AppDependencies] to the widget tree for injectable infrastructure.
final class AppDependenciesScope extends InheritedWidget {
  const AppDependenciesScope({
    required this.dependencies,
    required super.child,
    super.key,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppDependenciesScope>();
    assert(scope != null, 'AppDependenciesScope not found in the widget tree');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppDependenciesScope oldWidget) {
    return dependencies != oldWidget.dependencies;
  }
}

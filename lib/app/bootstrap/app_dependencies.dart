import 'package:flutter/widgets.dart';

import '../../core/config/app_config.dart';
import '../../core/device/barcode_scanner.dart';
import '../../core/device/connectivity_service.dart';
import '../../core/device/location_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/networking/api_client.dart';
import '../../core/networking/request_id.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';

/// Composition root for VendingApp infrastructure dependencies.
///
/// Features must receive these collaborators via injection — never construct
/// HTTP clients, storage, or device services inside widgets.
final class AppDependencies {
  AppDependencies({
    required this.config,
    required this.logger,
    required this.localStorage,
    required this.secureStorage,
    required this.apiClient,
    required this.requestIdGenerator,
    required this.connectivityService,
    required this.locationService,
    required this.barcodeScanner,
  });

  final AppConfig config;
  final AppLogger logger;
  final LocalStorage localStorage;
  final SecureStorage secureStorage;
  final ApiClient apiClient;
  final RequestIdGenerator requestIdGenerator;
  final ConnectivityService connectivityService;
  final LocationService locationService;
  final BarcodeScanner barcodeScanner;

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

    return AppDependencies(
      config: config,
      logger: logger,
      localStorage: MemoryLocalStorage(),
      secureStorage: MemorySecureStorage(),
      apiClient: apiClient,
      requestIdGenerator: requestIdGenerator,
      connectivityService: const UnsupportedConnectivityService(),
      locationService: const UnsupportedLocationService(),
      barcodeScanner: const UnsupportedBarcodeScanner(),
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

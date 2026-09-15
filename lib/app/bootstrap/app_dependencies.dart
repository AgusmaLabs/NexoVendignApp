import 'package:flutter/widgets.dart';

import '../../core/authentication/google_sign_in_config.dart';
import '../../core/authentication/google_sign_in_service.dart';
import '../../core/authentication/http_session_service.dart';
import '../../core/authentication/sdk_google_sign_in_service.dart';
import '../../core/authentication/session_credential_provider.dart';
import '../../core/authentication/session_service.dart';
import '../../core/config/app_config.dart';
import '../../core/device/barcode_scanner.dart';
import '../../core/device/connectivity_service.dart';
import '../../core/device/location_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/networking/api_client.dart';
import '../../core/networking/request_id.dart';
import '../../core/storage/flutter_secure_storage_adapter.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/time/clock.dart';
import '../../features/authentication/application/authentication_controller.dart';
import '../../features/machine/application/machine_detail_controller.dart';
import '../../features/machine/application/machine_identification_controller.dart';
import '../../features/machine/data/api_machine_detail_service.dart';
import '../../features/machine/data/api_machine_service.dart';
import '../../features/machine/data/api_machine_slot_service.dart';
import '../../features/machine/domain/machine_detail_service.dart';
import '../../features/machine/domain/machine_service.dart';
import '../../features/machine/domain/machine_slot_service.dart';
import '../../features/operator/application/operator_bootstrap_controller.dart';
import '../../features/operator/data/api_operator_service.dart';
import '../../features/operator/domain/operator_service.dart';
import '../../features/replenishment/application/replenishment_creation_controller.dart';
import '../../features/replenishment/data/api_replenishment_service.dart';
import '../../features/replenishment/domain/replenishment_service.dart';

/// Composition root for VendingApp infrastructure dependencies.
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
    required this.sessionService,
    required this.operatorService,
    required this.operatorBootstrapController,
    required this.machineService,
    required this.machineIdentificationController,
    required this.machineDetailService,
    required this.machineSlotService,
    required this.machineDetailController,
    required this.replenishmentService,
    required this.replenishmentCreationController,
    required this.authenticationController,
    required this.clock,
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
  final SessionService sessionService;
  final OperatorService operatorService;
  final OperatorBootstrapController operatorBootstrapController;
  final MachineService machineService;
  final MachineIdentificationController machineIdentificationController;
  final MachineDetailService machineDetailService;
  final MachineSlotService machineSlotService;
  final MachineDetailController machineDetailController;
  final ReplenishmentService replenishmentService;
  final ReplenishmentCreationController replenishmentCreationController;
  final AuthenticationController authenticationController;
  final Clock clock;

  factory AppDependencies.create(AppConfig config) {
    final logger = ConsoleAppLogger(
      minimumLevel: config.environment == AppEnvironment.production
          ? LogLevel.info
          : LogLevel.debug,
    );
    final requestIdGenerator = UuidRequestIdGenerator();
    const clock = SystemClock();
    final secureStorage = FlutterSecureStorageAdapter();
    final credentialProvider = DelegatingSessionCredentialProvider();
    final apiClient = HttpApiClient(
      config: config,
      logger: logger,
      requestIdGenerator: requestIdGenerator,
      credentialProvider: credentialProvider,
    );
    final sessionService = HttpSessionService(
      apiClient: apiClient,
      secureStorage: secureStorage,
      logger: logger,
      clock: clock,
    );
    credentialProvider.delegate = sessionService;

    final operatorService = ApiOperatorService(
      apiClient: apiClient,
      logger: logger,
    );
    final machineService = ApiMachineService(
      apiClient: apiClient,
      logger: logger,
    );
    final machineDetailService = ApiMachineDetailService(
      apiClient: apiClient,
      logger: logger,
    );
    final machineSlotService = ApiMachineSlotService(
      apiClient: apiClient,
      logger: logger,
    );
    final replenishmentService = ApiReplenishmentService(
      apiClient: apiClient,
      logger: logger,
    );

    // Contract requires GPS on create; real device GPS arrives later.
    // Development uses fixed coords so local API testing can proceed.
    final locationService = config.environment == AppEnvironment.production
        ? const UnsupportedLocationService()
        : const FixedLocationService(
            DeviceLocation(
              latitude: -35.4264,
              longitude: -71.6554,
              accuracyMeters: 12.4,
            ),
          );

    late final AuthenticationController authenticationController;
    final operatorBootstrapController = OperatorBootstrapController(
      operatorService: operatorService,
      sessionService: sessionService,
      logger: logger,
      onSessionExpired: () => authenticationController.handleSessionExpired(),
    );
    final machineIdentificationController = MachineIdentificationController(
      machineService: machineService,
      sessionService: sessionService,
      logger: logger,
      onSessionExpired: () => authenticationController.handleSessionExpired(),
    );
    final machineDetailController = MachineDetailController(
      detailService: machineDetailService,
      slotService: machineSlotService,
      sessionService: sessionService,
      logger: logger,
      onSessionExpired: () => authenticationController.handleSessionExpired(),
    );
    final replenishmentCreationController = ReplenishmentCreationController(
      replenishmentService: replenishmentService,
      machineIdentificationController: machineIdentificationController,
      operatorBootstrapController: operatorBootstrapController,
      locationService: locationService,
      sessionService: sessionService,
      requestIdGenerator: requestIdGenerator,
      logger: logger,
      onSessionExpired: () => authenticationController.handleSessionExpired(),
    );

    final googleSignInConfig = GoogleSignInConfig.fromEnvironment(
      config.environment,
    );
    final googleSignInService = SdkGoogleSignInService(
      config: googleSignInConfig,
      logger: logger,
    );
    authenticationController = AuthenticationController(
      googleSignInService: googleSignInService,
      sessionService: sessionService,
      config: config,
      logger: logger,
      afterSessionEstablished: operatorBootstrapController.load,
      afterSessionCleared: () async {
        await operatorBootstrapController.clear();
        await machineIdentificationController.clear();
        await machineDetailController.clear();
        await replenishmentCreationController.clear();
      },
    );

    return AppDependencies(
      config: config,
      googleSignInConfig: googleSignInConfig,
      logger: logger,
      localStorage: MemoryLocalStorage(),
      secureStorage: secureStorage,
      apiClient: apiClient,
      requestIdGenerator: requestIdGenerator,
      connectivityService: const UnsupportedConnectivityService(),
      locationService: locationService,
      barcodeScanner: const UnsupportedBarcodeScanner(),
      googleSignInService: googleSignInService,
      sessionService: sessionService,
      operatorService: operatorService,
      operatorBootstrapController: operatorBootstrapController,
      machineService: machineService,
      machineIdentificationController: machineIdentificationController,
      machineDetailService: machineDetailService,
      machineSlotService: machineSlotService,
      machineDetailController: machineDetailController,
      replenishmentService: replenishmentService,
      replenishmentCreationController: replenishmentCreationController,
      authenticationController: authenticationController,
      clock: clock,
    );
  }
}

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

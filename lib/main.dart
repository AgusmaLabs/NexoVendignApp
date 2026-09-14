import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/bootstrap/app_dependencies.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig(
    environment: _environmentFromString(
      const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
    ),
    apiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    httpTimeout: const Duration(
      milliseconds: int.fromEnvironment('HTTP_TIMEOUT_MS', defaultValue: 30000),
    ),
  );

  final dependencies = AppDependencies.create(config);
  runApp(VendingApp(dependencies: dependencies));
}

AppEnvironment _environmentFromString(String value) {
  return switch (value.toLowerCase()) {
    'staging' => AppEnvironment.staging,
    'production' => AppEnvironment.production,
    _ => AppEnvironment.development,
  };
}

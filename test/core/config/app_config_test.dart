import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('preserves environment and apiBaseUrl', () {
      final config = AppConfig(
        environment: AppEnvironment.staging,
        apiBaseUrl: 'https://api.example.com',
      );

      expect(config.environment, AppEnvironment.staging);
      expect(config.apiBaseUrl, 'https://api.example.com');
    });

    test('rejects an empty apiBaseUrl', () {
      expect(
        () =>
            AppConfig(environment: AppEnvironment.development, apiBaseUrl: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a blank apiBaseUrl', () {
      expect(
        () => AppConfig(
          environment: AppEnvironment.production,
          apiBaseUrl: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

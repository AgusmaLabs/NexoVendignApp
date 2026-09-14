import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('preserves environment, apiBaseUrl, and httpTimeout', () {
      final config = AppConfig(
        environment: AppEnvironment.staging,
        apiBaseUrl: 'https://api.example.com',
        httpTimeout: const Duration(seconds: 15),
      );

      expect(config.environment, AppEnvironment.staging);
      expect(config.apiBaseUrl, 'https://api.example.com');
      expect(config.httpTimeout, const Duration(seconds: 15));
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

    test('rejects a non-positive httpTimeout', () {
      expect(
        () => AppConfig(
          environment: AppEnvironment.development,
          apiBaseUrl: 'http://localhost:8080',
          httpTimeout: Duration.zero,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

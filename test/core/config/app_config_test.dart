import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('preserves environment, apiBaseUrl, tenantId, and httpTimeout', () {
      final config = AppConfig(
        environment: AppEnvironment.staging,
        apiBaseUrl: 'https://api.example.com',
        tenantId: 'tenant-a',
        httpTimeout: const Duration(seconds: 15),
      );

      expect(config.environment, AppEnvironment.staging);
      expect(config.apiBaseUrl, 'https://api.example.com');
      expect(config.tenantId, 'tenant-a');
      expect(config.httpTimeout, const Duration(seconds: 15));
    });

    test('rejects an empty apiBaseUrl', () {
      expect(
        () => AppConfig(
          environment: AppEnvironment.development,
          apiBaseUrl: '',
          tenantId: 'tenant-a',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a blank tenantId', () {
      expect(
        () => AppConfig(
          environment: AppEnvironment.development,
          apiBaseUrl: 'http://localhost:8080',
          tenantId: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a blank apiBaseUrl', () {
      expect(
        () => AppConfig(
          environment: AppEnvironment.production,
          apiBaseUrl: '   ',
          tenantId: 'tenant-a',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a non-positive httpTimeout', () {
      expect(
        () => AppConfig(
          environment: AppEnvironment.development,
          apiBaseUrl: 'http://localhost:8080',
          tenantId: 'tenant-a',
          httpTimeout: Duration.zero,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

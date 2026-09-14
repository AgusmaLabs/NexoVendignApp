import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/logging/app_logger.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/networking/api_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  group('AppLogger networking', () {
    test('HTTP events include method, status, and request ID', () async {
      final logger = RecordingAppLogger();
      final client = HttpApiClient(
        config: testConfig(),
        logger: logger,
        requestIdGenerator: FixedRequestIdGenerator('log-request-id'),
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );

      await client.get('/machines');

      expect(
        logger.entries.any(
          (entry) =>
              entry.message == 'HTTP request' &&
              entry.context?['requestId'] == 'log-request-id' &&
              entry.context?['method'] == 'GET' &&
              entry.context?['endpoint'] == '/machines',
        ),
        isTrue,
      );
      expect(
        logger.entries.any(
          (entry) =>
              entry.message == 'HTTP response' &&
              entry.context?['status'] == 200 &&
              entry.context?['requestId'] == 'log-request-id',
        ),
        isTrue,
      );
    });

    test('errors are logged with request ID', () async {
      final logger = RecordingAppLogger();
      final client = HttpApiClient(
        config: testConfig(),
        logger: logger,
        requestIdGenerator: FixedRequestIdGenerator('error-request-id'),
        httpClient: MockClient((request) async => http.Response('nope', 500)),
      );

      await expectLater(client.get('/boom'), throwsA(isA<HttpException>()));

      expect(
        logger.entries.any(
          (entry) =>
              entry.level == LogLevel.error &&
              entry.context?['requestId'] == 'error-request-id' &&
              entry.context?['status'] == 500,
        ),
        isTrue,
      );
    });

    test('sanitizeLogContext drops tokens and secrets', () {
      final sanitized = sanitizeLogContext({
        'requestId': 'abc',
        'authorization': 'Bearer secret-token',
        'access_token': 'secret',
        'id_token': 'id_token_value',
        'password': 'super-secret-password',
        'status': 200,
      });

      expect(sanitized, {'requestId': 'abc', 'status': 200});
    });

    test('logger does not leak secrets from context', () {
      final logger = RecordingAppLogger();
      logger.info(
        'safe event',
        context: sanitizeLogContext({
          'authorization': 'Bearer secret-token',
          'password': 'super-secret-password',
          'id_token': 'id_token_value',
          'requestId': 'r1',
        }),
      );

      expect(logger.hasSensitiveLeak, isFalse);
      expect(logger.entries.single.context, {'requestId': 'r1'});
    });
  });
}

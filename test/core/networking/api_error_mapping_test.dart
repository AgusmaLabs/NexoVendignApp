import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/networking/api_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  group('API error mapping', () {
    HttpApiClient clientFor(Future<http.Response> Function() handler) {
      return HttpApiClient(
        config: testConfig(),
        logger: RecordingAppLogger(),
        requestIdGenerator: FixedRequestIdGenerator('err-id'),
        httpClient: MockClient((request) => handler()),
      );
    }

    test('HTTP 401 becomes HttpException(statusCode: 401)', () async {
      final client = clientFor(() async => http.Response('unauthorized', 401));

      expect(
        () => client.get('/secure'),
        throwsA(
          isA<HttpException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.requestId, 'requestId', 'err-id'),
        ),
      );
    });

    test('timeout becomes TimeoutException', () async {
      final client = HttpApiClient(
        config: testConfig(httpTimeout: const Duration(milliseconds: 15)),
        logger: RecordingAppLogger(),
        requestIdGenerator: FixedRequestIdGenerator('err-id'),
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return http.Response('{}', 200);
        }),
      );

      expect(() => client.get('/slow'), throwsA(isA<TimeoutException>()));
    });

    test('network failure becomes NetworkException', () async {
      final client = clientFor(() async {
        throw http.ClientException('failed host lookup');
      });

      expect(() => client.get('/down'), throwsA(isA<NetworkException>()));
    });

    test('package HTTP exceptions do not escape as raw types', () async {
      final client = clientFor(() async {
        throw http.ClientException('boom');
      });

      try {
        await client.get('/down');
        fail('expected NetworkException');
      } on NetworkException {
        // expected
      } on http.ClientException {
        fail('raw http.ClientException escaped');
      }
    });
  });
}

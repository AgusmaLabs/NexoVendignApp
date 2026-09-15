import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/networking/api_exception.dart';
import 'package:vendingapp/core/networking/request_id.dart';
import 'package:vendingapp/core/time/clock.dart';

import '../../support/test_doubles.dart';

void main() {
  group('HttpApiClient', () {
    late RecordingAppLogger logger;
    late FixedRequestIdGenerator requestIds;

    setUp(() {
      logger = RecordingAppLogger();
      requestIds = FixedRequestIdGenerator('generated-request-id');
    });

    HttpApiClient buildClient({
      required http.Client httpClient,
      String baseUrl = 'http://example.test',
      Duration timeout = const Duration(seconds: 30),
    }) {
      return HttpApiClient(
        config: testConfig(apiBaseUrl: baseUrl, httpTimeout: timeout),
        logger: logger,
        requestIdGenerator: requestIds,
        httpClient: httpClient,
      );
    }

    test('GET success uses base URL and returns body', () async {
      late Uri capturedUri;
      final client = buildClient(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response('{"ok":true}', 200);
        }),
      );

      final response = await client.get('/health');

      expect(capturedUri.toString(), 'http://example.test/health');
      expect(response.statusCode, 200);
      expect(response.body, '{"ok":true}');
      expect(response.requestId, 'generated-request-id');
    });

    test('POST success sends JSON body', () async {
      late http.Request captured;
      final client = buildClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{"id":1}', 201);
        }),
      );

      final response = await client.post(
        '/items',
        body: <String, Object?>{'name': 'water'},
      );

      expect(captured.method, 'POST');
      expect(jsonDecode(captured.body), {'name': 'water'});
      expect(captured.headers['content-type'], contains('application/json'));
      expect(response.statusCode, 201);
    });

    test('adds generated X-Request-Id header', () async {
      late http.Request captured;
      final client = buildClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await client.get('/ping');

      expect(
        captured.headers[HttpApiClient.requestIdHeader],
        'generated-request-id',
      );
    });

    test('preserves caller-supplied request ID', () async {
      late http.Request captured;
      final client = buildClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await client.get('/ping', requestId: 'explicit-id');

      expect(captured.headers[HttpApiClient.requestIdHeader], 'explicit-id');
    });

    test('forwards custom headers', () async {
      late http.Request captured;
      final client = buildClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await client.get('/ping', headers: {'X-Custom': 'value'});

      expect(captured.headers['x-custom'], 'value');
    });

    for (final status in [400, 401, 403, 404, 409, 422, 429, 500]) {
      test('maps HTTP $status to HttpException', () async {
        final client = buildClient(
          httpClient: MockClient((request) async {
            return http.Response('{"error":"$status"}', status);
          }),
        );

        expect(
          () => client.get('/fail'),
          throwsA(
            isA<HttpException>()
                .having((e) => e.statusCode, 'statusCode', status)
                .having((e) => e.body, 'body', '{"error":"$status"}')
                .having(
                  (e) => e.requestId,
                  'requestId',
                  'generated-request-id',
                ),
          ),
        );
      });
    }

    test('maps timeout to TimeoutException', () async {
      final client = buildClient(
        timeout: const Duration(milliseconds: 20),
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response('{}', 200);
        }),
      );

      expect(
        () => client.get('/slow'),
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.requestId,
            'requestId',
            'generated-request-id',
          ),
        ),
      );
    });

    test('maps ClientException to NetworkException', () async {
      final client = buildClient(
        httpClient: MockClient((request) async {
          throw http.ClientException('connection failed');
        }),
      );

      expect(() => client.get('/offline'), throwsA(isA<NetworkException>()));
    });

    test('maps serialization failure for request body', () async {
      final client = buildClient(
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );

      expect(
        () => client.post('/bad', body: Object()),
        throwsA(isA<SerializationException>()),
      );
    });

    test('decodeJson maps invalid body to SerializationException', () async {
      final response = await buildClient(
        httpClient: MockClient((request) async {
          return http.Response('not-json', 200);
        }),
      ).get('/raw');
      expect(response.decodeJson, throwsA(isA<SerializationException>()));
    });

    test(
      'authenticated request attaches Bearer from SessionCredentialProvider',
      () async {
        late http.Request captured;
        final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
        final sessions = FakeSessionService(
          clock: clock,
          session: fakeSession(
            accessToken: 'test-session-token',
            issuedAt: clock.now(),
          ),
        );
        final client = HttpApiClient(
          config: testConfig(),
          logger: logger,
          requestIdGenerator: requestIds,
          credentialProvider: sessions,
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response('{}', 200);
          }),
        );

        await client.get('/secure', authenticated: true);

        expect(captured.headers['authorization'], 'Bearer test-session-token');
        expect(logger.hasSensitiveLeak, isFalse);
      },
    );

    test('unauthenticated request does not attach Authorization', () async {
      late http.Request captured;
      final clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
      final sessions = FakeSessionService(
        clock: clock,
        session: fakeSession(issuedAt: clock.now()),
      );
      final client = HttpApiClient(
        config: testConfig(),
        logger: logger,
        requestIdGenerator: requestIds,
        credentialProvider: sessions,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await client.get('/public', authenticated: false);

      expect(captured.headers.containsKey('authorization'), isFalse);
    });

    test('UuidRequestIdGenerator produces unique ids', () {
      final generator = UuidRequestIdGenerator();
      final first = generator.next();
      final second = generator.next();
      expect(first, isNot(equals(second)));
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });
  });
}

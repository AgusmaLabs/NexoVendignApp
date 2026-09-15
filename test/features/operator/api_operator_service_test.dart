import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/operator/data/api_operator_service.dart';
import 'package:vendingapp/features/operator/domain/operator_exception.dart';

import '../../support/test_doubles.dart';

void main() {
  late RecordingAppLogger logger;
  late FakeClock clock;
  late FakeSessionService sessions;

  setUp(() {
    logger = RecordingAppLogger();
    clock = FakeClock(DateTime.utc(2026, 9, 15, 12));
    sessions = FakeSessionService(
      clock: clock,
      session: fakeSession(issuedAt: clock.now()),
    );
  });

  ApiOperatorService build(http.Client httpClient) {
    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-op'),
      credentialProvider: sessions,
      httpClient: httpClient,
    );
    return ApiOperatorService(apiClient: apiClient, logger: logger);
  }

  Map<String, Object?> operatorJson() => {
    'operator_id': 'op-1',
    'tenant_id': 'tenant-a',
    'role': 'replenisher',
    'status': 'active',
    'display_name': 'Ada Operator',
    'email': 'operator@example.com',
    'provider': 'google',
    'subject': 'google-sub-1',
  };

  test('GET /operators/me with Bearer maps OperatorOut', () async {
    late http.Request captured;
    final service = build(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(operatorJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final operator = await service.getCurrentOperator();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/operators/me');
    expect(captured.headers['authorization'], 'Bearer test-session-token');
    expect(captured.body.contains('fake-google-id-token'), isFalse);
    expect(operator.operatorId, 'op-1');
    expect(operator.displayName, 'Ada Operator');
    expect(operator.role, 'replenisher');
    expect(logger.hasSensitiveLeak, isFalse);
  });

  test('invalid JSON body maps to OperatorInvalidResponse', () async {
    final service = build(
      MockClient((request) async => http.Response('not-json', 200)),
    );

    expect(
      () => service.getCurrentOperator(),
      throwsA(isA<OperatorInvalidResponse>()),
    );
  });

  test('401 maps to OperatorSessionExpired', () async {
    final service = build(
      MockClient((request) async => http.Response('{"detail":"no"}', 401)),
    );

    expect(
      () => service.getCurrentOperator(),
      throwsA(isA<OperatorSessionExpired>()),
    );
  });

  test('403 OPERATOR_NOT_FOUND maps to OperatorNotConfigured', () async {
    final service = build(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'code': 'OPERATOR_NOT_FOUND', 'message': 'missing'}),
          403,
        ),
      ),
    );

    expect(
      () => service.getCurrentOperator(),
      throwsA(isA<OperatorNotConfigured>()),
    );
  });

  test('403 without code maps to OperatorAccessDenied', () async {
    final service = build(
      MockClient((request) async => http.Response('{"detail":"no"}', 403)),
    );

    expect(
      () => service.getCurrentOperator(),
      throwsA(isA<OperatorAccessDenied>()),
    );
  });

  test('404 maps to OperatorNotConfigured', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 404)),
    );

    expect(
      () => service.getCurrentOperator(),
      throwsA(isA<OperatorNotConfigured>()),
    );
  });

  test('500 maps to OperatorUnknownError', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 500)),
    );

    expect(
      () => service.getCurrentOperator(),
      throwsA(isA<OperatorUnknownError>()),
    );
  });

  test('timeout maps to OperatorNetworkFailure', () async {
    final apiClient = HttpApiClient(
      config: testConfig(
        apiBaseUrl: 'http://vending.test',
        httpTimeout: const Duration(milliseconds: 10),
      ),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-op'),
      credentialProvider: sessions,
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      }),
    );
    final timed = ApiOperatorService(apiClient: apiClient, logger: logger);

    expect(
      () => timed.getCurrentOperator(),
      throwsA(isA<OperatorNetworkFailure>()),
    );
  });

  test('network failure maps to OperatorNetworkFailure', () async {
    final service = build(
      MockClient((request) async {
        throw http.ClientException('offline');
      }),
    );

    expect(
      () => service.getCurrentOperator(),
      throwsA(isA<OperatorNetworkFailure>()),
    );
  });
}

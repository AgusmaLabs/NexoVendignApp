import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/products/data/api_product_lookup_service.dart';
import 'package:vendingapp/features/products/domain/product_exception.dart';

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

  ApiProductLookupService build(http.Client httpClient) {
    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-p'),
      credentialProvider: sessions,
      httpClient: httpClient,
    );
    return ApiProductLookupService(apiClient: apiClient, logger: logger);
  }

  Map<String, Object?> productJson() => {
    'product_id': 'prod-1',
    'barcode': '7801234567890',
    'name': 'Coca Cola 350 ml',
    'status': 'ACTIVE',
    'unit': 'CAN',
  };

  test('GET /products/barcode/{code} with Bearer and request id', () async {
    late http.Request captured;
    final service = build(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(productJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final product = await service.lookupByBarcode('7801234567890');

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/products/barcode/7801234567890');
    expect(captured.headers['authorization'], 'Bearer test-session-token');
    expect(captured.headers['x-request-id'], 'req-p');
    expect(captured.body.contains('fake-google-id-token'), isFalse);
    expect(product.name, 'Coca Cola 350 ml');
    expect(logger.hasSensitiveLeak, isFalse);
  });

  test('invalid barcode rejects without HTTP', () async {
    var calls = 0;
    final service = build(
      MockClient((request) async {
        calls += 1;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => service.lookupByBarcode('  '),
      throwsA(isA<ProductBarcodeInvalid>()),
    );
    expect(calls, 0);
  });

  test('404 maps to ProductNotFound', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 404)),
    );
    expect(
      () => service.lookupByBarcode('7801234567890'),
      throwsA(isA<ProductNotFound>()),
    );
  });

  test('401 maps to ProductSessionExpired', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 401)),
    );
    expect(
      () => service.lookupByBarcode('7801234567890'),
      throwsA(isA<ProductSessionExpired>()),
    );
  });

  test('403 maps to ProductAccessDenied', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 403)),
    );
    expect(
      () => service.lookupByBarcode('7801234567890'),
      throwsA(isA<ProductAccessDenied>()),
    );
  });

  test('422 maps to ProductBarcodeInvalid', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 422)),
    );
    expect(
      () => service.lookupByBarcode('7801234567890'),
      throwsA(isA<ProductBarcodeInvalid>()),
    );
  });

  test('429 maps to ProductRateLimited', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 429)),
    );
    expect(
      () => service.lookupByBarcode('7801234567890'),
      throwsA(isA<ProductRateLimited>()),
    );
  });

  test('5xx maps to ProductUnknownError', () async {
    final service = build(
      MockClient((request) async => http.Response('{}', 500)),
    );
    expect(
      () => service.lookupByBarcode('7801234567890'),
      throwsA(isA<ProductUnknownError>()),
    );
  });

  test('timeout maps to ProductNetworkFailure', () async {
    final service = build(
      MockClient((request) async {
        throw TimeoutException('slow');
      }),
    );
    expect(
      () => service.lookupByBarcode('7801234567890'),
      throwsA(isA<ProductNetworkFailure>()),
    );
  });

  test('lookup does not call inventory or replenishment line endpoints', () async {
    final paths = <String>[];
    final service = build(
      MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode(productJson()), 200);
      }),
    );

    await service.lookupByBarcode('7801234567890');

    expect(paths, ['/api/v1/products/barcode/7801234567890']);
    expect(paths.any((p) => p.contains('inventory')), isFalse);
    expect(paths.any((p) => p.contains('lines')), isFalse);
  });

  test('GET /products?q= returns Product list', () async {
    late http.Request captured;
    final service = build(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([productJson()]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final products = await service.searchByText('coca');

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/products');
    expect(captured.url.queryParameters['q'], 'coca');
    expect(captured.url.queryParameters['limit'], '20');
    expect(captured.url.queryParameters['offset'], '0');
    expect(captured.headers['authorization'], 'Bearer test-session-token');
    expect(products, hasLength(1));
    expect(products.single.name, 'Coca Cola 350 ml');
  });

  test('empty search list is success', () async {
    final service = build(
      MockClient(
        (_) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final products = await service.searchByText('zzzz');
    expect(products, isEmpty);
  });

  test('blank search query rejects without HTTP', () async {
    var calls = 0;
    final service = build(
      MockClient((_) async {
        calls += 1;
        return http.Response('[]', 200);
      }),
    );

    expect(
      () => service.searchByText('  '),
      throwsA(isA<ProductSearchQueryInvalid>()),
    );
    expect(calls, 0);
  });

  test('search 422 maps to ProductSearchQueryInvalid', () async {
    final service = build(
      MockClient((_) async => http.Response('bad', 422)),
    );

    expect(
      () => service.searchByText('ok'),
      throwsA(isA<ProductSearchQueryInvalid>()),
    );
  });
}

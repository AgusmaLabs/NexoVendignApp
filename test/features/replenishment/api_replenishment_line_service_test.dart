import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendingapp/core/networking/api_client.dart';
import 'package:vendingapp/core/time/clock.dart';
import 'package:vendingapp/features/replenishment/data/api_replenishment_line_service.dart';
import 'package:vendingapp/features/replenishment/domain/replenishment_exception.dart';

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

  ApiReplenishmentLineService build(http.Client httpClient) {
    final apiClient = HttpApiClient(
      config: testConfig(apiBaseUrl: 'http://vending.test'),
      logger: logger,
      requestIdGenerator: FixedRequestIdGenerator('req-line'),
      credentialProvider: sessions,
      httpClient: httpClient,
    );
    return ApiReplenishmentLineService(apiClient: apiClient, logger: logger);
  }

  Map<String, Object?> replenishmentJson({
    String id = 'rep-1',
    List<Map<String, Object?>> lines = const <Map<String, Object?>>[],
  }) => {
    'id': id,
    'machine_id': '11111111-1111-1111-1111-111111111111',
    'operator_id': 'op-1',
    'status': 'IN_PROGRESS',
    'machine_type': 'SNACK',
    'started_at': '2026-09-15T12:00:00+00:00',
    'completed_at': null,
    'location': {
      'latitude': -35.4264,
      'longitude': -71.6554,
      'accuracy': 12.4,
    },
    'idempotency_key': 'idem-abc',
    'version': 2,
    'lines': lines,
  };

  Map<String, Object?> lineJson() => {
    'id': 'line-1',
    'slot_id': 'slot-A01',
    'product_id': 'prod-1',
    'quantity': 12,
    'unit_price': '1500.00',
    'occurred_at': '2026-09-15T12:05:00+00:00',
    'product_description_snapshot': 'Coca Cola 350 ml',
    'resolution_status': 'RESOLVED',
  };

  test('POST lines with Bearer, product_id, quantity, slot_id, Idempotency-Key',
      () async {
    late http.Request captured;
    final service = build(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(
            replenishmentJson(lines: [lineJson()]),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final replenishment = await service.addLine(
      replenishmentId: 'rep-1',
      productId: 'prod-1',
      quantity: 12,
      slotId: 'slot-A01',
      idempotencyKey: 'idem-line-1',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/replenishments/rep-1/lines');
    expect(captured.headers['authorization'], 'Bearer test-session-token');
    expect(captured.headers['idempotency-key'], 'idem-line-1');
    expect(captured.headers['x-request-id'], 'req-line');
    expect(captured.body.contains('fake-google-id-token'), isFalse);
    expect(captured.body.contains('tenant_id'), isFalse);
    expect(captured.body.contains('operator_id'), isFalse);

    final body = jsonDecode(captured.body) as Map<String, Object?>;
    expect(body['product_id'], 'prod-1');
    expect(body['quantity'], 12);
    expect(body['slot_id'], 'slot-A01');

    expect(replenishment.lines, hasLength(1));
    expect(replenishment.lines.single.quantity, 12);
    expect(logger.hasSensitiveLeak, isFalse);
  });

  test('empty slot rejects without HTTP', () async {
    var calls = 0;
    final service = build(
      MockClient((request) async {
        calls += 1;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 1,
        slotId: '  ',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentSlotRequired>()),
    );
    expect(calls, 0);
  });

  test('quantity <= 0 rejects without HTTP', () async {
    var calls = 0;
    final service = build(
      MockClient((request) async {
        calls += 1;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 0,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentQuantityInvalid>()),
    );
    expect(calls, 0);
  });

  test('401 maps to session expired', () async {
    final service = build(
      MockClient((_) async => http.Response('unauthorized', 401)),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 1,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentSessionExpired>()),
    );
  });

  test('403 maps to access denied', () async {
    final service = build(
      MockClient((_) async => http.Response('forbidden', 403)),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 1,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentAccessDenied>()),
    );
  });

  test('404 maps to resource not found', () async {
    final service = build(
      MockClient((_) async => http.Response('missing', 404)),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 1,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentResourceNotFound>()),
    );
  });

  test('409 maps to conflict', () async {
    final service = build(
      MockClient((_) async => http.Response('conflict', 409)),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 1,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentConflict>()),
    );
  });

  test('422 maps to validation failed', () async {
    final service = build(
      MockClient((_) async => http.Response('invalid', 422)),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 1,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentValidationFailed>()),
    );
  });

  test('429 maps to rate limited', () async {
    final service = build(
      MockClient((_) async => http.Response('slow down', 429)),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 1,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentRateLimited>()),
    );
  });

  test('timeout maps to network failure', () async {
    final service = build(
      MockClient((_) async {
        throw TimeoutException('slow');
      }),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        productId: 'prod-1',
        quantity: 1,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentNetworkFailure>()),
    );
  });

  test('PENDING line posts product_id null with manual_description', () async {
    late http.Request captured;
    final service = build(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(
            replenishmentJson(
              lines: [
                {
                  'id': 'line-pending',
                  'slot_id': 'slot-A01',
                  'product_id': null,
                  'quantity': 5,
                  'unit_price': '0.00',
                  'occurred_at': '2026-09-15T12:05:00+00:00',
                  'product_description_snapshot': 'Bebida energética X',
                  'resolution_status': 'pending_product_resolution',
                  'barcode_scanned': '123456789',
                  'manual_description': 'Bebida energética X',
                },
              ],
            ),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final replenishment = await service.addLine(
      replenishmentId: 'rep-1',
      quantity: 5,
      slotId: 'slot-A01',
      idempotencyKey: 'idem-pending',
      barcode: '123456789',
      manualDescription: 'Bebida energética X',
    );

    final body = jsonDecode(captured.body) as Map<String, Object?>;
    expect(body.containsKey('product_id'), isTrue);
    expect(body['product_id'], isNull);
    expect(body['manual_description'], 'Bebida energética X');
    expect(body['barcode'], '123456789');
    expect(body.containsKey('replacement_reason'), isFalse);
    expect(replenishment.lines.single.productId, isNull);
    expect(
      replenishment.lines.single.resolutionStatus,
      'pending_product_resolution',
    );
  });

  test('PENDING without manual_description rejects without HTTP', () async {
    var calls = 0;
    final service = build(
      MockClient((request) async {
        calls += 1;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => service.addLine(
        replenishmentId: 'rep-1',
        quantity: 1,
        slotId: 'slot-A01',
        idempotencyKey: 'k',
      ),
      throwsA(isA<ReplenishmentValidationFailed>()),
    );
    expect(calls, 0);
  });
}

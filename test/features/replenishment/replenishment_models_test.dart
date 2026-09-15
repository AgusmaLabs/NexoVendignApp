import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/features/replenishment/domain/replenishment.dart';
import 'package:vendingapp/features/replenishment/domain/replenishment_line.dart';

void main() {
  test('fromJson maps ReplenishmentOut fields including lines', () {
    final replenishment = Replenishment.fromJson({
      'id': 'rep-1',
      'machine_id': 'm-1',
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
      'idempotency_key': 'idem-1',
      'version': 2,
      'lines': [
        {
          'id': 'line-1',
          'slot_id': 'slot-A01',
          'product_id': 'prod-1',
          'quantity': 12,
          'unit_price': '1500.00',
          'occurred_at': '2026-09-15T12:05:00+00:00',
          'product_description_snapshot': 'Coca Cola 350 ml',
          'resolution_status': 'RESOLVED',
        },
      ],
    });

    expect(replenishment.id, 'rep-1');
    expect(replenishment.status, 'IN_PROGRESS');
    expect(replenishment.lines, hasLength(1));
    expect(replenishment.lines.single.slotId, 'slot-A01');
    expect(replenishment.lines.single.quantity, 12);
    expect(replenishment.toJson().containsKey('access_token'), isFalse);
  });

  test('ReplenishmentLine.fromJson maps ReplenishmentLineOut', () {
    final line = ReplenishmentLine.fromJson({
      'id': 'line-1',
      'slot_id': 'slot-A01',
      'product_id': 'prod-1',
      'quantity': 8,
      'unit_price': '0.00',
      'occurred_at': '2026-09-15T12:05:00+00:00',
      'product_description_snapshot': 'Papas',
      'resolution_status': 'RESOLVED',
    });

    expect(line.id, 'line-1');
    expect(line.productId, 'prod-1');
    expect(line.quantity, 8);
  });

  test('rejects missing required replenishment fields', () {
    expect(
      () => Replenishment.fromJson({'id': 'x'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects zero quantity on line construction', () {
    expect(
      () => ReplenishmentLine(
        id: 'line-1',
        slotId: 'slot-1',
        quantity: 0,
        unitPrice: '0',
        occurredAt: '2026-09-15T12:00:00+00:00',
        productDescriptionSnapshot: 'x',
        resolutionStatus: 'RESOLVED',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

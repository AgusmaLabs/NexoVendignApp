import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/features/replenishment/domain/replenishment.dart';

void main() {
  test('fromJson maps ReplenishmentOut fields', () {
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
      'version': 1,
      'lines': <Object>[],
    });

    expect(replenishment.id, 'rep-1');
    expect(replenishment.status, 'IN_PROGRESS');
    expect(replenishment.lines, isEmpty);
    expect(replenishment.toJson().containsKey('access_token'), isFalse);
  });

  test('rejects missing required fields', () {
    expect(
      () => Replenishment.fromJson({'id': 'x'}),
      throwsA(isA<FormatException>()),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/features/operator/domain/operator.dart';

void main() {
  test('fromJson maps OperatorOut contract fields', () {
    final operator = Operator.fromJson({
      'operator_id': 'op-9',
      'tenant_id': 'tenant-b',
      'role': 'admin',
      'status': 'active',
      'display_name': 'Boss',
      'email': 'boss@example.com',
      'provider': 'google',
      'subject': 'sub-9',
    });

    expect(operator.operatorId, 'op-9');
    expect(operator.tenantId, 'tenant-b');
    expect(operator.welcomeName, 'Boss');
  });

  test('toJson does not include tokens', () {
    final json = fakeJson();
    expect(json.containsKey('access_token'), isFalse);
    expect(json.containsKey('id_token'), isFalse);
  });

  test('rejects missing required fields', () {
    expect(
      () => Operator.fromJson({'operator_id': 'x'}),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, Object?> fakeJson() {
  return Operator(
    operatorId: 'op-1',
    tenantId: 'tenant-a',
    role: 'replenisher',
    status: 'active',
    provider: 'google',
    subject: 'sub',
  ).toJson();
}

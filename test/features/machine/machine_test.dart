import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/features/machine/domain/machine.dart';

void main() {
  test('fromJson maps MachineOut fields', () {
    final machine = Machine.fromJson({
      'machine_id': 'm-1',
      'identifier': 'MIX-001',
      'machine_type': 'SNACK',
      'name': 'Lobby',
      'status': 'ACTIVE',
    });

    expect(machine.machineId, 'm-1');
    expect(machine.identifier, 'MIX-001');
    expect(machine.toJson().containsKey('access_token'), isFalse);
  });

  test('rejects missing required fields', () {
    expect(
      () => Machine.fromJson({'machine_id': 'x'}),
      throwsA(isA<FormatException>()),
    );
  });
}

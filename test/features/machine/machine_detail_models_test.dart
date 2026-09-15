import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/features/machine/domain/machine_detail.dart';
import 'package:vendingapp/features/machine/domain/machine_slot.dart';

void main() {
  group('MachineDetail', () {
    test('fromJson maps MachineOut fields', () {
      final detail = MachineDetail.fromJson({
        'machine_id': 'm-1',
        'identifier': 'MIX-001',
        'machine_type': 'SNACK',
        'name': 'Lobby',
        'status': 'ACTIVE',
      });

      expect(detail.machineId, 'm-1');
      expect(detail.identifier, 'MIX-001');
      expect(detail.toJson().containsKey('access_token'), isFalse);
    });

    test('rejects missing required fields', () {
      expect(
        () => MachineDetail.fromJson({'machine_id': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('MachineSlot', () {
    test('fromJson maps MachineSlotOut and preserves optionals', () {
      final slot = MachineSlot.fromJson({
        'slot_id': 's-1',
        'slot_number': 3,
        'capacity': 12,
        'status': 'ACTIVE',
        'preferred_product_id': 'prod-9',
        'selling_price': '1500',
        'current_quantity': 4,
      });

      expect(slot.slotId, 's-1');
      expect(slot.slotNumber, 3);
      expect(slot.identifier, 'S3');
      expect(slot.preferredProductId, 'prod-9');
      expect(slot.sellingPrice, '1500');
      expect(slot.currentQuantity, 4);
    });

    test('allows null preferred product and price', () {
      final slot = MachineSlot.fromJson({
        'slot_id': 's-2',
        'slot_number': 1,
        'capacity': 5,
        'status': 'ACTIVE',
        'preferred_product_id': null,
        'selling_price': null,
        'current_quantity': null,
      });

      expect(slot.preferredProductId, isNull);
      expect(slot.sellingPrice, isNull);
      expect(slot.currentQuantity, isNull);
    });

    test('rejects missing required fields', () {
      expect(
        () => MachineSlot.fromJson({'slot_id': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

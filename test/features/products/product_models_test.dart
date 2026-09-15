import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/features/products/domain/barcode_input.dart';
import 'package:vendingapp/features/products/domain/product.dart';

void main() {
  group('BarcodeInput', () {
    test('normalizes whitespace', () {
      expect(BarcodeInput.normalize('  7801234  '), '7801234');
    });

    test('accepts valid barcodes', () {
      expect(BarcodeInput.isValidFormat('7801234567890'), isTrue);
      expect(BarcodeInput.isValidFormat('ABC-12'), isTrue);
    });

    test('rejects empty, short, long, and illegal chars', () {
      expect(BarcodeInput.isValidFormat(''), isFalse);
      expect(BarcodeInput.isValidFormat('12'), isFalse);
      expect(BarcodeInput.isValidFormat('x' * 65), isFalse);
      expect(BarcodeInput.isValidFormat('780 123'), isFalse);
      expect(BarcodeInput.isValidFormat('780@123'), isFalse);
    });
  });

  group('Product', () {
    test('fromJson maps ProductOut', () {
      final product = Product.fromJson({
        'product_id': 'p-1',
        'barcode': '7801234567890',
        'name': 'Coca Cola 350 ml',
        'status': 'ACTIVE',
        'unit': 'CAN',
      });

      expect(product.productId, 'p-1');
      expect(product.description, 'Coca Cola 350 ml');
      expect(product.toJson().containsKey('access_token'), isFalse);
    });

    test('equality is by productId', () {
      final a = fakeLike(id: 'p-1', barcode: '1');
      final b = fakeLike(id: 'p-1', barcode: '2');
      final c = fakeLike(id: 'p-2', barcode: '1');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('rejects missing fields', () {
      expect(
        () => Product.fromJson({'product_id': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Product fakeLike({required String id, required String barcode}) {
  return Product(
    productId: id,
    barcode: barcode,
    name: 'Name',
    status: 'ACTIVE',
    unit: 'CAN',
  );
}

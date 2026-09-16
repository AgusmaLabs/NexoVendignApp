import 'package:flutter_test/flutter_test.dart';
import 'package:vendingapp/features/products/domain/unresolved_product.dart';

void main() {
  test('trims and accepts manual description', () {
    final unresolved = UnresolvedProduct(
      manualDescription: '  Bebida X  ',
      barcode: ' 123 ',
    );
    expect(unresolved.manualDescription, 'Bebida X');
    expect(unresolved.barcode, '123');
  });

  test('rejects empty manual description', () {
    expect(
      () => UnresolvedProduct(manualDescription: '   '),
      throwsArgumentError,
    );
  });

  test('rejects empty barcode when provided', () {
    expect(
      () => UnresolvedProduct(manualDescription: 'X', barcode: '  '),
      throwsArgumentError,
    );
  });

  test('validationMessage covers blank and max length', () {
    expect(ManualDescription.validationMessage(''), isNotNull);
    expect(ManualDescription.validationMessage('ok'), isNull);
    expect(
      ManualDescription.validationMessage('x' * (ManualDescription.maxLength + 1)),
      isNotNull,
    );
  });
}

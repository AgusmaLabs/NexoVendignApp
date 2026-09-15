/// Catalog product from NexoVending `ProductOut`.
final class Product {
  Product({
    required this.productId,
    required this.barcode,
    required this.name,
    required this.status,
    required this.unit,
  }) {
    if (productId.trim().isEmpty) {
      throw ArgumentError.value(productId, 'productId', 'must not be empty');
    }
    if (barcode.trim().isEmpty) {
      throw ArgumentError.value(barcode, 'barcode', 'must not be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (status.trim().isEmpty) {
      throw ArgumentError.value(status, 'status', 'must not be empty');
    }
    if (unit.trim().isEmpty) {
      throw ArgumentError.value(unit, 'unit', 'must not be empty');
    }
  }

  final String productId;
  final String barcode;
  final String name;
  final String status;
  final String unit;

  /// Display label used by UI (backend `name`).
  String get description => name;

  factory Product.fromJson(Map<String, Object?> json) {
    final productId = json['product_id'] as String?;
    final barcode = json['barcode'] as String?;
    final name = json['name'] as String?;
    final status = json['status'] as String?;
    final unit = json['unit'] as String?;

    if (productId == null ||
        barcode == null ||
        name == null ||
        status == null ||
        unit == null) {
      throw const FormatException('Product JSON missing required fields');
    }

    return Product(
      productId: productId,
      barcode: barcode,
      name: name,
      status: status,
      unit: unit,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'product_id': productId,
      'barcode': barcode,
      'name': name,
      'status': status,
      'unit': unit,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Product && other.productId == productId;
  }

  @override
  int get hashCode => productId.hashCode;

  @override
  String toString() {
    return 'Product(productId: $productId, barcode: $barcode, name: $name)';
  }
}

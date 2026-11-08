class StockItem {
  final String name;
  final String code;
  final String barcode;
  final String brand;
  final String category;
  final String unit;
  final double qty;
  final double reorder;
  final double rate;
  final double sellingPrice;

  StockItem({
    required this.name,
    this.code = '',
    this.barcode = '',
    required this.brand,
    required this.category,
    required this.unit,
    required this.qty,
    required this.reorder,
    required this.rate,
    this.sellingPrice = 0.0,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    return StockItem(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      barcode: json['barcode'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      unit: json['unit'] ?? '',
      qty: toDouble(json['qty']),
      reorder: toDouble(json['reorder']),
      rate: toDouble(json['rate']),
      sellingPrice: toDouble(json['selling_price']),
    );
  }

  double get value => qty * rate;
  bool get isOutOfStock => qty <= 0;
  bool get isLow => qty <= reorder;
  double get shortfall => isLow ? (reorder - qty) : 0;
  bool get isHealthy => qty > reorder && qty > 0;
  bool get isNeedReorder => isOutOfStock || (qty <= reorder && reorder > 0);

  String get stockStatus {
    if (isOutOfStock) return 'OUT_OF_STOCK';
    if (reorder <= 0) return 'NO_MIN';
    if (qty <= reorder) return 'REORDER';
    if (qty <= reorder * 1.25) return 'LOW_BUFFER';
    return 'HEALTHY';
  }
}

class CategoryStock {
  final String category;
  final double value;

  CategoryStock(this.category, this.value);
}

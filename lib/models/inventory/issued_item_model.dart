class IssuedItem {
  final int issueItemId;
  final int itemId;
  final String itemCode;
  final String itemName;
  final String brand;
  final String unit;
  final double qty;
  final double rate;
  final double tax;

  IssuedItem({
    required this.issueItemId,
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    this.brand = '',
    required this.unit,
    required this.qty,
    required this.rate,
    required this.tax,
  });

  double get amount => qty * rate;
  double get taxAmount => amount * tax / 100;
  double get totalAmount => amount + taxAmount;

  factory IssuedItem.fromJson(Map<String, dynamic> json) {
    return IssuedItem(
      issueItemId: json['id'],
      itemId: json['item_id'],
      itemCode: json['item_master']['item_code'],
      itemName: json['item_master']['item_name'],
      brand: (json['item_master']?['brand'] ?? '').toString(),
      unit: json['item_master']['unit'],
      qty: double.parse(json['qty'].toString()),
      rate: double.parse(json['rate'].toString()),
      tax: double.parse(json['tax'].toString()),
    );
  }
}

class ReturnItemPayload {
  final String item_code;
  final int issueItemId;
  final int itemId;
  final int qty;
  final double rate;

  ReturnItemPayload(
      {required this.issueItemId,
      required this.itemId,
      required this.qty,
      required this.rate,
      required this.item_code});

  Map<String, dynamic> toJson() {
    return {
      'item_code': item_code,
      'issue_item_id': issueItemId,
      'item_id': itemId,
      'qty': qty,
      'rate': rate,
    };
  }
}

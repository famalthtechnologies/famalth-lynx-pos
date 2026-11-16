class ReturnItem {
  final int issueItemId;
  final int itemId;
  int qty;
  double rate;
  double tax;

  ReturnItem({
    required this.issueItemId,
    required this.itemId,
    required this.qty,
    required this.rate,
    this.tax = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'issue_item_id': issueItemId,
      'item_id': itemId,
      'qty': qty,
      'rate': rate,
      'tax': tax,
    };
  }
}

class ReturnItemReport {
  final String itemName;
  final String brand;
  final double qty;
  final double rate;
  final double amount;
  final double tax;
  final double taxAmount;
  final double totalAmount;

  ReturnItemReport({
    required this.itemName,
    this.brand = '',
    required this.qty,
    required this.rate,
    required this.amount,
    this.tax = 0,
    double taxAmount = 0,
    double? totalAmount,
  })  : taxAmount = taxAmount,
        totalAmount = totalAmount ?? amount + taxAmount;

  factory ReturnItemReport.fromJson(Map<String, dynamic> json) {
    return ReturnItemReport(
      itemName: json['item_name'] ?? '',
      brand: (json['brand'] ?? '').toString(),
      qty: double.tryParse(json['qty'].toString()) ?? 0,
      rate: double.tryParse(json['rate'].toString()) ?? 0,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      tax: double.tryParse((json['tax'] ?? json['tax_percent'] ?? 0).toString()) ?? 0,
      taxAmount: double.tryParse((json['tax_amount'] ?? 0).toString()) ?? 0,
      totalAmount: double.tryParse((json['total_amount'] ?? json['total_after_tax'] ?? '').toString()),
    );
  }
}

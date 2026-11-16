class SupplierReturnSourceItem {
  final int receiptItemId;
  final int itemId;
  final String itemCode;
  final String itemName;
  final String brand;
  final String unit;
  final double qty;
  final double rate;
  final double tax;

  SupplierReturnSourceItem({
    required this.receiptItemId,
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    this.brand = '',
    required this.unit,
    required this.qty,
    required this.rate,
    this.tax = 0,
  });

  factory SupplierReturnSourceItem.fromJson(Map<String, dynamic> json) {
    return SupplierReturnSourceItem(
      receiptItemId: json['id'],
      itemId: json['item_id'] ?? 0,
      itemCode: (json['item_code'] ?? '').toString(),
      itemName: (json['item_name'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      qty: double.tryParse((json['qty'] ?? 0).toString()) ?? 0,
      rate: double.tryParse((json['rate'] ?? 0).toString()) ?? 0,
      tax: double.tryParse((json['tax'] ?? json['tax_percent'] ?? 0).toString()) ?? 0,
    );
  }

  double get amount => qty * rate;
  double get taxAmount => amount * tax / 100;
  double get totalAmount => amount + taxAmount;
}

class SupplierReturnEntryItem {
  final int receiptItemId;
  final int itemId;
  final String itemCode;
  final String itemName;
  final String brand;
  final String unit;
  double qty;
  double rate;
  double tax;

  SupplierReturnEntryItem({
    required this.receiptItemId,
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    this.brand = '',
    required this.unit,
    required this.qty,
    required this.rate,
    this.tax = 0,
  });

  double get amount => qty * rate;
  double get taxAmount => amount * tax / 100;
  double get totalAmount => amount + taxAmount;

  Map<String, dynamic> toJson() {
    return {
      'receipt_item_id': receiptItemId,
      'item_id': itemId,
      'item_code': itemCode,
      'qty': qty,
      'rate': rate,
      'tax': tax,
    };
  }
}

class SupplierReturnRecord {
  final int id;
  final String returnNo;
  final DateTime returnDate;
  final String supplierName;
  final String grnNo;
  final String billNo;
  final double totalAmount;
  final double refundedAmount;
  final String status;

  SupplierReturnRecord({
    required this.id,
    required this.returnNo,
    required this.returnDate,
    required this.supplierName,
    required this.grnNo,
    required this.billNo,
    required this.totalAmount,
    required this.refundedAmount,
    required this.status,
  });

  factory SupplierReturnRecord.fromJson(Map<String, dynamic> json) {
    return SupplierReturnRecord(
      id: json['id'],
      returnNo: (json['return_no'] ?? '').toString(),
      returnDate: DateTime.parse(json['return_date']),
      supplierName: json['supplier']?['supplier_name']?.toString() ?? '',
      grnNo: json['grn']?['grn_no']?.toString() ?? '',
      billNo: json['grn']?['supplier_bill_no']?.toString() ?? '',
      totalAmount: double.tryParse((json['total_amount'] ?? 0).toString()) ?? 0,
      refundedAmount:
          double.tryParse((json['refunded_amount'] ?? 0).toString()) ?? 0,
      status: (json['status'] ?? 'PENDING').toString(),
    );
  }

  double get pendingAmount => totalAmount - refundedAmount;
}

class SupplierReturnRefund {
  final int id;
  final DateTime refundDate;
  final double amount;
  final String paymentMode;
  final String referenceNo;
  final String notes;

  SupplierReturnRefund({
    required this.id,
    required this.refundDate,
    required this.amount,
    required this.paymentMode,
    required this.referenceNo,
    required this.notes,
  });

  factory SupplierReturnRefund.fromJson(Map<String, dynamic> json) {
    return SupplierReturnRefund(
      id: json['id'],
      refundDate: DateTime.parse(json['refund_date']),
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      paymentMode: (json['payment_mode'] ?? '').toString(),
      referenceNo: (json['reference_no'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

import 'purchase_item_model.dart';

class PurchaseOrder {
  final String poNo;
  final String manualNo;
  final int supplierId;
  final DateTime poDate;
  final DateTime? createdAt;
  final double roundOffAmount;
  final double totalAmount;
  final List<PurchaseItem> items;

  PurchaseOrder({
    required this.poNo,
    required this.manualNo,
    required this.supplierId,
    required this.poDate,
    this.createdAt,
    this.roundOffAmount = 0.0,
    this.totalAmount = 0.0,
    required this.items,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      poNo: json['po_no'] ?? '',
      manualNo: json['manual_no'] ?? '',
      supplierId: json['supplier_id'],
      poDate: DateTime.parse(json['po_date']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      roundOffAmount: double.tryParse((json['round_off_amount'] ?? 0).toString()) ?? 0,
      totalAmount: double.tryParse((json['total_amount'] ?? 0).toString()) ?? 0,
      items:
          (json['items'] as List).map((e) => PurchaseItem.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'po_no': poNo,
        'manual_no': manualNo,
        'supplier_id': supplierId,
        'po_date': poDate.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'round_off_amount': roundOffAmount,
        'total_amount': totalAmount,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

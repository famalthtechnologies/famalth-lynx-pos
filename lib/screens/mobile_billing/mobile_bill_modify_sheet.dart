import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/sale_order_model.dart';

class MobileBillModifySheet extends StatefulWidget {
  final SaleOrder initialOrder;
  final VoidCallback onModified;

  const MobileBillModifySheet({
    super.key,
    required this.initialOrder,
    required this.onModified,
  });

  @override
  State<MobileBillModifySheet> createState() => _MobileBillModifySheetState();
}

class _MobileBillModifySheetState extends State<MobileBillModifySheet> {
  final SalesController _salesCtrl = SalesController();
  bool _loading = true;
  bool _saving = false;

  late SaleOrder _order;
  int? _saleId;
  List<SaleItem> _items = [];
  late String _paymentMode;
  late TextEditingController _custNameCtrl;
  late TextEditingController _custPhoneCtrl;
  final TextEditingController _noteCtrl = TextEditingController(text: 'Customer requested payment mode change');

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _saleId = widget.initialOrder.orderId;
    _paymentMode = widget.initialOrder.paymentMode.toUpperCase();
    _custNameCtrl = TextEditingController(text: widget.initialOrder.customerName ?? '');
    _custPhoneCtrl = TextEditingController(text: widget.initialOrder.customerPhone ?? '');
    _fetchFullOrderDetails();
  }

  @override
  void dispose() {
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFullOrderDetails() async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.sales}/${_order.saleNo}');
      if (res['data'] != null) {
        final map = Map<String, dynamic>.from(res['data']);
        _saleId = int.tryParse(map['id']?.toString() ?? '') ?? _saleId;
        final full = SaleOrder.fromJson(map);
        if (mounted) {
          setState(() {
            _order = full;
            _items = List.from(full.items);
            _paymentMode = full.paymentMode.toUpperCase();
            _loading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _items = List.from(widget.initialOrder.items);
        _loading = false;
      });
    }
  }

  double get _computedSubtotal {
    return _items.fold(0.0, (sum, it) => sum + (it.rate * it.qty));
  }

  double get _computedTax {
    return _items.fold(0.0, (sum, it) => sum + ((it.rate * it.qty) * (it.taxPercent / 100.0)));
  }

  double get _computedNetTotal {
    return _computedSubtotal + _computedTax + _order.chargeTotal - _order.schemeDiscount - _order.manualDiscountAmount;
  }

  Future<void> _saveModifications() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a modification note')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final saleId = _saleId ?? _order.orderId;

      // Check if items changed
      final bool itemsChanged = _items.length != _order.items.length ||
          _items.any((curr) {
            final orig = _order.items.where((i) => i.itemId == curr.itemId).firstOrNull;
            return orig == null || orig.qty != curr.qty;
          });

      if (itemsChanged && saleId != null) {
        final updatedOrder = _order.copyWith(
          items: _items,
          customerName: _custNameCtrl.text.trim().isNotEmpty ? _custNameCtrl.text.trim() : null,
          customerPhone: _custPhoneCtrl.text.trim().isNotEmpty ? _custPhoneCtrl.text.trim() : null,
          paymentMode: _paymentMode,
          subTotal: _computedSubtotal,
          totalTax: _computedTax,
          netAmount: _computedNetTotal,
        );
        await _salesCtrl.modifySale(saleId, updatedOrder, modificationNote: note);
      } else if (saleId != null) {
        // Fast update: payment mode & customer details
        await _salesCtrl.updateSalePaymentMode(
          saleId: saleId,
          paymentMode: _paymentMode,
          customerName: _custNameCtrl.text.trim().isNotEmpty ? _custNameCtrl.text.trim() : null,
          customerPhone: _custPhoneCtrl.text.trim().isNotEmpty ? _custPhoneCtrl.text.trim() : null,
        );
      }

      HapticFeedback.heavyImpact();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill ${_order.saleNo} updated successfully!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        widget.onModified();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating bill: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _confirmCancelBill() {
    final reasonCtrl = TextEditingController(text: 'Cancelled by cashier');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Void / Cancel Bill?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel ${_order.saleNo}? Stock will be restored to inventory.',
                style: const TextStyle(fontSize: 13, color: textDark)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Cancellation Reason', isDense: true, border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Bill', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _saving = true);
              try {
                final saleId = _saleId ?? _order.orderId;
                if (saleId != null) {
                  await ApiClient.put('${ApiEndpoints.sales}/$saleId', {
                    'header': {
                      'status': 'CANCELLED',
                      'modification_note': reasonCtrl.text.trim(),
                    },
                    'items': [],
                  });
                }
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bill ${_order.saleNo} cancelled successfully'), backgroundColor: const Color(0xFFDC2626)),
                  );
                  widget.onModified();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error cancelling bill: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Yes, Void Bill'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(bottom: BorderSide(color: borderSubtle)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Modify: ${_order.saleNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(DateFormat('dd MMM yyyy, hh:mm a').format(_order.saleDate),
                                  style: const TextStyle(color: textMuted, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Payment Mode Switcher
                        const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: ['CASH', 'UPI', 'CARD', 'CREDIT', 'BANK'].map((mode) {
                            final isSel = _paymentMode == mode;
                            return ChoiceChip(
                              label: Text(mode, style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 11.5)),
                              selected: isSel,
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
                              onSelected: (val) {
                                if (val) setState(() => _paymentMode = mode);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Customer Fields
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _custNameCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'Customer Name',
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _custPhoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'Customer Phone',
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Line Items Stepper
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bill Line Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                            Text('${_items.length} items', style: const TextStyle(color: textMuted, fontSize: 11.5)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._items.map((it) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(it.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                      Text('₹${it.rate.toStringAsFixed(2)} × ${it.qty.toInt()} = ₹${(it.rate * it.qty).toStringAsFixed(2)}',
                                          style: const TextStyle(color: textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                // Quantity Stepper
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (it.qty > 1) {
                                            final idx = _items.indexOf(it);
                                            _items[idx] = it.copyWith(qty: it.qty - 1);
                                          } else {
                                            _items.remove(it);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.remove, size: 14, color: Color(0xFFDC2626)),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('${it.qty.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          final idx = _items.indexOf(it);
                                          _items[idx] = it.copyWith(qty: it.qty + 1);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),

                        // Totals Summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Modified Net Payable:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('₹${_computedNetTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Modification Note
                        TextField(
                          controller: _noteCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Modification Audit Note *',
                            hintText: 'e.g. Changed to UPI payment',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFFECACA)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('Void Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _confirmCancelBill,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: _saving
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _saving ? null : _saveModifications,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

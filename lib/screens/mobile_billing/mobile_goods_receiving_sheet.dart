import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/supplier_model.dart';

class MobileGoodsReceivingSheet extends StatefulWidget {
  final List<Item> catalogItems;
  final VoidCallback? onInventoryUpdated;

  const MobileGoodsReceivingSheet({
    super.key,
    required this.catalogItems,
    this.onInventoryUpdated,
  });

  @override
  State<MobileGoodsReceivingSheet> createState() => _MobileGoodsReceivingSheetState();
}

class _MobileGoodsReceivingSheetState extends State<MobileGoodsReceivingSheet> {
  int _activeTab = 0; // 0: New Inward (GRN), 1: Recent Inwards History

  // Header Details
  String _grnNo = 'GRN-...';
  final TextEditingController _manualNoCtrl = TextEditingController();
  final TextEditingController _supplierBillCtrl = TextEditingController();
  DateTime _receiptDate = DateTime.now();

  // Supplier
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  bool _loadingSuppliers = false;

  // Staged Inward Line Items
  final List<Map<String, dynamic>> _stagedItems = [];

  // Item Entry Form
  Item? _selectedItem;
  final TextEditingController _itemSearchCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _saleRateCtrl = TextEditingController();
  final TextEditingController _taxCtrl = TextEditingController(text: '0');
  final TextEditingController _remarksCtrl = TextEditingController();
  DateTime? _expiryDate;

  bool _isSaving = false;
  bool _loadingHistory = false;
  List<dynamic> _recentGrns = [];
  final TextEditingController _historySearchCtrl = TextEditingController();

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadNextGrnNo();
    _loadSuppliers();
    _loadRecentGrns();
  }

  @override
  void dispose() {
    _manualNoCtrl.dispose();
    _supplierBillCtrl.dispose();
    _itemSearchCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _saleRateCtrl.dispose();
    _taxCtrl.dispose();
    _remarksCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNextGrnNo() async {
    try {
      final res = await ApiClient.get(
        '/api/receiving/next-grn?date=${_receiptDate.toIso8601String()}',
        silent: true,
      );
      if (res != null && res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final no = (data['grn_no'] ?? data['next_no'] ?? '').toString();
        if (no.isNotEmpty && mounted) {
          setState(() => _grnNo = no);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loadingSuppliers = true);
    try {
      final res = await ApiClient.get('${ApiEndpoints.suppliers}?activeOnly=true', silent: true);
      if (res != null && res['data'] is List && mounted) {
        final list = (res['data'] as List).map((e) => Supplier.fromJson(e)).toList();
        setState(() {
          _suppliers = list;
          if (list.isNotEmpty && _selectedSupplier == null) {
            _selectedSupplier = list.first;
          }
          _loadingSuppliers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  Future<void> _loadRecentGrns() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await ApiClient.get('/api/receiving', silent: true);
      if (res != null && res['data'] is List && mounted) {
        setState(() {
          _recentGrns = res['data'] as List;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _onItemSelected(Item item) {
    setState(() {
      _selectedItem = item;
      _rateCtrl.text = item.rate > 0 ? item.rate.toStringAsFixed(2) : '';
      _saleRateCtrl.text = item.retailSalePrice > 0 ? item.retailSalePrice.toStringAsFixed(2) : (item.mrp > 0 ? item.mrp.toStringAsFixed(2) : '');
      _taxCtrl.text = item.taxPercent.toStringAsFixed(1);
    });
  }

  void _addItemToStaged() {
    if (_selectedItem == null) {
      _showToast('Please pick an item first', isError: true);
      return;
    }
    final double qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _showToast('Please enter a valid received quantity (> 0)', isError: true);
      return;
    }
    final double rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final double saleRate = double.tryParse(_saleRateCtrl.text.trim()) ?? 0;
    final double tax = double.tryParse(_taxCtrl.text.trim()) ?? 0;

    // Check if already in staged items
    final existingIdx = _stagedItems.indexWhere((e) => e['item_id'] == _selectedItem!.id);
    if (existingIdx >= 0) {
      _stagedItems[existingIdx]['qty'] += qty;
      _stagedItems[existingIdx]['rate'] = rate;
      _stagedItems[existingIdx]['tax'] = tax;
    } else {
      _stagedItems.add({
        'item_id': _selectedItem!.id,
        'code': _selectedItem!.itemCode,
        'name': _selectedItem!.itemName,
        'brand': _selectedItem!.brand,
        'unit': _selectedItem!.unit.isNotEmpty ? _selectedItem!.unit : 'PCS',
        'qty': qty,
        'rate': rate,
        'original_rate': rate,
        'is_tax_inclusive': false,
        'is_sale_tax_inclusive': false,
        'inclusive_scope': 'NONE',
        'sale_rate': saleRate,
        'tax': tax,
        'line_status': 'CLOSED',
        'department': '',
        'remarks': _remarksCtrl.text.trim(),
        'expiry_date': _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      });
    }

    setState(() {
      _selectedItem = null;
      _itemSearchCtrl.clear();
      _qtyCtrl.text = '1';
      _rateCtrl.clear();
      _saleRateCtrl.clear();
      _taxCtrl.text = '0';
      _remarksCtrl.clear();
      _expiryDate = null;
    });

    _showToast('Item added to inward bill');
  }

  double get _subtotal {
    double sum = 0.0;
    for (final it in _stagedItems) {
      final q = (it['qty'] as num?)?.toDouble() ?? 0.0;
      final r = (it['rate'] as num?)?.toDouble() ?? 0.0;
      sum += (q * r);
    }
    return sum;
  }

  double get _totalTax {
    double sum = 0.0;
    for (final it in _stagedItems) {
      final q = (it['qty'] as num?)?.toDouble() ?? 0.0;
      final r = (it['rate'] as num?)?.toDouble() ?? 0.0;
      final t = (it['tax'] as num?)?.toDouble() ?? 0.0;
      sum += (q * r * (t / 100));
    }
    return sum;
  }

  double get _netAmount => _subtotal + _totalTax;

  Future<void> _submitGoodsReceipt() async {
    if (_stagedItems.isEmpty) {
      _showToast('Please add at least one received item', isError: true);
      return;
    }
    if (_selectedSupplier == null) {
      _showToast('Please select a vendor / supplier', isError: true);
      return;
    }

    final double net = _netAmount;
    final double rounded = net.roundToDouble();
    final double roundOff = rounded - net;

    setState(() => _isSaving = true);
    try {
      final body = {
        'grn_no': _grnNo,
        'manual_no': _manualNoCtrl.text.trim(),
        'po_no': null,
        'supplier_id': _selectedSupplier!.id,
        'receipt_date': _receiptDate.toIso8601String(),
        'supplier_bill_no': _supplierBillCtrl.text.trim(),
        'status': 'CLOSED',
        'round_off_amount': roundOff,
        'net_amount': rounded,
        'items': _stagedItems,
      };

      final res = await ApiClient.post('/api/receiving', body);
      setState(() => _isSaving = false);

      if (res != null && (res['success'] == true || res['id'] != null || res['data'] != null)) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dlgCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
                  SizedBox(width: 10),
                  Text('Stock Inwarded!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GRN $_grnNo successfully saved and items updated in warehouse stock.', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        _summaryRow('Vendor:', _selectedSupplier!.supplierName),
                        _summaryRow('Items Inwarded:', '${_stagedItems.length} lines'),
                        _summaryRow('Total Cost:', CurrencyService.format(rounded)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dlgCtx);
                    setState(() {
                      _stagedItems.clear();
                      _supplierBillCtrl.clear();
                      _manualNoCtrl.clear();
                    });
                    _loadNextGrnNo();
                    _loadRecentGrns();
                    widget.onInventoryUpdated?.call();
                  },
                  child: const Text('Done & New Inward'),
                ),
              ],
            ),
          );
        }
      } else {
        final err = res?['message'] ?? res?['error'] ?? 'Failed to save inward receipt';
        _showToast(err.toString(), isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showToast('Error saving inward: $e', isError: true);
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openItemPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = widget.catalogItems.where((i) {
              if (filter.isEmpty) return true;
              final q = filter.toLowerCase();
              return i.itemName.toLowerCase().contains(q) ||
                  i.itemCode.toLowerCase().contains(q) ||
                  i.barcode.toLowerCase().contains(q) ||
                  i.brand.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, color: primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Select Inward Item',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by item name, code or barcode...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                      ),
                      onChanged: (val) => setModalState(() => filter = val.trim()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No matching items found', style: TextStyle(color: textMuted)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final it = filtered[idx];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                title: Text(
                                  it.itemName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                                ),
                                subtitle: Text(
                                  '${it.itemCode} • ${it.brand.isNotEmpty ? it.brand : it.itemGroup} • Tax: ${it.taxPercent}%',
                                  style: const TextStyle(fontSize: 11, color: textMuted),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Cost: ${CurrencyService.format(it.rate)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryBlue),
                                    ),
                                    Text(
                                      'MRP: ${CurrencyService.format(it.retailSalePrice > 0 ? it.retailSalePrice : it.mrp)}',
                                      style: const TextStyle(fontSize: 10, color: textMuted),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _onItemSelected(it);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openSupplierPickerModal(BuildContext context) {
    String filter = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final f = filter.trim().toLowerCase();
            final filtered = _suppliers.where((s) {
              if (f.isEmpty) return true;
              final name = s.supplierName.toLowerCase();
              final code = s.supplierCode.toLowerCase();
              final phone = s.phone.toLowerCase();
              final gstin = (s.gstin ?? '').toLowerCase();
              return name.contains(f) || code.contains(f) || phone.contains(f) || gstin.contains(f);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.business_rounded, color: primaryBlue, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Vendor / Supplier',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark),
                              ),
                              Text(
                                '${_suppliers.length} vendors available',
                                style: const TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF),
                            foregroundColor: primaryBlue,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showQuickAddVendorDialog();
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by vendor name, phone, GSTIN...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: textMuted),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
                      ),
                      onChanged: (val) => setModalState(() => filter = val),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 8),
                                Text(
                                  filter.isEmpty ? 'No vendors found' : 'No vendors matching "$filter"',
                                  style: const TextStyle(color: textMuted, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showQuickAddVendorDialog();
                                  },
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('+ Create New Vendor', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final s = filtered[idx];
                              final isSelected = _selectedSupplier?.id == s.id;
                              final initial = s.supplierName.isNotEmpty ? s.supplierName[0].toUpperCase() : 'V';

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      color: isSelected ? primaryBlue : const Color(0xFF475569),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  s.supplierName,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 13,
                                    color: isSelected ? primaryBlue : textDark,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (s.supplierCode.isNotEmpty) s.supplierCode,
                                    if (s.phone.isNotEmpty) s.phone,
                                    if (s.gstin != null && s.gstin!.isNotEmpty) 'GSTIN: ${s.gstin}',
                                  ].join(' • '),
                                  style: const TextStyle(fontSize: 11, color: textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                                    : const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 18),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() => _selectedSupplier = s);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQuickAddVendorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Vendor / Company Name *', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact Phone Number', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: gstinCtrl,
              decoration: const InputDecoration(labelText: 'GSTIN / Tax ID', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(dlgCtx);
              try {
                final payload = {
                  'supplier_name': n,
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim(),
                  'is_active': true,
                };
                await ApiClient.post(ApiEndpoints.suppliers, payload);
                await _loadSuppliers();
                final added = _suppliers.firstWhere((s) => s.supplierName.toLowerCase() == n.toLowerCase(), orElse: () => _suppliers.first);
                setState(() => _selectedSupplier = added);
                _showToast('Vendor added successfully');
              } catch (e) {
                _showToast('Failed to add vendor: $e', isError: true);
              }
            },
            child: const Text('Save Vendor'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),

          // Top Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: primaryBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receive From Vendor (GRN)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark),
                      ),
                      Text(
                        'Purchase Inward • $_grnNo',
                        style: const TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderSubtle),

          // Tabs: New Inward vs Recent GRNs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _activeTab == 0 ? primaryBlue : Colors.transparent, width: 2.5)),
                      ),
                      child: Text(
                        '+ New Inward Bill',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _activeTab == 0 ? primaryBlue : textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _activeTab = 1);
                      _loadRecentGrns();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _activeTab == 1 ? primaryBlue : Colors.transparent, width: 2.5)),
                      ),
                      child: Text(
                        '📋 Inward History (${_recentGrns.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _activeTab == 1 ? primaryBlue : textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderSubtle),

          // Main Tab Body
          Expanded(
            child: _activeTab == 0 ? _buildNewInwardView() : _buildHistoryView(),
          ),
        ],
      ),
    );
  }

  Widget _buildNewInwardView() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              // 1. Vendor & Inward Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Vendor & Bill Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('+ New Vendor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: _showQuickAddVendorDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Vendor Selector with Search
                    _loadingSuppliers
                        ? const LinearProgressIndicator()
                        : InkWell(
                            onTap: () => _openSupplierPickerModal(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.business_rounded,
                                    size: 18,
                                    color: _selectedSupplier != null ? primaryBlue : textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _selectedSupplier != null
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedSupplier!.supplierName,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: textDark,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (_selectedSupplier!.phone.isNotEmpty || (_selectedSupplier!.gstin ?? '').isNotEmpty)
                                                Text(
                                                  [_selectedSupplier!.phone, if ((_selectedSupplier!.gstin ?? '').isNotEmpty) 'GST: ${_selectedSupplier!.gstin}'].where((e) => e.isNotEmpty).join(' • '),
                                                  style: const TextStyle(fontSize: 10, color: textMuted),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          )
                                        : const Text(
                                            'Tap to Search & Select Vendor / Supplier *',
                                            style: TextStyle(fontSize: 13, color: textMuted),
                                          ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.search, color: textMuted, size: 16),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down_rounded, color: textMuted, size: 22),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _supplierBillCtrl,
                            decoration: InputDecoration(
                              labelText: 'Vendor Bill / Invoice #',
                              hintText: 'e.g. INV-904',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _receiptDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (d != null) {
                                setState(() => _receiptDate = d);
                                _loadNextGrnNo();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderSubtle),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Inward Date', style: TextStyle(fontSize: 9.5, color: textMuted)),
                                      Text(DateFormat('dd MMM yyyy').format(_receiptDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: primaryBlue),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Add Item to Inward Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Inward Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                    const SizedBox(height: 8),

                    // Tap to choose item from master
                    InkWell(
                      onTap: _openItemPickerModal,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 18, color: primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedItem != null ? '${_selectedItem!.itemName} (${_selectedItem!.itemCode})' : 'Tap to search & pick product...',
                                style: TextStyle(
                                  fontWeight: _selectedItem != null ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedItem != null ? textDark : textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Inputs: Qty, Buy Rate, Sale Rate, Tax
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Qty Received *',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Cost Rate (₹) *',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _taxCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Tax (%)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Expiry Date (Optional) & Add button
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 180)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (d != null) setState(() => _expiryDate = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderSubtle),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_outlined, size: 16, color: textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    _expiryDate != null ? 'Exp: ${DateFormat('dd-MMM-yyyy').format(_expiryDate!)}' : 'Expiry Date (Optional)',
                                    style: TextStyle(fontSize: 11, color: _expiryDate != null ? textDark : textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add to Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: _addItemToStaged,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Staged Items List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Inwarded Items (${_stagedItems.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
                  ),
                  if (_stagedItems.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _stagedItems.clear()),
                      child: const Text('Clear All', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              if (_stagedItems.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderSubtle),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_rounded, color: Color(0xFFCBD5E1), size: 36),
                        SizedBox(height: 6),
                        Text('No items added yet', style: TextStyle(color: textMuted, fontSize: 12)),
                        Text('Pick a product above to add to this inward batch', style: TextStyle(color: textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                )
              else
                ..._stagedItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final double q = (item['qty'] as num?)?.toDouble() ?? 0;
                  final double r = (item['rate'] as num?)?.toDouble() ?? 0;
                  final double t = (item['tax'] as num?)?.toDouble() ?? 0;
                  final double lineAmt = q * r;

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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.shopping_bag_outlined, color: primaryBlue, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${q.toStringAsFixed(1)} ${item['unit']} @ ${CurrencyService.format(r)} • Tax ${t.toStringAsFixed(0)}%${item['expiry_date'] != null ? ' • Exp: ${item['expiry_date']}' : ''}',
                                style: const TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyService.format(lineAmt),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => setState(() => _stagedItems.removeAt(idx)),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),

        // 4. Financial Summary & Inward Confirmation Footer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: borderSubtle)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal (${_stagedItems.length} items):', style: const TextStyle(color: textMuted, fontSize: 12)),
                  Text(CurrencyService.format(_subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total GST / Tax:', style: TextStyle(color: textMuted, fontSize: 12)),
                  Text(CurrencyService.format(_totalTax), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const Divider(height: 12, color: Color(0xFFF1F5F9)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Inward Amount:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                  Text(
                    CurrencyService.format(_netAmount),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryBlue),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Inwarding Stock...' : 'Confirm & Receive Stock Into Inventory',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _isSaving ? null : _submitGoodsReceipt,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    final q = _historySearchCtrl.text.trim().toLowerCase();
    final list = _recentGrns.where((g) {
      if (q.isEmpty) return true;
      final grnNo = (g['grn_no'] ?? '').toString().toLowerCase();
      final billNo = (g['supplier_bill_no'] ?? '').toString().toLowerCase();
      final sup = (g['supplier_name'] ?? g['supplier']?['supplier_name'] ?? '').toString().toLowerCase();
      return grnNo.contains(q) || billNo.contains(q) || sup.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _historySearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search GRN # or vendor bill...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const Center(child: Text('No inward records found', style: TextStyle(color: textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, idx) {
                        final grn = list[idx];
                        final grnNo = grn['grn_no'] ?? 'GRN-#${grn['id']}';
                        final dateStr = grn['receipt_date'] ?? grn['created_at'] ?? '';
                        String formattedDate = '';
                        if (dateStr.isNotEmpty) {
                          try {
                            formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr.toString()));
                          } catch (_) {
                            formattedDate = dateStr.toString();
                          }
                        }
                        final supName = (grn['supplier_name'] ?? grn['supplier']?['supplier_name'] ?? 'Vendor').toString();
                        final billNo = (grn['supplier_bill_no'] ?? '').toString();
                        final double netAmt = double.tryParse((grn['net_amount'] ?? 0).toString()) ?? 0.0;
                        final String status = (grn['status'] ?? 'CLOSED').toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    grnNo,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vendor: $supName${billNo.isNotEmpty ? ' • Bill: $billNo' : ''}',
                                style: const TextStyle(fontSize: 12, color: textMuted),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(formattedDate, style: const TextStyle(fontSize: 11, color: textMuted)),
                                  Text(
                                    CurrencyService.format(netAmt),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryBlue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

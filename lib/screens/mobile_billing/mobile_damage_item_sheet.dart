import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';
import '../../models/inventory/item_model.dart';

class MobileDamageItemSheet extends StatefulWidget {
  final List<Item> catalogItems;
  final VoidCallback? onInventoryUpdated;

  const MobileDamageItemSheet({
    super.key,
    required this.catalogItems,
    this.onInventoryUpdated,
  });

  @override
  State<MobileDamageItemSheet> createState() => _MobileDamageItemSheetState();
}

class _MobileDamageItemSheetState extends State<MobileDamageItemSheet> {
  int _activeTab = 0; // 0: Record Damage, 1: Damage Log

  String _damageNo = 'DMG-...';
  DateTime _damageDate = DateTime.now();
  final TextEditingController _overallRemarksCtrl = TextEditingController();

  final List<Map<String, dynamic>> _stagedItems = [];

  Item? _selectedItem;
  double _availableStock = 0.0;
  bool _loadingStock = false;
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _itemRemarksCtrl = TextEditingController();
  String _selectedReason = 'Broken / Cracked';

  final List<String> _commonReasons = [
    'Broken / Cracked',
    'Expired / Spoiled',
    'Leakage / Spillage',
    'Transit Damage',
    'Defective / Reject',
    'Handling Loss',
    'Other / Wastage',
  ];

  bool _isSaving = false;
  bool _loadingHistory = false;
  List<dynamic> _damageHistory = [];
  final TextEditingController _historySearchCtrl = TextEditingController();

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color alertRed = Color(0xFFDC2626);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadNextDamageNo();
    _loadDamageHistory();
  }

  @override
  void dispose() {
    _overallRemarksCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _itemRemarksCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNextDamageNo() async {
    try {
      final now = DateTime.now();
      final res = await ApiClient.get(
        '/api/inventory/damage/next-no?date=${now.toIso8601String()}',
        silent: true,
      );
      if (res != null && res['success'] == true && res['data'] != null) {
        final d = res['data'];
        final no = (d['damage_no'] ?? d['next_no'] ?? '').toString();
        if (no.isNotEmpty && mounted) {
          setState(() => _damageNo = no);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadAvailableStock(String itemCode) async {
    setState(() => _loadingStock = true);
    try {
      final res = await ApiClient.get('/api/inventory/issue/stock/$itemCode', silent: true);
      if (res != null && mounted) {
        final q = double.tryParse((res['qty'] ?? 0).toString()) ?? 0.0;
        setState(() {
          _availableStock = q;
          _loadingStock = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  Future<void> _loadDamageHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final now = DateTime.now();
      final from = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 90)));
      final to = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
      final res = await ApiClient.get('/api/reports/damage?from=$from&to=$to', silent: true);
      if (res != null && res['data'] is List && mounted) {
        setState(() {
          _damageHistory = res['data'] as List;
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
      _rateCtrl.text = item.rate > 0 ? item.rate.toStringAsFixed(2) : (item.retailSalePrice > 0 ? item.retailSalePrice.toStringAsFixed(2) : '0');
    });
    _loadAvailableStock(item.itemCode);
  }

  void _addItemToStaged() {
    if (_selectedItem == null) {
      _showToast('Please select a damaged item first', isError: true);
      return;
    }
    final double qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _showToast('Please enter a valid damaged quantity (> 0)', isError: true);
      return;
    }
    final double rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final double lineAmt = qty * rate;

    final reason = _itemRemarksCtrl.text.trim().isNotEmpty
        ? '$_selectedReason (${_itemRemarksCtrl.text.trim()})'
        : _selectedReason;

    setState(() {
      _stagedItems.add({
        'item_id': _selectedItem!.id,
        'item_code': _selectedItem!.itemCode,
        'item_name': _selectedItem!.itemName,
        'brand': _selectedItem!.brand,
        'unit': _selectedItem!.unit.isNotEmpty ? _selectedItem!.unit : 'PCS',
        'qty': qty,
        'rate': rate,
        'amount': lineAmt,
        'reason': reason,
      });

      _selectedItem = null;
      _availableStock = 0.0;
      _qtyCtrl.text = '1';
      _rateCtrl.clear();
      _itemRemarksCtrl.clear();
      _selectedReason = _commonReasons.first;
    });

    _showToast('Damaged item added to write-off batch');
  }

  double get _totalLossAmount {
    double sum = 0.0;
    for (final it in _stagedItems) {
      final double amt = (it['amount'] as num?)?.toDouble() ?? 0.0;
      sum += amt;
    }
    return sum;
  }

  Future<void> _submitDamageEntry() async {
    if (_stagedItems.isEmpty) {
      _showToast('Please add at least one damaged item', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final header = {
        'damage_no': _damageNo,
        'damage_date': _damageDate.toIso8601String(),
        'status': 'OPEN',
        'approval_status': 'PENDING',
        'description': _overallRemarksCtrl.text.trim(),
      };

      final itemsPayload = _stagedItems.map((e) => {
        'item_id': e['item_id'],
        'item_code': e['item_code'],
        'qty': e['qty'],
        'quantity': e['qty'],
        'rate': e['rate'],
        'amount': e['amount'],
        'remarks': e['reason'],
        'reason': e['reason'],
      }).toList();

      final res = await ApiClient.post(ApiEndpoints.damage, {
        'header': header,
        'items': itemsPayload,
      });

      setState(() => _isSaving = false);

      if (res != null && (res['success'] == true || res['data'] != null || res['id'] != null)) {
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
                  Text('Damage Recorded!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Damage entry $_damageNo submitted successfully.\n\nNote: Stock quantities will be deducted from inventory after approval in Approval Center.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        _summaryRow('Damage Voucher #:', _damageNo),
                        _summaryRow('Status:', 'Pending Approval'),
                        _summaryRow('Lines Written-off:', '${_stagedItems.length} items'),
                        _summaryRow('Total Loss Cost:', CurrencyService.format(_totalLossAmount)),
                        _summaryRow('Stock Deduction:', 'After Manager Approval'),
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
                      _overallRemarksCtrl.clear();
                    });
                    _loadNextDamageNo();
                    _loadDamageHistory();
                    widget.onInventoryUpdated?.call();
                  },
                  child: const Text('Done & Next Entry'),
                ),
              ],
            ),
          );
        }
      } else {
        final err = res?['message'] ?? res?['error'] ?? 'Failed to save damage entry';
        _showToast(err.toString(), isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showToast('Error recording damage: $e', isError: true);
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? alertRed : const Color(0xFF16A34A),
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
                        const Icon(Icons.report_problem_rounded, color: alertRed, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Select Damaged Product',
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
                        hintText: 'Search product by name, code or barcode...',
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
                                  '${it.itemCode} • ${it.brand.isNotEmpty ? it.brand : it.itemGroup}',
                                  style: const TextStyle(fontSize: 11, color: textMuted),
                                ),
                                trailing: Text(
                                  CurrencyService.format(it.rate > 0 ? it.rate : it.retailSalePrice),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: alertRed),
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

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_rounded, color: alertRed, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Damage & Spoilage Entry',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark),
                      ),
                      Text(
                        'Stock Write-Off • $_damageNo',
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

          // Tabs
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
                        border: Border(bottom: BorderSide(color: _activeTab == 0 ? alertRed : Colors.transparent, width: 2.5)),
                      ),
                      child: Text(
                        '+ Record Damage',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _activeTab == 0 ? alertRed : textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _activeTab = 1);
                      _loadDamageHistory();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _activeTab == 1 ? alertRed : Colors.transparent, width: 2.5)),
                      ),
                      child: Text(
                        '📋 Damage History (${_damageHistory.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _activeTab == 1 ? alertRed : textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderSubtle),

          // Body
          Expanded(
            child: _activeTab == 0 ? _buildRecordDamageView() : _buildDamageHistoryView(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordDamageView() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              // 1. Date & Header Description Card
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
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _damageDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                setState(() => _damageDate = d);
                                _loadNextDamageNo();
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
                                      const Text('Damage Date', style: TextStyle(fontSize: 9.5, color: textMuted)),
                                      Text(DateFormat('dd MMM yyyy').format(_damageDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: alertRed),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              border: Border.all(color: const Color(0xFFFECACA)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Voucher Sequence', style: TextStyle(fontSize: 9.5, color: alertRed)),
                                Text(_damageNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: alertRed)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _overallRemarksCtrl,
                      decoration: InputDecoration(
                        labelText: 'General Reason / Description',
                        hintText: 'e.g. Shelf audit, transit breakage, leakage...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Select Item & Damage Reason Card
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
                    const Text('Select Damaged Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                    const SizedBox(height: 8),

                    // Tap to choose item
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
                            const Icon(Icons.search_rounded, size: 18, color: alertRed),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedItem != null ? '${_selectedItem!.itemName} (${_selectedItem!.itemCode})' : 'Tap to search product from inventory...',
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
                    const SizedBox(height: 8),

                    // Available Stock Badge
                    if (_selectedItem != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _availableStock > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 14, color: _availableStock > 0 ? const Color(0xFF16A34A) : alertRed),
                            const SizedBox(width: 6),
                            Text(
                              _loadingStock ? 'Checking current stock...' : 'Current On-Hand Stock: ${_availableStock.toStringAsFixed(1)} ${_selectedItem!.unit}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _availableStock > 0 ? const Color(0xFF15803D) : alertRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Qty Damaged & Unit Cost Rate
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Damaged Qty *',
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
                              labelText: 'Loss Cost Rate (₹)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Reason Selector Chips
                    const Text('Primary Reason Code:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _commonReasons.map((r) {
                        final isSel = _selectedReason == r;
                        return ChoiceChip(
                          label: Text(r, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : textDark, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          selected: isSel,
                          selectedColor: alertRed,
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) setState(() => _selectedReason = r);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Item Remarks & Add button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _itemRemarksCtrl,
                            decoration: InputDecoration(
                              labelText: 'Specific Item Note (Optional)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: alertRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add to Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                    'Damaged Items to Write-off (${_stagedItems.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
                  ),
                  if (_stagedItems.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _stagedItems.clear()),
                      child: const Text('Clear All', style: TextStyle(color: alertRed, fontSize: 12)),
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
                        Icon(Icons.remove_shopping_cart_rounded, color: Color(0xFFCBD5E1), size: 36),
                        SizedBox(height: 6),
                        Text('No damaged items in current batch', style: TextStyle(color: textMuted, fontSize: 12)),
                        Text('Select product above to register write-off', style: TextStyle(color: textMuted, fontSize: 10)),
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
                  final double lineAmt = (item['amount'] as num?)?.toDouble() ?? 0;

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
                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.broken_image_rounded, color: alertRed, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['item_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${q.toStringAsFixed(1)} ${item['unit']} @ ${CurrencyService.format(r)} • Reason: ${item['reason']}',
                                style: const TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyService.format(lineAmt),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: alertRed),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: alertRed, size: 20),
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

        // 4. Total Loss & Submit Action Footer
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
                  const Text('Items Count:', style: TextStyle(color: textMuted, fontSize: 12)),
                  Text('${_stagedItems.length} lines', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Estimated Write-Off Loss:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
                  Text(
                    CurrencyService.format(_totalLossAmount),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: alertRed),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stock quantities will be deducted from inventory after approval in Approval Center.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: alertRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.assignment_turned_in_outlined, size: 20),
                  label: Text(
                    _isSaving ? 'Submitting Damage Entry...' : 'Submit Damage Entry for Approval',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _isSaving ? null : _submitDamageEntry,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDamageHistoryView() {
    final q = _historySearchCtrl.text.trim().toLowerCase();
    final list = _damageHistory.where((d) {
      if (q.isEmpty) return true;
      final item = (d['item'] ?? '').toString().toLowerCase();
      final reason = (d['reason'] ?? '').toString().toLowerCase();
      return item.contains(q) || reason.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _historySearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search damaged item or reason...',
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
                  ? const Center(child: Text('No damage records found', style: TextStyle(color: textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, idx) {
                        final rec = list[idx];
                        final itemName = (rec['item'] ?? 'Unknown Item').toString();
                        final dateStr = (rec['date'] ?? '').toString();
                        String formattedDate = '';
                        if (dateStr.isNotEmpty) {
                          try {
                            formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
                          } catch (_) {
                            formattedDate = dateStr;
                          }
                        }
                        final double rawQty = double.tryParse((rec['qty'] ?? 0).toString()) ?? 0;
                        final double r = double.tryParse((rec['rate'] ?? 0).toString()) ?? 0;
                        final double rawAmt = double.tryParse((rec['amount'] ?? 0).toString()) ?? 0;
                        // Graceful fallback for past entries if qty was saved as zero
                        final double q = rawQty > 0 ? rawQty : (rawAmt > 0 && r > 0 ? (rawAmt / r) : 1.0);
                        final double totalLoss = rawAmt > 0 ? rawAmt : (q * r);
                        final reason = (rec['reason'] ?? 'Damage').toString();
                        final user = (rec['user'] ?? '').toString();

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
                                  Expanded(
                                    child: Text(
                                      itemName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                                    ),
                                  ),
                                  Text(
                                    CurrencyService.format(totalLoss),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: alertRed),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${q.toStringAsFixed(1)} units @ ${CurrencyService.format(r)}',
                                    style: const TextStyle(fontSize: 11, color: textMuted),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                                    child: Text(reason, style: const TextStyle(fontSize: 10, color: alertRed, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$formattedDate${user.isNotEmpty ? ' • Logged by: $user' : ''}',
                                style: const TextStyle(fontSize: 10, color: textMuted),
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

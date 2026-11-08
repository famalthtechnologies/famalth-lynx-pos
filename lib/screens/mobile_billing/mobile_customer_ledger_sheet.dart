import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/reports/finance_models.dart';

class MobileCustomerLedgerSheet extends StatefulWidget {
  const MobileCustomerLedgerSheet({super.key});

  @override
  State<MobileCustomerLedgerSheet> createState() => _MobileCustomerLedgerSheetState();
}

class _MobileCustomerLedgerSheetState extends State<MobileCustomerLedgerSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  final TextEditingController _searchCtrl = TextEditingController();

  double _totalCreditOutstanding = 0.0;
  double _totalAdvancesHeld = 0.0;

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadCreditReport();
    _searchCtrl.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCreditReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.financeCreditReport);
      if (res['data'] is List) {
        final list = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        double creditSum = 0;
        double advanceSum = 0;

        if (res['summary'] is Map) {
          creditSum = double.tryParse((res['summary']['total_outstanding'] ?? 0).toString()) ?? 0.0;
          advanceSum = double.tryParse((res['summary']['total_advance'] ?? 0).toString()) ?? 0.0;
        }

        for (final c in list) {
          final credit = double.tryParse((c['total_outstanding'] ?? c['outstanding_balance'] ?? c['total_credit'] ?? 0).toString()) ?? 0;
          final advance = double.tryParse((c['total_advance'] ?? 0).toString()) ?? 0;
          if (res['summary'] == null) {
            creditSum += credit;
            advanceSum += advance;
          }
        }

        if (mounted) {
          setState(() {
            _customers = list;
            _totalCreditOutstanding = creditSum;
            _totalAdvancesHeld = advanceSum;
            _filterCustomers();
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _filterCustomers() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredCustomers = _customers.where((c) {
        if (q.isEmpty) return true;
        final name = (c['customer_name'] ?? '').toString().toLowerCase();
        final phone = (c['customer_phone'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    });
  }

  void _openRepaymentDialog(Map<String, dynamic> customer) {
    final custName = (customer['customer_name'] ?? '').toString();
    final custPhone = (customer['customer_phone'] ?? '').toString();
    final due = double.tryParse((customer['total_outstanding'] ?? customer['outstanding_balance'] ?? customer['total_credit'] ?? 0).toString()) ?? 0.0;
    final adv = double.tryParse((customer['total_advance'] ?? 0).toString()) ?? 0.0;

    final amountCtrl = TextEditingController(text: due > 0 ? due.toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController();
    String paymentMode = 'CASH';
    bool saving = false;
    final availableModes = adv > 0.009 ? ['CASH', 'UPI', 'CARD', 'BANK', 'ADVANCE'] : ['CASH', 'UPI', 'CARD', 'BANK'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.payments_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Collect Repayment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$custName ($custPhone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Current Due: ₹${due.toStringAsFixed(2)}',
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600)),
                            if (adv > 0)
                              Text('Advance: ₹${adv.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'Repayment Amount (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Payment Mode', style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: availableModes.map((mode) {
                      final isSel = paymentMode == mode;
                      final isAdvMode = mode == 'ADVANCE';
                      return ChoiceChip(
                        label: Text(mode, style: TextStyle(color: isSel ? Colors.white : (isAdvMode ? const Color(0xFF059669) : textDark), fontSize: 11, fontWeight: isAdvMode ? FontWeight.bold : FontWeight.normal)),
                        selected: isSel,
                        selectedColor: isAdvMode ? const Color(0xFF059669) : const Color(0xFF2563EB),
                        backgroundColor: isAdvMode ? const Color(0xFFECFDF5) : Colors.white,
                        side: BorderSide(color: isSel ? (isAdvMode ? const Color(0xFF059669) : const Color(0xFF2563EB)) : (isAdvMode ? const Color(0xFFA7F3D0) : borderSubtle)),
                        onSelected: (val) {
                          if (val) setDialogState(() => paymentMode = mode);
                        },
                      );
                    }).toList(),
                  ),
                  if (paymentMode == 'ADVANCE') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        'Will be adjusted from Customer Advance Held (Available: ₹${adv.toStringAsFixed(2)})',
                        style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Reference No / Notes (Optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount')),
                          );
                          return;
                        }
                        if (paymentMode == 'ADVANCE' && amt > adv + 0.009) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Amount cannot exceed available advance (₹${adv.toStringAsFixed(2)})')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          if (paymentMode == 'ADVANCE') {
                            await ApiClient.post(ApiEndpoints.financeAdjustBulkAdvance, {
                              'customer_name': custName,
                              'customer_phone': custPhone,
                              'amount': amt,
                              'payment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              'note': notesCtrl.text.trim(),
                            });
                          } else {
                            await ApiClient.post(ApiEndpoints.financeRepaymentsBulkAdjust, {
                              'customer_name': custName,
                              'customer_phone': custPhone,
                              'amount': amt,
                              'payment_mode': paymentMode,
                              'payment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              'note': notesCtrl.text.trim(),
                            });
                          }
                          HapticFeedback.heavyImpact();
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(paymentMode == 'ADVANCE'
                                  ? 'Advance of ₹${amt.toStringAsFixed(2)} adjusted against dues!'
                                  : 'Repayment of ₹${amt.toStringAsFixed(2)} recorded successfully!'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          _loadCreditReport();
                        } catch (e) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Repayment', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAdjustAdvanceDialog(Map<String, dynamic> customer, {double? specificDue, String? saleNo, int? saleId}) {
    final custName = (customer['customer_name'] ?? '').toString();
    final custPhone = (customer['customer_phone'] ?? '').toString();
    final due = specificDue ?? (double.tryParse((customer['total_outstanding'] ?? customer['outstanding_balance'] ?? customer['total_credit'] ?? 0).toString()) ?? 0.0);
    final adv = double.tryParse((customer['total_advance'] ?? 0).toString()) ?? 0.0;
    final maxAdjust = math.min(due, adv);

    final amountCtrl = TextEditingController(text: maxAdjust > 0 ? maxAdjust.toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController(text: saleNo != null ? 'Adjusted against bill $saleNo' : 'Adjusted from customer advance');
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF059669), size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Adjust from Advance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$custName ($custPhone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Credit Due: ₹${due.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.w600)),
                            Text('Advance: ₹${adv.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (saleNo != null) ...[
                          const SizedBox(height: 2),
                          Text('Target Bill: $saleNo', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Adjustment Amount (₹)',
                      helperText: 'Max available: ₹${maxAdjust.toStringAsFixed(2)}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amt <= 0 || amt > adv + 0.009) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(amt <= 0 ? 'Enter a valid amount' : 'Cannot exceed available advance (₹${adv.toStringAsFixed(2)})')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await ApiClient.post(ApiEndpoints.financeAdjustBulkAdvance, {
                            'customer_name': custName,
                            'customer_phone': custPhone,
                            'amount': amt,
                            'sale_id': saleId,
                            'payment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            'note': notesCtrl.text.trim(),
                          });
                          HapticFeedback.heavyImpact();
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Advance of ₹${amt.toStringAsFixed(2)} adjusted successfully!'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          _loadCreditReport();
                        } catch (e) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAdvanceDialog(Map<String, dynamic> customer) {
    final custName = (customer['customer_name'] ?? '').toString();
    final custPhone = (customer['customer_phone'] ?? '').toString();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMode = 'CASH';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF059669), size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Collect Advance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Text('$custName ($custPhone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'Advance Amount (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Payment Mode', style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['CASH', 'UPI', 'CARD', 'BANK'].map((mode) {
                      final isSel = paymentMode == mode;
                      return ChoiceChip(
                        label: Text(mode, style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 11)),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
                        onSelected: (val) {
                          if (val) setDialogState(() => paymentMode = mode);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Notes / Reason (Optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await ApiClient.post(ApiEndpoints.financeAdvances, {
                            'customer_name': custName,
                            'customer_phone': custPhone,
                            'amount': amt,
                            'payment_mode': paymentMode,
                            'advance_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            'notes': notesCtrl.text.trim(),
                          });
                          HapticFeedback.heavyImpact();
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Customer advance of ₹${amt.toStringAsFixed(2)} added successfully!'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          _loadCreditReport();
                        } catch (e) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Advance', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openStatementModal(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerStatementSheet(customer: customer),
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
      child: Column(
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
                const Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 24),
                    SizedBox(width: 10),
                    Text('Customer Credit & Ledger',
                        style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // KPI Strip: Total Credit Due vs Advances
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Credit Due', style: TextStyle(color: textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('₹${_totalCreditOutstanding.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(height: 36, width: 1, color: borderSubtle),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Advances Held', style: TextStyle(color: textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('₹${_totalAdvancesHeld.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFF059669), fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search customer by name or phone...',
                hintStyle: const TextStyle(color: textMuted, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _searchCtrl.clear())
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderSubtle)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderSubtle)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Customers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_outlined, size: 54, color: textMuted),
                            SizedBox(height: 10),
                            Text('No customer credit or advance records found', style: TextStyle(color: textMuted, fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCreditReport,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredCustomers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final c = _filteredCustomers[idx];
                            final custName = (c['customer_name'] ?? 'Customer').toString();
                            final custPhone = (c['customer_phone'] ?? '').toString();
                            final due = double.tryParse((c['total_outstanding'] ?? c['outstanding_balance'] ?? c['total_credit'] ?? 0).toString()) ?? 0.0;
                            final adv = double.tryParse((c['total_advance'] ?? 0).toString()) ?? 0.0;

                            return Container(
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
                                      Expanded(
                                        child: Text(custName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                                      ),
                                      if (due > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFFECACA)),
                                          ),
                                          child: Text('Due: ₹${due.toStringAsFixed(2)}',
                                              style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                    ],
                                  ),
                                  if (custPhone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(custPhone, style: const TextStyle(color: textMuted, fontSize: 12)),
                                  ],
                                  if (adv > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('Advance Available: ₹${adv.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w600)),
                                  ],
                                  const Divider(height: 16, color: borderSubtle),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF2563EB),
                                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.receipt_long, size: 14),
                                          label: const Text('Statement', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                          onPressed: () => _openStatementModal(c),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF059669),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.payments, size: 14),
                                          label: const Text('Repay', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                          onPressed: () => _openRepaymentDialog(c),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.add_card, color: Color(0xFF2563EB), size: 20),
                                        tooltip: 'Add Advance',
                                        onPressed: () => _openAdvanceDialog(c),
                                      ),
                                    ],
                                  ),
                                  if (due > 0 && adv > 0) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF059669),
                                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                                          backgroundColor: const Color(0xFFECFDF5),
                                          padding: const EdgeInsets.symmetric(vertical: 7),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                                        label: Text(
                                          'Adjust Advance (₹${math.min(due, adv).toStringAsFixed(2)})',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () => _openAdjustAdvanceDialog(c),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CustomerStatementSheet extends StatefulWidget {
  final Map<String, dynamic> customer;
  const _CustomerStatementSheet({required this.customer});

  @override
  State<_CustomerStatementSheet> createState() => _CustomerStatementSheetState();
}

class _CustomerStatementSheetState extends State<_CustomerStatementSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _txns = [];
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  double _closingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  String _formatTxDate(dynamic raw) {
    if (raw == null) return '';
    if (raw is DateTime) {
      return DateFormat('dd-MMM-yyyy').format(raw);
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return DateFormat('dd-MMM-yyyy').format(dt);
      }
    } catch (_) {}
    return s.split('T').first;
  }

  Future<void> _fetchLedger() async {
    final phone = (widget.customer['customer_phone'] ?? '').toString().trim();
    final name = (widget.customer['customer_name'] ?? '').toString().trim();

    try {
      dynamic res = await ApiClient.get(
        '${ApiEndpoints.financeCustomerLedger}?customer_phone=${Uri.encodeComponent(phone)}&customer_name=${Uri.encodeComponent(name)}',
      );

      Map<String, dynamic> d = (res is Map && res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'])
          : (res is Map ? Map<String, dynamic>.from(res) : {});
      List<Map<String, dynamic>> rawList =
          (d['transactions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

      if (rawList.isEmpty && phone.isNotEmpty) {
        // Try with only phone
        res = await ApiClient.get(
          '${ApiEndpoints.financeCustomerLedger}?customer_phone=${Uri.encodeComponent(phone)}',
        );
        d = (res is Map && res['data'] is Map)
            ? Map<String, dynamic>.from(res['data'])
            : (res is Map ? Map<String, dynamic>.from(res) : {});
        rawList = (d['transactions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (rawList.isEmpty && name.isNotEmpty) {
        // Try with only name
        res = await ApiClient.get(
          '${ApiEndpoints.financeCustomerLedger}?customer_name=${Uri.encodeComponent(name)}',
        );
        d = (res is Map && res['data'] is Map)
            ? Map<String, dynamic>.from(res['data'])
            : (res is Map ? Map<String, dynamic>.from(res) : {});
        rawList = (d['transactions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final summary = d['summary'] is Map ? d['summary'] : {};
      double totalDebit = double.tryParse((summary['total_debit'] ?? summary['total_invoiced'] ?? 0).toString()) ?? 0.0;
      double totalCredit = double.tryParse((summary['total_credit'] ?? summary['total_paid'] ?? 0).toString()) ?? 0.0;
      double closingBal = double.tryParse((summary['closing_balance'] ?? summary['balance'] ?? 0).toString()) ?? 0.0;

      // Fallback: If transactions still empty, fetch customer bills directly from sales
      if (rawList.isEmpty) {
        try {
          final queryParam = phone.isNotEmpty ? 'customer_phone=$phone' : 'customer_name=${Uri.encodeComponent(name)}';
          final salesRes = await ApiClient.get('${ApiEndpoints.sales}?$queryParam');
          final salesList = (salesRes['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
          if (salesList.isNotEmpty) {
            for (final s in salesList) {
              final netAmt = double.tryParse((s['net_amount'] ?? s['total_amount'] ?? 0).toString()) ?? 0.0;
              final paidAmt = double.tryParse((s['amount_paid'] ?? 0).toString()) ?? 0.0;
              totalDebit += netAmt;
              totalCredit += paidAmt;

              rawList.add({
                'date': s['sale_date'] ?? s['created_at'],
                'voucher_no': (s['sale_no'] ?? 'Invoice').toString(),
                'reference_no': (s['sale_no'] ?? 'Invoice').toString(),
                'debit': netAmt,
                'credit': paidAmt,
                'payment_mode': s['payment_mode'] ?? 'CASH',
                'description': 'POS Sale: ${s['customer_name'] ?? 'Walk-in'}',
              });
            }
          }
        } catch (_) {}
      }

      // Convert via CustomerLedgerReport logic or compute running balances
      // First sort chronologically (oldest first) to compute running balance
      rawList.sort((a, b) {
        final da = DateTime.tryParse((a['date'] ?? a['txn_date'] ?? '').toString()) ?? DateTime(2000);
        final db = DateTime.tryParse((b['date'] ?? b['txn_date'] ?? '').toString()) ?? DateTime(2000);
        return da.compareTo(db);
      });

      double runningBal = 0.0;
      double sumDr = 0.0;
      double sumCr = 0.0;
      final List<Map<String, dynamic>> computedList = [];

      for (final tx in rawList) {
        final dVal = double.tryParse((tx['debit'] ?? 0).toString()) ?? 0.0;
        final cVal = double.tryParse((tx['credit'] ?? 0).toString()) ?? 0.0;
        sumDr += dVal;
        sumCr += cVal;
        runningBal += (dVal - cVal);

        final m = Map<String, dynamic>.from(tx);
        m['balance'] = runningBal;
        m['debit'] = dVal;
        m['credit'] = cVal;
        m['formatted_date'] = _formatTxDate(tx['date'] ?? tx['txn_date']);
        m['payment_mode'] = (tx['payment_mode'] ?? tx['payment_method'] ?? tx['paymentMode'] ?? '').toString().toUpperCase();
        computedList.add(m);
      }

      if (totalDebit == 0 && sumDr > 0) totalDebit = sumDr;
      if (totalCredit == 0 && sumCr > 0) totalCredit = sumCr;
      if (closingBal == 0 && computedList.isNotEmpty) closingBal = runningBal;

      // Reverse so newest appears on top for biller convenience
      final displayList = computedList.reversed.toList();

      if (mounted) {
        setState(() {
          _txns = displayList;
          _totalDebit = totalDebit;
          _totalCredit = totalCredit;
          _closingBalance = closingBal;
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  void _shareStatementWhatsApp() async {
    final name = (widget.customer['customer_name'] ?? 'Customer').toString();
    final phone = (widget.customer['customer_phone'] ?? '').toString();

    final balStr = _closingBalance > 0.009
        ? '₹${_closingBalance.toStringAsFixed(2)} Dr (Outstanding Due)'
        : (_closingBalance < -0.009
            ? '₹${_closingBalance.abs().toStringAsFixed(2)} Cr (Advance Available)'
            : '₹0.00 (Settled)');

    final msg = 'Dear $name,\nHere is your account statement summary:\n'
        '• Total Invoiced: ₹${_totalDebit.toStringAsFixed(2)}\n'
        '• Total Paid: ₹${_totalCredit.toStringAsFixed(2)}\n'
        '• Net Balance: $balStr\n\n'
        'Thank you for your business!';

    final uri = Uri.parse('whatsapp://send?phone=$phone&text=${Uri.encodeComponent(msg)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  void _confirmAdjustAdvanceForBill({
    required String saleNo,
    dynamic saleId,
    required double billDue,
    required double availableAdv,
  }) {
    final double maxAlloc = math.min(billDue, availableAdv);
    final phone = (widget.customer['customer_phone'] ?? '').toString().trim();
    final name = (widget.customer['customer_name'] ?? '').toString().trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Adjust from Advance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adjust ₹${maxAlloc.toStringAsFixed(2)} against invoice $saleNo from customer advance?',
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice Due: ₹${billDue.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Advance Available: ₹${availableAdv.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                await ApiClient.post(ApiEndpoints.financeAdjustBulkAdvance, {
                  'customer_name': name,
                  'customer_phone': phone,
                  'amount': maxAlloc,
                  'sale_id': saleId,
                  'payment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'note': 'Advance adjusted against $saleNo',
                });
                HapticFeedback.heavyImpact();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('₹${maxAlloc.toStringAsFixed(2)} adjusted from advance against $saleNo!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                  _fetchLedger();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Confirm Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.customer['customer_name'] ?? 'Customer').toString();
    final phone = (widget.customer['customer_phone'] ?? '').toString();

    final isDr = _closingBalance > 0.009;
    final isCr = _closingBalance < -0.009;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ledger: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Summary Strip (Matching Windows Desktop Format)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Invoiced', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    Text('₹${_totalDebit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Paid', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    Text('₹${_totalCredit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF059669))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isDr ? 'Balance Due (Dr)' : (isCr ? 'Advance Held (Cr)' : 'Net Balance'),
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    Text(
                      isDr
                          ? '₹${_closingBalance.toStringAsFixed(2)} Dr'
                          : (isCr ? '₹${_closingBalance.abs().toStringAsFixed(2)} Cr' : '₹0.00 Settled'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDr ? const Color(0xFFDC2626) : (isCr ? const Color(0xFF059669) : const Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _txns.isEmpty
                    ? const Center(child: Text('No transaction history found', style: TextStyle(color: Color(0xFF64748B))))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _txns.length,
                        separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, idx) {
                          final t = _txns[idx];
                          final dateStr = (t['formatted_date'] ?? _formatTxDate(t['date'] ?? t['txn_date'])).toString();
                          final ref = (t['reference_no'] ?? t['voucher_no'] ?? 'Txn').toString();
                          final mode = (t['payment_mode'] ?? '').toString().toUpperCase();
                          final vType = (t['voucher_type'] ?? '').toString().toUpperCase();
                          final debit = double.tryParse((t['debit'] ?? 0).toString()) ?? 0.0;
                          final credit = double.tryParse((t['credit'] ?? 0).toString()) ?? 0.0;
                          final bal = double.tryParse((t['balance'] ?? 0).toString()) ?? 0.0;

                          // User rule:
                          // 1) Subscription adjusted -> GREEN (not due, paid via subscription)
                          // 2) Pending payment (not paid) -> RED (DUE)
                          // 3) Paid purchases -> GREEN (PAID)
                          // 4) Customer advance / extra payment -> GREEN (ADVANCE RECEIVED, not labelled CREDIT)
                          final isSubscription = vType.contains('SUBSCRIPTION') || mode == 'SUBSCRIPTION';
                          final isAdvanceOrPayment = debit <= 0.009 && credit > 0.009;
                          final double remainingDue = math.max(0.0, debit - credit);
                          final isUnpaidDue = !isSubscription && !isAdvanceOrPayment && remainingDue > 0.009;
                          final isFullyPaidSale = !isSubscription && !isAdvanceOrPayment && !isUnpaidDue;
                          final double availAdv = double.tryParse((widget.customer['total_advance'] ?? 0).toString()) ?? (_closingBalance < -0.009 ? _closingBalance.abs() : 0.0);

                          final Color iconBgColor = isUnpaidDue ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
                          final Color iconColor = isUnpaidDue ? const Color(0xFFDC2626) : const Color(0xFF059669);
                          final IconData iconData = isUnpaidDue
                              ? Icons.arrow_outward_rounded
                              : (isSubscription
                                  ? Icons.auto_awesome_rounded
                                  : (isFullyPaidSale ? Icons.check_circle_outline_rounded : Icons.arrow_downward_rounded));

                          final String badgeLabel = isSubscription
                              ? 'SUBSCRIPTION'
                              : (isUnpaidDue
                                  ? 'DUE'
                                  : (isAdvanceOrPayment
                                      ? (vType.contains('REPAY') ? 'REPAYMENT' : 'ADVANCE RECEIVED')
                                      : 'PAID'));

                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: iconBgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(iconData, size: 16, color: iconColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            ref,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (mode.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              mode,
                                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isUnpaidDue ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            badgeLabel,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: isUnpaidDue ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(dateStr, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (isUnpaidDue) ...[
                                    Text(
                                      '+₹${remainingDue.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
                                    ),
                                    if (credit > 0.009)
                                      Text(
                                        'Paid: ₹${credit.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.bold),
                                      ),
                                    if (availAdv > 0.009) ...[
                                      const SizedBox(height: 3),
                                      InkWell(
                                        onTap: () => _confirmAdjustAdvanceForBill(
                                          saleNo: ref,
                                          saleId: t['sale_id'] ?? t['id'],
                                          billDue: remainingDue,
                                          availableAdv: availAdv,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.auto_fix_high_rounded, size: 10, color: Color(0xFF059669)),
                                              SizedBox(width: 3),
                                              Text('Adjust Advance', style: TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ] else if (isSubscription) ...[
                                    Text(
                                      '₹${debit > 0 ? debit.toStringAsFixed(2) : credit.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
                                    ),
                                  ] else if (isFullyPaidSale) ...[
                                    Text(
                                      '₹${(debit > 0 ? debit : credit).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
                                    ),
                                  ] else if (isAdvanceOrPayment) ...[
                                    Text(
                                      '+₹${credit.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
                                    ),
                                  ] else ...[
                                    Text(
                                      '₹0.00',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                  Text(
                                    bal > 0.009
                                        ? 'Bal: ₹${bal.toStringAsFixed(2)} Dr'
                                        : (bal < -0.009 ? 'Bal: ₹${bal.abs().toStringAsFixed(2)} Cr' : 'Bal: ₹0.00 Settled'),
                                    style: TextStyle(
                                      color: bal > 0.009
                                          ? const Color(0xFFDC2626)
                                          : (bal < -0.009 ? const Color(0xFF059669) : const Color(0xFF64748B)),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share Summary on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _shareStatementWhatsApp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

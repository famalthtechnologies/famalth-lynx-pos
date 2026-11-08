import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class MobileCashLedgerSheet extends StatefulWidget {
  final int initialTab; // 0: Ledger, 1: Expenses

  const MobileCashLedgerSheet({super.key, this.initialTab = 0});

  @override
  State<MobileCashLedgerSheet> createState() => _MobileCashLedgerSheetState();
}

class _MobileCashLedgerSheetState extends State<MobileCashLedgerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String _dateFilter = 'TODAY'; // TODAY, WEEK, MONTH, CUSTOM
  DateTimeRange? _customRange;
  String _modeFilter = 'ALL'; // ALL, CASH, BANK

  // Ledger entries & summary
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  double _openingBalance = 0.0;
  double _totalIn = 0.0;
  double _totalOut = 0.0;
  double _closingBalance = 0.0;
  double _totalCash = 0.0;
  double _totalBank = 0.0;
  double _totalGst = 0.0;

  // Expenses entries & summary
  List<Map<String, dynamic>> _expenses = [];
  double _totalExpenseAmount = 0.0;

  List<String> _dynamicCategories = [];
  final Map<String, String> _categoryNameToId = {};
  List<String> _dynamicPaymentMethods = [];

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  final List<String> _expensePresets = const [
    'Salary',
    'Petrol',
    'Diesel',
    'Rent',
    'Tea & Refreshment',
    'Office Supplies',
    'Electricity',
    'Maintenance',
    'Delivery & Freight',
    'General Expense',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTimeRange _resolveDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_dateFilter) {
      case 'TODAY':
        return DateTimeRange(start: today, end: today);
      case 'WEEK':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: weekStart, end: today);
      case 'MONTH':
        final monthStart = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: monthStart, end: today);
      case 'CUSTOM':
        return _customRange ?? DateTimeRange(start: today.subtract(const Duration(days: 7)), end: today);
      default:
        return DateTimeRange(start: today, end: today);
    }
  }

  Future<void> _loadMetadata() async {
    try {
      final catRes = await ApiClient.get(ApiEndpoints.financeExpenseCategories);
      final rawCats = catRes['data'] as List? ?? [];
      final List<String> cats = [];
      for (final c in rawCats) {
        final name = (c['category_name'] ?? c['name'] ?? '').toString().trim();
        final id = (c['id'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          if (id.isNotEmpty) _categoryNameToId[name.toLowerCase()] = id;
          if (!cats.contains(name)) cats.add(name);
        }
      }
      if (cats.isNotEmpty) {
        _dynamicCategories = cats;
      }
    } catch (_) {}

    try {
      final pmRes = await ApiClient.get('/api/sales/payment-methods');
      final rawPm = pmRes['data'] as List? ?? [];
      final methods = rawPm
          .where((e) => e['is_active'] == true || e['is_active'] == 1)
          .map((e) => (e['name'] ?? '').toString().trim().toUpperCase())
          .where((s) => s.isNotEmpty)
          .toList();
      if (methods.isNotEmpty) {
        _dynamicPaymentMethods = methods;
      }
    } catch (_) {}
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadMetadata(),
      _loadLedgerInternal(),
      _loadExpensesInternal(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLedgerInternal() async {
    final range = _resolveDateRange();
    final fromStr = DateFormat('yyyy-MM-dd').format(range.start);
    final toStr = DateFormat('yyyy-MM-dd').format(range.end);

    try {
      final res = await ApiClient.get('/api/finance/ledger?from_date=$fromStr&to_date=$toStr');
      final List<Map<String, dynamic>> rawList = [];

      // Exactly like desktop: use res['data'] directly. Only fallback to daily if data is absent.
      if (res['data'] is List && (res['data'] as List).isNotEmpty) {
        rawList.addAll((res['data'] as List).map((e) => Map<String, dynamic>.from(e)));
      } else if (res['daily'] is List) {
        for (final day in res['daily']) {
          if (day is Map && day['entries'] is List) {
            for (final entry in day['entries']) {
              if (entry is Map) {
                final m = Map<String, dynamic>.from(entry);
                if (m['date'] == null && day['date'] != null) {
                  m['date'] = day['date'].toString().split('T').first;
                }
                rawList.add(m);
              }
            }
          }
        }
      }

      final summary = res['summary'] ?? {};
      final paySummary = res['payment_method_summary'] is List ? (res['payment_method_summary'] as List) : [];
      double cashIn = 0;
      double bankIn = 0;
      double gstSum = 0;

      for (final pm in paySummary) {
        final m = (pm['payment_method'] ?? '').toString().toUpperCase();
        final inVal = double.tryParse((pm['amount_in'] ?? 0).toString()) ?? 0.0;
        if (m == 'CASH') {
          cashIn += inVal;
        } else if (m != 'CREDIT' && m != 'SUBSCRIPTION') {
          bankIn += inVal;
        }
      }

      // Fallback calculation from entries if payment_method_summary wasn't provided
      if (cashIn == 0 && bankIn == 0 && rawList.isNotEmpty) {
        for (final e in rawList) {
          final mode = (e['payment_method'] ?? e['paymentMethod'] ?? e['payment_mode'] ?? 'CASH').toString().toUpperCase();
          final inAmt = _ledgerEntryCredit(e);
          if (mode == 'CASH') {
            cashIn += inAmt;
          } else if (mode != 'CREDIT' && mode != 'SUBSCRIPTION') {
            bankIn += inAmt;
          }
        }
      }

      for (final e in rawList) {
        final tax = double.tryParse((e['tax_amount'] ?? e['total_tax'] ?? e['tax'] ?? 0).toString()) ?? 0.0;
        gstSum += tax;
      }

      if (mounted) {
        setState(() {
          _entries = rawList;
          _openingBalance = double.tryParse((summary['openingBalance'] ?? 0).toString()) ?? 0.0;
          _totalIn = double.tryParse((summary['totalIn'] ?? 0).toString()) ?? (cashIn + bankIn);
          _totalOut = double.tryParse((summary['totalOut'] ?? 0).toString()) ?? 0.0;
          _closingBalance = double.tryParse((summary['closingBalance'] ?? 0).toString()) ?? (_openingBalance + _totalIn - _totalOut);
          _totalCash = cashIn;
          _totalBank = bankIn;
          _totalGst = gstSum;
          _filterEntries();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadExpensesInternal() async {
    final range = _resolveDateRange();
    final fromStr = DateFormat('yyyy-MM-dd').format(range.start);
    final toStr = DateFormat('yyyy-MM-dd').format(range.end);

    try {
      final res = await ApiClient.get('${ApiEndpoints.financeExpenses}?from_date=$fromStr&to_date=$toStr');
      final list = (res['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      final total = double.tryParse((res['summary']?['totalAmount'] ?? 0).toString()) ??
          list.fold<double>(0.0, (sum, e) => sum + (double.tryParse((e['net_payable_amount'] ?? e['amount'] ?? e['total_amount'] ?? 0).toString()) ?? 0.0));

      if (mounted) {
        setState(() {
          _expenses = list;
          _totalExpenseAmount = total;
        });
      }
    } catch (_) {}
  }

  void _filterEntries() {
    setState(() {
      _filteredEntries = _entries.where((e) {
        if (_modeFilter == 'ALL') return true;
        final mode = (e['payment_method'] ?? e['paymentMethod'] ?? e['payment_mode'] ?? e['paymentMode'] ?? 'CASH').toString().toUpperCase();
        if (_modeFilter == 'CASH') {
          return mode == 'CASH';
        } else {
          return mode != 'CASH' && mode != 'CREDIT' && e['is_credit'] != true;
        }
      }).toList();
    });
  }

  String _ledgerTypeLabel(String type) {
    switch (type.trim().toUpperCase()) {
      case 'SALE_CASH':
      case 'SALE':
        return 'Sales';
      case 'SALE_CREDIT':
        return 'Sales Credit';
      case 'SALE_DISCOUNT_EXPENSE':
        return 'Sale Discount Expense';
      case 'CUSTOMER_ADVANCE':
        return 'Customer Advance';
      case 'ADVANCE_APPLY':
      case 'ADVANCE_ADJUSTMENT':
      case 'SALE_SUBSCRIPTION_ADJUSTMENT':
        return 'Advance Adjustment';
      case 'SUBSCRIPTION_SETTLEMENT':
        return 'Subscription Settlement';
      case 'REPAYMENT':
      case 'CUSTOMER_REPAYMENT':
        return 'Credit Payment';
      case 'WAIVE_OFF':
        return 'Waive Off';
      case 'OPENING_DEPOSIT':
      case 'OPENING':
        return 'Opening';
      case 'WITHDRAWAL':
        return 'Cash Withdrawal';
      case 'INCOME':
        return 'Other Income';
      case 'EXPENSE':
        return 'Expense';
      case 'SUPPLIER_PAYMENT':
        return 'Supplier Payment';
      case 'PURCHASE_GRN':
        return 'Purchase GRN';
      case 'SALE_SCHEME_FREE_EXPENSE':
      case 'SUBSCRIPTION_SCHEME_FREE_EXPENSE':
      case 'SALE_SUBSCRIPTION_FREE_EXPENSE':
        return 'Scheme Free Expense';
      case 'SALE_MODIFY_ADJUSTMENT':
        return 'Bill Adjustment';
      default:
        return type
            .trim()
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  String _resolveVoucherNo(Map<String, dynamic> entry) {
    final ref = (entry['reference_no'] ?? entry['voucher_no'] ?? entry['voucherNo'] ?? '').toString().trim();
    final type = (entry['transaction_type'] ?? entry['transactionType'] ?? '').toString().trim().toUpperCase();
    final refType = (entry['reference_type'] ?? entry['referenceType'] ?? '').toString().trim().toUpperCase();

    if (ref.startsWith('PV-') ||
        ref.startsWith('SV-') ||
        ref.startsWith('RV-') ||
        ref.startsWith('CN-') ||
        ref.startsWith('JV-')) {
      return ref;
    }

    if (type.contains('SALE') || refType == 'SALE') {
      return ref.isNotEmpty ? 'SV-$ref' : 'SV-0001';
    } else if (type.contains('REPAYMENT') || type.contains('CREDIT PAYMENT') || refType == 'REPAYMENT') {
      return ref.isNotEmpty ? 'RV-$ref' : 'RV-0001';
    } else if (type.contains('SUBSCRIPTION') || type.contains('ADVANCE') || refType.contains('ADVANCE')) {
      return ref.isNotEmpty ? (ref.startsWith('RV-') ? ref : 'RV-$ref') : 'RV-0001';
    } else if (type.contains('SUPPLIER') || type.contains('VENDOR') || type.contains('REFUND') || refType.contains('SUPPLIER')) {
      return ref.isNotEmpty ? (ref.startsWith('PV-') ? ref : 'PV-$ref') : 'PV-0001';
    } else if (type == 'EXPENSE' || refType == 'EXPENSE') {
      return ref.isNotEmpty ? 'PV-$ref' : 'PV-0001';
    } else if (type == 'INCOME' || refType == 'INCOME') {
      return ref.isNotEmpty ? 'RV-$ref' : 'RV-0001';
    } else if (type == 'WITHDRAWAL' || type == 'CONTRA' || refType == 'WITHDRAWAL') {
      return ref.isNotEmpty ? 'CN-$ref' : 'CN-0001';
    } else if (type == 'OPENING' || refType == 'OPENING_DEPOSIT') {
      return ref.isNotEmpty ? (ref.startsWith('RV-') ? ref : 'RV-$ref') : 'RV-OPENING';
    }
    return ref.isNotEmpty ? ref : '-';
  }

  double _ledgerEntryCredit(Map<String, dynamic> entry) {
    final mode = (entry['payment_method'] ?? entry['paymentMethod'] ?? entry['payment_mode'] ?? '').toString().toUpperCase();
    final type = (entry['transaction_type'] ?? entry['transactionType'] ?? '').toString().toUpperCase();
    final isCreditMode = type == 'SALE_CREDIT' || mode == 'CREDIT';
    if (isCreditMode) return 0.0;
    return double.tryParse((entry['amount_in'] ?? entry['amountIn'] ?? entry['credit'] ?? 0).toString()) ?? 0.0;
  }

  double _ledgerEntryDebit(Map<String, dynamic> entry) {
    final mode = (entry['payment_method'] ?? entry['paymentMethod'] ?? entry['payment_mode'] ?? '').toString().toUpperCase();
    final type = (entry['transaction_type'] ?? entry['transactionType'] ?? '').toString().toUpperCase();
    final isCreditMode = type == 'SALE_CREDIT' || mode == 'CREDIT';
    if (isCreditMode) return 0.0;
    final outAmt = double.tryParse((entry['amount_out'] ?? entry['amountOut'] ?? entry['debit'] ?? 0).toString()) ?? 0.0;
    if (outAmt > 0.009) return outAmt;
    final isAdvanceAdjust = type == 'ADVANCE_APPLY' || type == 'ADVANCE_ADJUSTMENT' || type == 'SALE_SUBSCRIPTION_ADJUSTMENT';
    final adjAmt = double.tryParse((entry['adjustment_amount'] ?? entry['adjustmentAmount'] ?? 0).toString()) ?? 0.0;
    if (isAdvanceAdjust && adjAmt > 0.009) {
      return adjAmt;
    }
    return 0.0;
  }

  void _openAddExpenseModal() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final customCatCtrl = TextEditingController();
    final allCats = _dynamicCategories.isNotEmpty ? List<String>.from(_dynamicCategories) : List<String>.from(_expensePresets);
    String selectedCategory = allCats.first;
    final allModes = _dynamicPaymentMethods.isNotEmpty ? List<String>.from(_dynamicPaymentMethods) : ['CASH', 'UPI', 'BANK', 'CARD'];
    String paymentMethod = allModes.first;
    double taxPercent = 0.0;
    bool isTaxInclusive = false;
    bool saving = false;
    bool isAddingNewCat = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.add_card_rounded, color: Color(0xFFDC2626), size: 22),
                          SizedBox(width: 8),
                          Text('Record Store Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: textMuted),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(color: borderSubtle),
                  const SizedBox(height: 8),

                  // Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    decoration: const InputDecoration(
                      labelText: 'Expense Amount (₹) *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Selection Chips & Add Category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Category', style: TextStyle(color: textDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      InkWell(
                        onTap: () => setModalState(() => isAddingNewCat = !isAddingNewCat),
                        child: Text(
                          isAddingNewCat ? 'Cancel' : '+ New Category',
                          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (isAddingNewCat) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customCatCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'New Category Name',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onPressed: () async {
                            final name = customCatCtrl.text.trim();
                            if (name.isNotEmpty) {
                              try {
                                final postRes = await ApiClient.post(ApiEndpoints.financeExpenseCategories, {'category_name': name});
                                final newId = (postRes is Map && postRes['data'] is Map ? postRes['data']['id'] : null)?.toString() ?? '';
                                if (newId.isNotEmpty) _categoryNameToId[name.toLowerCase()] = newId;
                                if (!allCats.contains(name)) allCats.add(name);
                                if (!_dynamicCategories.contains(name)) _dynamicCategories.add(name);
                                setModalState(() {
                                  selectedCategory = name;
                                  isAddingNewCat = false;
                                  customCatCtrl.clear();
                                });
                              } catch (_) {
                                if (!allCats.contains(name)) allCats.add(name);
                                setModalState(() {
                                  selectedCategory = name;
                                  isAddingNewCat = false;
                                });
                              }
                            }
                          },
                          child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: allCats.take(12).map((cat) {
                      final isSel = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat, style: TextStyle(fontSize: 11.5, color: isSel ? Colors.white : textDark)),
                        selected: isSel,
                        selectedColor: const Color(0xFFDC2626),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSel ? const Color(0xFFDC2626) : borderSubtle),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Payment Mode
                  const Text('Payment Mode', style: TextStyle(color: textDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: allModes.map((m) {
                        final isSel = paymentMethod == m;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(m, style: TextStyle(fontSize: 11.5, color: isSel ? Colors.white : textDark)),
                            selected: isSel,
                            selectedColor: const Color(0xFF0F172A),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: isSel ? const Color(0xFF0F172A) : borderSubtle),
                            onSelected: (val) {
                              if (val) setModalState(() => paymentMethod = m);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description / Note
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Notes / Particulars',
                      hintText: 'e.g. Paid diesel for generator, tea for staff...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Reference No & GST Tax %
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: refCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Bill / Voucher No',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          value: taxPercent,
                          style: const TextStyle(color: textDark, fontSize: 13),
                          decoration: const InputDecoration(labelText: 'GST Tax %', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                            DropdownMenuItem(value: 5.0, child: Text('5% GST')),
                            DropdownMenuItem(value: 12.0, child: Text('12% GST')),
                            DropdownMenuItem(value: 18.0, child: Text('18% GST')),
                            DropdownMenuItem(value: 28.0, child: Text('28% GST')),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => taxPercent = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                              if (amt <= 0) {
                                ScaffoldMessenger.of(modalCtx).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid expense amount')),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                final now = DateTime.now();
                                final resolvedCatId = _categoryNameToId[selectedCategory.toLowerCase()] ?? selectedCategory;
                                final payload = {
                                  'payment_date': DateFormat('yyyy-MM-dd').format(now),
                                  'category_name': selectedCategory,
                                  'category_id': resolvedCatId,
                                  'amount': amt,
                                  'invoice_ref_no': refCtrl.text.trim(),
                                  'payment_method': paymentMethod,
                                  'is_tax_inclusive': isTaxInclusive,
                                  'expense_note': noteCtrl.text.trim(),
                                  'note': noteCtrl.text.trim(),
                                  'status': 'PAID',
                                  'taxes': taxPercent > 0
                                      ? [
                                          {'tax_name': 'GST', 'tax_rate': taxPercent}
                                        ]
                                      : [],
                                  'deductions': [],
                                };

                                await ApiClient.post(ApiEndpoints.financeExpenses, payload);
                                HapticFeedback.heavyImpact();
                                Navigator.pop(modalCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Expense of ₹${amt.toStringAsFixed(2)} recorded successfully!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                                _loadAllData();
                              } catch (e) {
                                setModalState(() => saving = false);
                                ScaffoldMessenger.of(modalCtx).showSnackBar(
                                  SnackBar(content: Text('Error saving expense: $e'), backgroundColor: Colors.redAccent),
                                );
                              }
                            },
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Expense Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header with Tabs
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: borderSubtle)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 22),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Cash, Bank & Expenses',
                              style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            minimumSize: const Size(44, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add, size: 13),
                          label: const Text('Expense', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: _openAddExpenseModal,
                        ),
                        IconButton(
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close, color: textMuted, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: textMuted,
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Cash & Bank Ledger'),
                    Tab(text: 'Store Expenses'),
                  ],
                ),
              ],
            ),
          ),

          // Date Filter Chips
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _buildDateChip('TODAY', 'Today'),
                const SizedBox(width: 8),
                _buildDateChip('WEEK', 'This Week'),
                const SizedBox(width: 8),
                _buildDateChip('MONTH', 'This Month'),
                const SizedBox(width: 8),
                _buildDateChip(
                  'CUSTOM',
                  _customRange != null
                      ? '${DateFormat('dd MMM').format(_customRange!.start)} - ${DateFormat('dd MMM').format(_customRange!.end)}'
                      : 'Custom',
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLedgerTab(),
                _buildExpensesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTab() {
    return Column(
      children: [
        // Summary Strip with Cash & Bank breakdown
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderSubtle),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Opening Balance: ₹${_openingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                    child: Text('Closing: ₹${_closingBalance.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(height: 16, color: borderSubtle),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cash In (+)', style: TextStyle(color: textMuted, fontSize: 11)),
                        Text('₹${_totalCash.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bank / UPI In (+)', style: TextStyle(color: textMuted, fontSize: 11)),
                        Text('₹${_totalBank.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Out (-)', style: TextStyle(color: textMuted, fontSize: 11)),
                        Text('₹${_totalOut.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
              if (_totalGst > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text('GST Collected: ₹${_totalGst.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Mode filter row (All, Cash, Bank/UPI)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildModePill('ALL', 'All Modes'),
              const SizedBox(width: 8),
              _buildModePill('CASH', 'Cash Only'),
              const SizedBox(width: 8),
              _buildModePill('BANK', 'Bank / UPI / Card'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Ledger Transactions List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredEntries.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 54, color: textMuted),
                          SizedBox(height: 10),
                          Text('No transactions recorded for this period', style: TextStyle(color: textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAllData,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final e = _filteredEntries[idx];
                          final voucher = _resolveVoucherNo(e);
                          final rawType = (e['transaction_type'] ?? e['transactionType'] ?? e['reference_type'] ?? '').toString().trim();
                          final typeLabel = _ledgerTypeLabel(rawType);
                          final party = (e['party_name'] ?? e['partyName'] ?? '').toString().trim();
                          final note = (e['notes'] ?? e['expense_note'] ?? '').toString().trim();
                          final date = (e['date'] ?? e['txn_date'] ?? '').toString().split('T').first;
                          final mode = (e['payment_method'] ?? e['paymentMethod'] ?? e['payment_mode'] ?? 'CASH').toString().toUpperCase();
                          final creditAmt = _ledgerEntryCredit(e);
                          final debitAmt = _ledgerEntryDebit(e);
                          final balance = double.tryParse((e['balance'] ?? 0).toString()) ?? 0.0;
                          final taxAmt = double.tryParse((e['tax_amount'] ?? e['total_tax'] ?? 0).toString()) ?? 0.0;

                          final isCredit = mode == 'CREDIT' || e['is_credit'] == true || rawType == 'SALE_CREDIT';
                          final isDebit = debitAmt > 0.009;
                          final isCreditIn = creditAmt > 0.009;

                          Color modeColor = const Color(0xFF059669);
                          if (isCredit) {
                            modeColor = const Color(0xFFD97706);
                          } else if (mode.contains('SUBSCRIPTION')) {
                            modeColor = const Color(0xFF0284C7);
                          } else if (mode.contains('BANK')) {
                            modeColor = const Color(0xFF2563EB);
                          } else if (mode.contains('UPI') || mode.contains('PHONEPE') || mode.contains('GPAY')) {
                            modeColor = const Color(0xFF7C3AED);
                          } else if (mode.contains('CARD')) {
                            modeColor = const Color(0xFFD97706);
                          }

                          final Color leadingBg = isCredit
                              ? const Color(0xFFFFFBEB)
                              : (isDebit ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5));
                          final Color leadingColor = isCredit
                              ? const Color(0xFFD97706)
                              : (isDebit ? const Color(0xFFDC2626) : const Color(0xFF059669));
                          final IconData leadingIcon = isCredit
                              ? Icons.hourglass_top_rounded
                              : (isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

                          return Container(
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
                                  decoration: BoxDecoration(
                                    color: leadingBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    leadingIcon,
                                    size: 16,
                                    color: leadingColor,
                                  ),
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
                                              voucher,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFBFDBFE)),
                                            ),
                                            child: Text(
                                              typeLabel,
                                              style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 9.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: modeColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(mode, style: TextStyle(color: modeColor, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                          ),
                                          if (taxAmt > 0) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text('GST: ₹${taxAmt.toStringAsFixed(0)}',
                                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      if (party.isNotEmpty || note.isNotEmpty) ...[
                                        Text(
                                          party.isNotEmpty && note.isNotEmpty ? '$party • $note' : (note.isNotEmpty ? note : party),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: textMuted, fontSize: 11),
                                        ),
                                      ],
                                      Text(date, style: const TextStyle(color: textMuted, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                if (isCredit) ...[
                                  Builder(
                                    builder: (context) {
                                      double dueAmt = double.tryParse((e['adjustment_amount'] ?? e['customer_due'] ?? e['balance_due'] ?? e['amount'] ?? 0).toString()) ?? 0.0;
                                      if (dueAmt <= 0.009) {
                                        final notesStr = (e['notes'] ?? e['expense_note'] ?? '').toString();
                                        final match = RegExp(r'outstanding\s+([\d\.]+)').firstMatch(notesStr);
                                        if (match != null) {
                                          dueAmt = double.tryParse(match.group(1) ?? '0') ?? 0.0;
                                        }
                                      }
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${dueAmt.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Color(0xFFB45309),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Text(
                                            'Credit / Due',
                                            style: TextStyle(
                                              color: Color(0xFFD97706),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ] else if (isDebit) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '-₹${debitAmt.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (balance > 0.009)
                                        Text(
                                          'Bal: ₹${balance.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ] else ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '+₹${creditAmt.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (balance > 0.009)
                                        Text(
                                          'Bal: ₹${balance.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
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
    );
  }

  Widget _buildExpensesTab() {
    return Column(
      children: [
        // Expense Total Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Outflow / Expenses', style: TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('₹${_totalExpenseAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _openAddExpenseModal,
              ),
            ],
          ),
        ),

        // Expense Entries List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_outlined, size: 54, color: textMuted),
                          const SizedBox(height: 10),
                          const Text('No expenses recorded for this period', style: TextStyle(color: textMuted, fontSize: 13)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Record First Expense'),
                            onPressed: _openAddExpenseModal,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAllData,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final exp = _expenses[idx];
                          final rawCat = (exp['category_name'] ?? exp['category']?['category_name'] ?? '').toString().trim();
                          final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(rawCat);
                          final cat = (!isUuid && rawCat.isNotEmpty)
                              ? rawCat
                              : ((exp['expense_note'] ?? exp['note'] ?? '').toString().trim().isNotEmpty
                                  ? (exp['expense_note'] ?? exp['note']).toString()
                                  : 'Store Expense');
                          final amt = double.tryParse((exp['net_payable_amount'] ?? exp['amount'] ?? exp['total_amount'] ?? 0).toString()) ?? 0.0;
                          final date = (exp['payment_date'] ?? exp['created_at'] ?? '').toString().split('T').first;
                          final note = (exp['expense_note'] ?? exp['note'] ?? '').toString();
                          final mode = (exp['payment_method'] ?? exp['payment_mode'] ?? 'CASH').toString().toUpperCase();

                          return Container(
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
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEF2F2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_upward_rounded, size: 16, color: Color(0xFFDC2626)),
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
                                              cat,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(mode, style: const TextStyle(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      if (note.isNotEmpty && note != cat) ...[
                                        const SizedBox(height: 2),
                                        Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textMuted, fontSize: 11)),
                                      ],
                                      Text(date, style: const TextStyle(color: textMuted, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '-₹${amt.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildDateChip(String key, String label) {
    final isSel = _dateFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 12)),
      selected: isSel,
      selectedColor: const Color(0xFF059669),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSel ? const Color(0xFF059669) : borderSubtle),
      onSelected: (val) async {
        if (key == 'CUSTOM') {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDateRange: _customRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
          );
          if (picked != null) {
            setState(() {
              _dateFilter = 'CUSTOM';
              _customRange = picked;
            });
            _loadAllData();
          }
        } else {
          setState(() {
            _dateFilter = key;
          });
          _loadAllData();
        }
      },
    );
  }

  Widget _buildModePill(String key, String label) {
    final isSel = _modeFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _modeFilter = key);
        _filterEntries();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSel ? const Color(0xFF0F172A) : borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

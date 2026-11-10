import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';
import '../../core/billing/pos_billing_engine.dart';
import '../../core/config/app_brand.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/billing_charge_model.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/sale_customer_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/inventory/sale_scheme_model.dart';
import '../../widgets/app_setup_qr_dialog.dart';
import 'mobile_bill_modify_sheet.dart';
import 'mobile_billing_auth_screen.dart';
import 'mobile_cash_ledger_sheet.dart';
import 'mobile_customer_ledger_sheet.dart';
import 'mobile_item_master_sheet.dart';
import 'mobile_stock_balance_sheet.dart';

class MobileBillingAppScreen extends StatefulWidget {
  const MobileBillingAppScreen({super.key});

  @override
  State<MobileBillingAppScreen> createState() => _MobileBillingAppScreenState();
}

class _MobileBillingAppScreenState extends State<MobileBillingAppScreen> {
  int _currentTab = 0; // 0: POS Billing, 1: Orders / Reprints, 2: Subs, 3: Analytics, 4: Profile

  // POS State & Controller
  final SalesController _salesCtrl = SalesController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Item> _allItems = [];
  List<Item> _filteredItems = [];
  List<SaleScheme> _allSchemes = [];
  List<SaleCustomer> _allCustomers = [];
  List<String> _paymentMethods = ['CASH', 'UPI', 'CARD', 'CREDIT'];
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  // Cart: Map<itemId, CartEntry>
  final Map<int, _CartEntry> _cart = {};

  // Analytics & Orders State
  bool _isLoading = false;
  List<SaleOrder> _recentOrders = [];
  List<SaleOrder> _filteredOrders = [];
  final TextEditingController _reprintSearchCtrl = TextEditingController();

  // Date filters ('TODAY', 'WEEK', 'MONTH', 'CUSTOM') - default is 'TODAY'
  String _orderDateFilter = 'TODAY';
  DateTimeRange? _orderCustomRange;
  String _analyticsDateFilter = 'TODAY';
  DateTimeRange? _analyticsCustomRange;

  double _analyticsRevenue = 0.0;
  int _analyticsBillsCount = 0;
  double _analyticsCash = 0.0;
  double _analyticsDigital = 0.0;
  double _analyticsCreditSales = 0.0;
  double _analyticsDebitedOut = 0.0;
  double _customerCreditOutstanding = 0.0;
  double _supplierPayableOutstanding = 0.0;
  List<Map<String, dynamic>> _topItems = [];

  // Subscriptions State
  List<Map<String, dynamic>> _allSubscriptions = [];
  List<Map<String, dynamic>> _filteredSubscriptions = [];
  String _subsStatusFilter = 'ALL'; // 'ALL', 'ACTIVE', 'UPCOMING_RENEWAL', 'EXPIRED'
  final TextEditingController _subsSearchCtrl = TextEditingController();
  bool _loadingSubs = false;
  bool _isAdmin = false;

  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _loadCatalogAndMetadata();
    _loadPulseAndOrders();
    _loadSubscriptions();
    _searchCtrl.addListener(_filterItems);
    _reprintSearchCtrl.addListener(_filterOrders);
    _subsSearchCtrl.addListener(_filterSubscriptions);
  }

  Future<void> _checkAdminRole() async {
    try {
      final role = (await TokenStorage.getRole() ?? '').toUpperCase().trim();
      final user = await TokenStorage.getUser();
      final userRole = (user?['role'] ?? role).toString().toUpperCase().trim();
      if (mounted) {
        setState(() {
          _isAdmin = userRole == 'ADMIN' ||
              userRole == 'SUPER_ADMIN' ||
              userRole == 'OWNER' ||
              userRole == 'ENTERPRISE_ADMIN';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reprintSearchCtrl.dispose();
    _subsSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogAndMetadata() async {
    setState(() => _isLoading = true);
    try {
      await _salesCtrl.loadInitialData();
      _allItems = _salesCtrl.items;
      _allSchemes = _salesCtrl.schemes;
      _allCustomers = _salesCtrl.customers;

      // Ensure Property info and System settings are loaded
      try {
        final propCtrl = Provider.of<PropertyInfoController>(context, listen: false);
        if (propCtrl.data == null) await propCtrl.load();
      } catch (_) {}
      try {
        final settingsCtrl = Provider.of<SystemSettingsController>(context, listen: false);
        if (settingsCtrl.settings == null) await settingsCtrl.load();
      } catch (_) {}

      // Extract unique categories
      final cats = <String>{'All'};
      for (final it in _allItems) {
        final grp = it.itemGroup.trim();
        final sub = it.subCategory.trim();
        if (grp.isNotEmpty) cats.add(grp);
        if (sub.isNotEmpty) cats.add(sub);
      }
      _categories = cats.toList();

      // Load Payment Methods configured in system
      try {
        final pmList = await _salesCtrl.listPaymentMethods();
        final activePm = pmList
            .where((m) => m['is_active'] != false)
            .map((m) => m['name'].toString().toUpperCase())
            .toList();
        if (activePm.isNotEmpty) {
          _paymentMethods = activePm;
        }
      } catch (_) {}

      _filterItems();
    } catch (_) {
      // Handled gracefully in UI
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPulseAndOrders() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.sales);
      if (res['data'] is List) {
        final list = (res['data'] as List)
            .map((e) => SaleOrder.fromJson(e as Map<String, dynamic>))
            .toList();

        _recentOrders = list;
        _filterOrders();
        _recalculateAnalytics();
      }

      // Fetch customer credit outstanding
      try {
        final creditRes = await ApiClient.get(ApiEndpoints.financeCreditReport);
        double custSum = 0;
        if (creditRes['summary']?['total_outstanding'] != null) {
          custSum = double.tryParse(creditRes['summary']['total_outstanding'].toString()) ?? 0.0;
        } else if (creditRes['data'] is List) {
          for (final c in creditRes['data']) {
            final due = double.tryParse((c['total_outstanding'] ?? c['outstanding_balance'] ?? c['total_credit'] ?? 0).toString()) ?? 0.0;
            custSum += due;
          }
        }
        if (mounted) setState(() => _customerCreditOutstanding = custSum);
      } catch (_) {}

      // Fetch supplier outstanding (unpaid bills retailer needs to pay)
      try {
        final supRes = await ApiClient.get('${ApiEndpoints.supplierBills}?fromDate=2020-01-01&toDate=2099-12-31');
        final supDue = double.tryParse((supRes['summary']?['totalUnpaid'] ?? 0).toString()) ?? 0.0;
        if (mounted) setState(() => _supplierPayableOutstanding = supDue);
      } catch (_) {}

      // Fetch top selling products from analytics endpoint
      try {
        final analyticsRes = await ApiClient.get(ApiEndpoints.analyticsTopCustomerItems);
        if (analyticsRes['data'] is List) {
          final raw = analyticsRes['data'] as List;
          final top = raw.map((e) {
            final rawQty = e['totalQty'] ?? e['total_qty'] ?? e['quantity'] ?? e['qty'] ?? 0;
            final numVal = double.tryParse(rawQty.toString()) ?? 0;
            final qtyStr = numVal > 0 ? '${numVal.toInt()} sold' : '1 sold';
            final name = (e['itemName'] ?? e['item_name'] ?? e['name'] ?? 'Product').toString().trim();
            return {
              'name': name,
              'qty': qtyStr,
            };
          }).where((m) => m['name']!.isNotEmpty && m['name'] != 'Unknown Item').take(5).toList();

          if (mounted && top.isNotEmpty) {
            setState(() => _topItems = top);
          }
        }
      } catch (_) {}
    } catch (_) {}
  }

  bool _isOrderInDateFilter(SaleOrder order, String filter, DateTimeRange? customRange) {
    final orderDate = DateTime(order.saleDate.year, order.saleDate.month, order.saleDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case 'TODAY':
        return orderDate.isAtSameMomentAs(today);
      case 'WEEK':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return !orderDate.isBefore(weekStart) && !orderDate.isAfter(today);
      case 'MONTH':
        final monthStart = DateTime(now.year, now.month, 1);
        return !orderDate.isBefore(monthStart) && !orderDate.isAfter(today);
      case 'CUSTOM':
        if (customRange == null) return true;
        final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day);
        return !orderDate.isBefore(start) && !orderDate.isAfter(end);
      default:
        return true;
    }
  }

  void _recalculateAnalytics() {
    double rev = 0;
    int count = 0;
    double cash = 0;
    double digital = 0;
    double creditSales = 0;

    final Map<String, double> itemSoldCounts = {};

    for (final o in _recentOrders) {
      if (_isOrderInDateFilter(o, _analyticsDateFilter, _analyticsCustomRange)) {
        rev += o.netAmount;
        count++;
        final mode = o.paymentMode.toUpperCase();
        if (mode == 'CASH') {
          cash += o.amountPaid > 0 ? o.amountPaid : (o.balanceDue <= 0.01 ? o.netAmount : 0.0);
        } else if (mode == 'CREDIT') {
          creditSales += (o.balanceDue > 0 ? o.balanceDue : o.netAmount);
          if (o.amountPaid > 0) {
            digital += o.amountPaid;
          }
        } else {
          // BANK, UPI, CARD, SUBSCRIPTION
          digital += o.amountPaid > 0 ? o.amountPaid : (o.balanceDue <= 0.01 ? o.netAmount : 0.0);
        }
        for (final item in o.items) {
          final name = item.itemName.trim();
          if (name.isNotEmpty && name != 'Unknown Item') {
            itemSoldCounts[name] = (itemSoldCounts[name] ?? 0) + item.qty;
          }
        }
      }
    }

    List<Map<String, dynamic>> computedTop = [];
    if (itemSoldCounts.isNotEmpty) {
      final sorted = itemSoldCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      computedTop = sorted.where((e) => e.value > 0).take(5).map((e) => {
        'name': e.key,
        'qty': '${e.value.toInt()} sold',
      }).toList();
    }

    if (mounted) {
      setState(() {
        _analyticsRevenue = rev;
        _analyticsBillsCount = count;
        _analyticsCash = cash;
        _analyticsDigital = digital;
        _analyticsCreditSales = creditSales;
        if (computedTop.isNotEmpty) {
          _topItems = computedTop;
        }
      });
    }
    _loadDebitedOutflow();
  }

  Future<void> _loadDebitedOutflow() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime start = today;
    DateTime end = today;
    if (_analyticsDateFilter == 'WEEK') {
      start = today.subtract(Duration(days: today.weekday - 1));
    } else if (_analyticsDateFilter == 'MONTH') {
      start = DateTime(now.year, now.month, 1);
    } else if (_analyticsDateFilter == 'CUSTOM' && _analyticsCustomRange != null) {
      start = _analyticsCustomRange!.start;
      end = _analyticsCustomRange!.end;
    }
    final fromStr = DateFormat('yyyy-MM-dd').format(start);
    final toStr = DateFormat('yyyy-MM-dd').format(end);

    try {
      final res = await ApiClient.get('/api/finance/ledger?from_date=$fromStr&to_date=$toStr');
      final totalOut = double.tryParse((res['summary']?['totalOut'] ?? 0).toString()) ?? 0.0;
      if (mounted) {
        setState(() {
          _analyticsDebitedOut = totalOut;
        });
      }
    } catch (_) {}
  }

  void _filterItems() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final matchCategory = _selectedCategory == 'All' ||
            item.itemGroup == _selectedCategory ||
            item.subCategory == _selectedCategory;
        final matchQuery = query.isEmpty ||
            item.itemName.toLowerCase().contains(query) ||
            item.barcode.toLowerCase().contains(query) ||
            item.itemCode.toLowerCase().contains(query);
        return matchCategory && matchQuery;
      }).toList();
    });
  }

  void _filterOrders() {
    final q = _reprintSearchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredOrders = _recentOrders.where((o) {
        final matchesDate = _isOrderInDateFilter(o, _orderDateFilter, _orderCustomRange);
        if (!matchesDate) return false;
        if (q.isEmpty) return true;
        return o.saleNo.toLowerCase().contains(q) ||
            (o.customerName ?? '').toLowerCase().contains(q) ||
            (o.customerPhone ?? '').toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<SaleOrder> _fetchFullOrder(SaleOrder order) async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.sales}/${order.saleNo}');
      if (res['data'] != null) {
        return SaleOrder.fromJson(Map<String, dynamic>.from(res['data']));
      }
    } catch (_) {}
    return order;
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _loadingSubs = true);
    try {
      final subs = await _salesCtrl.listSubscriptions();
      _allSubscriptions = subs;
      _filterSubscriptions();
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingSubs = false);
    }
  }

  void _filterSubscriptions() {
    final q = _subsSearchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredSubscriptions = _allSubscriptions.where((sub) {
        final status = (sub['status'] ?? '').toString().toUpperCase();
        final isActive = sub['active_subscription'] == true || status == 'ACTIVE';

        bool matchesStatus = true;
        if (_subsStatusFilter == 'ACTIVE') {
          matchesStatus = isActive;
        } else if (_subsStatusFilter == 'UPCOMING_RENEWAL') {
          final endDateStr = sub['end_date']?.toString();
          if (endDateStr != null) {
            final endDate = DateTime.tryParse(endDateStr);
            if (endDate != null) {
              final diff = endDate.difference(DateTime.now()).inDays;
              matchesStatus = diff >= 0 && diff <= 7;
            } else {
              matchesStatus = false;
            }
          } else {
            matchesStatus = false;
          }
        } else if (_subsStatusFilter == 'EXPIRED') {
          matchesStatus = status == 'EXPIRED' || (!isActive && status != 'CANCELLED');
        }

        if (!matchesStatus) return false;
        if (q.isEmpty) return true;

        final custName = (sub['customer_name'] ?? '').toString().toLowerCase();
        final custPhone = (sub['customer_phone'] ?? '').toString().toLowerCase();
        final itemName = (sub['item_name'] ?? '').toString().toLowerCase();
        return custName.contains(q) || custPhone.contains(q) || itemName.contains(q);
      }).toList();
    });
  }

  double _getItemPrice(Item item) {
    if (item.retailSalePrice > 0) return item.retailSalePrice;
    if (item.rate > 0) return item.rate;
    if (item.mrp > 0) return item.mrp;
    return 0.0;
  }

  void _addToCart(Item item) {
    final settingsCtrl = context.read<SystemSettingsController>();
    final allowNegative = settingsCtrl.settings?.allowNegativeStock ?? false;
    final inCart = _cart[item.id]?.quantity ?? 0;
    final double availableStock = item.openingBalance - inCart;

    if (item.stockable && availableStock <= 0 && !allowNegative) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot add "${item.itemName}": Out of stock (Negative stock not allowed)'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.quantity += 1;
      } else {
        _cart[item.id] = _CartEntry(item: item, quantity: 1);
      }
    });
  }

  void _decreaseCartItem(int itemId) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_cart.containsKey(itemId)) {
        if (_cart[itemId]!.quantity > 1) {
          _cart[itemId]!.quantity -= 1;
        } else {
          _cart.remove(itemId);
        }
      }
    });
  }

  void _removeCartItem(int itemId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _cart.remove(itemId);
    });
  }

  int get _cartTotalCount {
    return _cart.values.fold(0, (sum, entry) => sum + entry.quantity);
  }

  double get _cartSubtotal {
    return _cart.values.fold(0.0, (sum, entry) {
      return sum + (_getItemPrice(entry.item) * entry.quantity);
    });
  }

  double get _cartTotalTax {
    return _cart.values.fold(0.0, (sum, entry) {
      final price = _getItemPrice(entry.item);
      final taxPct = entry.item.taxPercent;
      final lineTax = (price * entry.quantity) * (taxPct / 100.0);
      return sum + lineTax;
    });
  }

  double get _cartGrandTotal {
    return _cartSubtotal + _cartTotalTax;
  }

  // Dietary Veg / Non-Veg / Egg badge
  Widget _buildDietaryBadge(String type, {double size = 12}) {
    Color borderColor;
    Color dotColor;
    bool isVegan = false;

    switch (type.toUpperCase()) {
      case 'VEG':
        borderColor = const Color(0xFF16A34A);
        dotColor = const Color(0xFF16A34A);
        break;
      case 'NON_VEG':
      case 'NON-VEG':
      case 'NONVEG':
        borderColor = const Color(0xFFDC2626);
        dotColor = const Color(0xFFDC2626);
        break;
      case 'EGG':
        borderColor = const Color(0xFFEAB308);
        dotColor = const Color(0xFFEAB308);
        break;
      case 'VEGAN':
        borderColor = const Color(0xFF059669);
        dotColor = const Color(0xFF059669);
        isVegan = true;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: isVegan
            ? Icon(Icons.eco, size: size * 0.7, color: dotColor)
            : Container(
                width: size * 0.45,
                height: size * 0.45,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  // Live Camera Barcode Scanner View
  void _openBarcodeScannerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BarcodeScannerSheet(
        allItems: _allItems,
        cart: _cart,
        getItemPrice: _getItemPrice,
        onItemScanned: (item) {
          _addToCart(item);
        },
        onIncreaseItem: (item) {
          _addToCart(item);
        },
        onDecreaseItem: (id) {
          _decreaseCartItem(id);
        },
        onRemoveItem: (id) {
          _removeCartItem(id);
        },
        onProceedToTender: () {
          Navigator.pop(ctx);
          _openCheckoutSheet();
        },
      ),
    );
  }

  // Tender & Checkout Sheet
  void _openCheckoutSheet() {
    if (_cart.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutModalSheet(
        cart: _cart,
        allItems: _allItems,
        subtotal: _cartSubtotal,
        tax: _cartTotalTax,
        total: _cartGrandTotal,
        schemes: _allSchemes,
        customers: _allCustomers,
        paymentMethods: _paymentMethods,
        salesCtrl: _salesCtrl,
        getItemPrice: _getItemPrice,
        onIncreaseItem: (item) => _addToCart(item),
        onDecreaseItem: (id) => _decreaseCartItem(id),
        onRemoveItem: (id) => _removeCartItem(id),
        onCheckoutComplete: (SaleOrder savedOrder) {
          Navigator.pop(ctx);
          setState(() {
            _cart.clear();
          });
          _loadPulseAndOrders();
          _showInvoiceSuccessDialog(savedOrder);
        },
      ),
    );
  }

  void _showInvoiceSuccessDialog(SaleOrder order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Text(
                'Sale Completed',
                style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice: ${order.saleNo}',
                  style: const TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Total Paid: ₹${order.netAmount.toStringAsFixed(2)} (${order.paymentMode})',
                  style: const TextStyle(color: Color(0xFF2563EB), fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Share digital invoice or print 80mm thermal receipt:',
                  style: TextStyle(color: textMuted, fontSize: 13)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('WhatsApp'),
                      onPressed: () {
                        _shareInvoiceOnWhatsApp(order);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textDark,
                        side: const BorderSide(color: borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print Bill'),
                      onPressed: () {
                        _printDesktopReceipt(order);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done / New Bill',
                  style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareInvoiceOnWhatsApp(SaleOrder order, {List<SaleItem>? fullItems}) async {
    try {
      final detailed = (fullItems != null && fullItems.isNotEmpty)
          ? order.copyWith(items: fullItems)
          : (order.items.isNotEmpty ? order : await _fetchFullOrder(order));

      final propCtrl = Provider.of<PropertyInfoController>(context, listen: false);
      final settingsCtrl = Provider.of<SystemSettingsController>(context, listen: false);
      PropertyInfo? prop = propCtrl.data;
      if (prop == null) {
        try {
          await propCtrl.load();
          prop = propCtrl.data;
        } catch (_) {}
      }

      final format = (settingsCtrl.settings?.billFormat.isNotEmpty == true)
          ? settingsCtrl.settings!.billFormat
          : (detailed.billFormat.isNotEmpty ? detailed.billFormat : 'THERMAL_80');
      final orderToPrint = detailed.copyWith(billFormat: format);

      final pdfBytes = await PosInvoicePrinter.buildSaleInvoicePdf(
        order: orderToPrint,
        property: prop,
        settings: settingsCtrl.settings,
      );

      // Direct native WhatsApp / app share with PDF attachment
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Bill-${order.saleNo}.pdf',
        subject: 'Tax Invoice ${order.saleNo}',
      );
    } catch (e) {
      debugPrint('Error generating desktop PDF for WhatsApp: $e');
    }
  }

  Future<void> _printDesktopReceipt(SaleOrder order, {List<SaleItem>? fullItems}) async {
    try {
      final detailed = (fullItems != null && fullItems.isNotEmpty)
          ? order.copyWith(items: fullItems)
          : (order.items.isNotEmpty ? order : await _fetchFullOrder(order));

      final propCtrl = Provider.of<PropertyInfoController>(context, listen: false);
      final settingsCtrl = Provider.of<SystemSettingsController>(context, listen: false);
      PropertyInfo? prop = propCtrl.data;
      if (prop == null) {
        try {
          await propCtrl.load();
          prop = propCtrl.data;
        } catch (_) {}
      }

      final format = (settingsCtrl.settings?.billFormat.isNotEmpty == true)
          ? settingsCtrl.settings!.billFormat
          : (detailed.billFormat.isNotEmpty ? detailed.billFormat : 'THERMAL_80');
      final orderToPrint = detailed.copyWith(billFormat: format);

      await PosInvoicePrinter.printSaleInvoice(
        order: orderToPrint,
        property: prop,
        settings: settingsCtrl.settings,
      );
    } catch (e) {
      debugPrint('Error printing invoice with desktop engine: $e');
    }
  }

  // Biller Tools Modals
  void _openModifyBillModal(SaleOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileBillModifySheet(
        initialOrder: order,
        onModified: () {
          _loadPulseAndOrders();
        },
      ),
    );
  }

  void _openCustomerLedgerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MobileCustomerLedgerSheet(),
    );
  }

  void _openCashLedgerModal({int tab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileCashLedgerSheet(initialTab: tab),
    );
  }

  void _openExpensesModal() {
    _openCashLedgerModal(tab: 1);
  }

  void _openItemMasterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileItemMasterSheet(
        items: _allItems,
        onCatalogUpdated: () {
          _loadCatalogAndMetadata();
        },
      ),
    );
  }

  void _openStockBalanceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MobileStockBalanceSheet(),
    );
  }

  // Opens Bill Details Dialog with real fetched item rows
  void _openBillDetailsDialog(SaleOrder order) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return _BillDetailsDialog(
          initialOrder: order,
          onWhatsAppShare: (ord, items) => _shareInvoiceOnWhatsApp(ord, fullItems: items),
          onPrint80mm: (ord, items) => _printDesktopReceipt(ord, fullItems: items),
          onModify: (ord) => _openModifyBillModal(ord),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceLight,
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: [
            _buildPosBillingView(),
            _buildOrdersHistoryView(),
            _buildSubscriptionsView(),
            _buildStorePulseAnalyticsView(),
            _buildStoreProfileView(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // 1. POS Billing View
  Widget _buildPosBillingView() {
    final settingsCtrl = context.watch<SystemSettingsController>();
    final allowNegative = settingsCtrl.settings?.allowNegativeStock ?? false;

    return Stack(
      children: [
        Column(
          children: [
            _buildTopAppBar(title: 'Fast Mobile POS'),
            // Search Bar + Live Barcode Scanner Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: textDark, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search items by name, barcode or code...',
                        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: textMuted),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: textMuted, size: 18),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Scan to Cart Button
                  Material(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openBarcodeScannerModal,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Category Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cat = _categories[idx];
                  final isSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : textDark,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : borderSubtle,
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                        _filterItems();
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Products Grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                      ),
                    )
                  : _filteredItems.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, color: textMuted, size: 54),
                              SizedBox(height: 12),
                              Text('No items found in catalog',
                                  style: TextStyle(color: textMuted, fontSize: 14)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.88,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, idx) {
                            final item = _filteredItems[idx];
                            final price = _getItemPrice(item);
                            final inCart = _cart[item.id]?.quantity ?? 0;
                            final bool isStockTracked = item.stockable || item.openingBalance != 0;
                            final double availableStock = item.openingBalance - inCart;
                            final bool isOutOfStock = isStockTracked && availableStock <= 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: inCart > 0
                                      ? const Color(0xFF2563EB)
                                      : (isOutOfStock ? const Color(0xFFFECACA) : borderSubtle),
                                  width: inCart > 0 ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Diet badge + Stock badge + Tax
                                  Row(
                                    children: [
                                      if (item.foodType.isNotEmpty && item.foodType != 'OTHER') ...[
                                        _buildDietaryBadge(item.foodType, size: 14),
                                        const SizedBox(width: 4),
                                      ],
                                      // Stock Status Badge
                                      if (isStockTracked)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isOutOfStock
                                                ? const Color(0xFFFEF2F2)
                                                : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isOutOfStock
                                                  ? const Color(0xFFFCA5A5)
                                                  : const Color(0xFFA7F3D0),
                                            ),
                                          ),
                                          child: Text(
                                            isOutOfStock
                                                ? 'Out of Stock'
                                                : 'Stock: ${availableStock.toInt()}',
                                            style: TextStyle(
                                              color: isOutOfStock
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF065F46),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.unit.isNotEmpty ? item.unit : 'Nos',
                                            style: const TextStyle(
                                                color: textMuted, fontSize: 9.5, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      const Spacer(),
                                      if (item.taxPercent > 0)
                                        Text(
                                          '${item.taxPercent.toStringAsFixed(0)}% Tax',
                                          style: const TextStyle(
                                              color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: textDark,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (item.brand.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.brand,
                                            maxLines: 1,
                                            style: const TextStyle(color: textMuted, fontSize: 10.5),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '₹${price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Color(0xFF059669),
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (item.mrp > price)
                                            Text(
                                              '₹${item.mrp.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: textMuted,
                                                fontSize: 10,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (inCart > 0)
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _decreaseCartItem(item.id),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.remove, color: Color(0xFFDC2626), size: 16),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text(
                                                '$inCart',
                                                style: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: (isOutOfStock && !allowNegative)
                                                  ? () {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Cannot add more: Out of stock'),
                                                          backgroundColor: Colors.redAccent,
                                                        ),
                                                      );
                                                    }
                                                  : () => _addToCart(item),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: (isOutOfStock && !allowNegative)
                                                      ? Colors.grey.shade400
                                                      : const Color(0xFF2563EB),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.add, color: Colors.white, size: 16),
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: (isOutOfStock && !allowNegative)
                                                ? Colors.grey.shade300
                                                : const Color(0xFF2563EB),
                                            foregroundColor: (isOutOfStock && !allowNegative)
                                                ? Colors.grey.shade600
                                                : Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: const Size(54, 28),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            elevation: 0,
                                          ),
                                          onPressed: (isOutOfStock && !allowNegative)
                                              ? () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Cannot add "${item.itemName}": Out of stock'),
                                                      backgroundColor: Colors.redAccent,
                                                      duration: const Duration(seconds: 1),
                                                    ),
                                                  );
                                                }
                                              : () => _addToCart(item),
                                          child: Text(
                                            (isOutOfStock && !allowNegative) ? 'Out' : 'Add',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
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
        ),

        // Floating Cart Bar Pill
        if (_cart.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: _openCheckoutSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_cartTotalCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total Bill',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text(
                          '₹${_cartGrandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Tender & Pay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Reusable Date Filter Chips Row: Today, Week, Month, Custom Range
  Widget _buildDateFilterChips({
    required String selectedFilter,
    required DateTimeRange? customRange,
    required Function(String filter, DateTimeRange? range) onFilterChanged,
  }) {
    final filters = [
      {'key': 'TODAY', 'label': 'Today'},
      {'key': 'WEEK', 'label': 'This Week'},
      {'key': 'MONTH', 'label': 'This Month'},
      {
        'key': 'CUSTOM',
        'label': customRange != null
            ? '${DateFormat('dd MMM').format(customRange.start)} - ${DateFormat('dd MMM').format(customRange.end)}'
            : 'Custom Range',
      },
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final f = filters[idx];
          final isSel = selectedFilter == f['key'];
          return ChoiceChip(
            label: Text(
              f['label']!,
              style: TextStyle(
                color: isSel ? Colors.white : textDark,
                fontSize: 12,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            selected: isSel,
            selectedColor: const Color(0xFF2563EB),
            backgroundColor: Colors.white,
            side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
            onSelected: (val) async {
              if (f['key'] == 'CUSTOM') {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: customRange ??
                      DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 7)),
                        end: DateTime.now(),
                      ),
                );
                if (picked != null) {
                  onFilterChanged('CUSTOM', picked);
                }
              } else {
                onFilterChanged(f['key']!, null);
              }
            },
          );
        },
      ),
    );
  }

  // 2. Orders & Reprints History View
  Widget _buildOrdersHistoryView() {
    return Column(
      children: [
        _buildTopAppBar(title: 'Orders & Reprints'),
        const SizedBox(height: 8),
        // Date filter chips: Day/Today by default
        _buildDateFilterChips(
          selectedFilter: _orderDateFilter,
          customRange: _orderCustomRange,
          onFilterChanged: (filter, range) {
            setState(() {
              _orderDateFilter = filter;
              _orderCustomRange = range;
              _filterOrders();
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _reprintSearchCtrl,
            style: const TextStyle(color: textDark, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by Bill No, Name, or Phone...',
              hintStyle: const TextStyle(color: textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
              suffixIcon: _reprintSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: textMuted, size: 16),
                      onPressed: () => _reprintSearchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _filteredOrders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, color: textMuted, size: 54),
                      SizedBox(height: 12),
                      Text('No matching bills found', style: TextStyle(color: textMuted, fontSize: 14)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPulseAndOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final order = _filteredOrders[idx];
                      final displayQty = order.totalQty > 0
                          ? order.totalQty.toInt()
                          : (order.items.isNotEmpty ? order.items.length : 1);

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openBillDetailsDialog(order),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderSubtle),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        order.saleNo,
                                        style: const TextStyle(
                                          color: textDark,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF2563EB)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Text(
                                      order.paymentMode.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF065F46),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${order.customerName ?? 'Walk-in'} • ${DateFormat('dd MMM hh:mm a').format(order.saleDate)}',
                                style: const TextStyle(color: textMuted, fontSize: 12),
                              ),
                              const Divider(color: borderSubtle, height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$displayQty items (Tap for details)',
                                    style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '₹${order.netAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF16A34A),
                                      side: const BorderSide(color: Color(0xFFBBF7D0)),
                                      backgroundColor: const Color(0xFFF0FDF4),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(80, 30),
                                    ),
                                    icon: const Icon(Icons.share, size: 14),
                                    label: const Text('WhatsApp',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _shareInvoiceOnWhatsApp(order),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textDark,
                                      side: const BorderSide(color: borderSubtle),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(80, 30),
                                    ),
                                    icon: const Icon(Icons.print_outlined, size: 14),
                                    label: const Text('Print Bill', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _printDesktopReceipt(order),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2563EB),
                                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(76, 30),
                                    ),
                                    icon: const Icon(Icons.edit_outlined, size: 14),
                                    label: const Text('Modify',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _openModifyBillModal(order),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // 3. Subscriptions & Renewal View
  Widget _buildSubscriptionsView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.autorenew_rounded, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 8),
                  Text('Subscriptions',
                      style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _openNewSubscriptionModal,
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _subsSearchCtrl,
            style: const TextStyle(color: textDark, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search customer name, phone or product...',
              hintStyle: const TextStyle(color: textMuted, fontSize: 12.5),
              prefixIcon: const Icon(Icons.search, color: textMuted, size: 18),
              suffixIcon: _subsSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: textMuted, size: 16),
                      onPressed: () => _subsSearchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderSubtle)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB))),
            ),
          ),
        ),
        // Filter Chips
        SizedBox(
          height: 36,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _buildSubsChip('ALL', 'All Plans'),
              const SizedBox(width: 8),
              _buildSubsChip('ACTIVE', 'Active'),
              const SizedBox(width: 8),
              _buildSubsChip('UPCOMING_RENEWAL', 'Expiring Soon'),
              const SizedBox(width: 8),
              _buildSubsChip('EXPIRED', 'Expired'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // List
        Expanded(
          child: _loadingSubs
              ? const Center(child: CircularProgressIndicator())
              : _filteredSubscriptions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.autorenew_rounded, size: 52, color: textMuted),
                          const SizedBox(height: 10),
                          const Text('No subscriptions found', style: TextStyle(color: textMuted, fontSize: 14)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create Subscription'),
                            onPressed: _openNewSubscriptionModal,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSubscriptions,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredSubscriptions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final sub = _filteredSubscriptions[idx];
                          return _buildSubscriptionCard(sub);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSubsChip(String key, String label) {
    final isSel = _subsStatusFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSel ? Colors.white : textDark,
          fontSize: 11.5,
          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSel,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
      onSelected: (val) {
        if (val) {
          setState(() {
            _subsStatusFilter = key;
            _filterSubscriptions();
          });
        }
      },
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> sub) {
    final custName = (sub['customer_name'] ?? 'Customer').toString();
    final custPhone = (sub['customer_phone'] ?? '').toString();
    final itemName = (sub['item_name'] ?? 'Plan Item').toString();
    final dailyQty = (sub['daily_allowed_qty'] ?? 1).toString();
    final startDate = (sub['start_date'] ?? '').toString();
    final endDate = (sub['end_date'] ?? '').toString();
    final status = (sub['status'] ?? 'ACTIVE').toString().toUpperCase();
    final isActive = sub['active_subscription'] == true || status == 'ACTIVE';

    final origAmount = double.tryParse((sub['advance_original_amount'] ?? sub['total_payment_amount'] ?? 0).toString()) ?? 0.0;
    final consumedAmount = double.tryParse((sub['advance_consumed_amount'] ?? 0).toString()) ?? 0.0;
    final remainingAmount = sub['advance_remaining_amount'] != null
        ? (double.tryParse(sub['advance_remaining_amount'].toString()) ?? (origAmount - consumedAmount))
        : (origAmount - consumedAmount);

    final origQty = double.tryParse((sub['advance_original_qty'] ?? 0).toString()) ?? 0.0;
    final consumedQty = double.tryParse((sub['advance_consumed_qty'] ?? 0).toString()) ?? 0.0;
    final remainingQty = sub['advance_remaining_qty'] != null
        ? (double.tryParse(sub['advance_remaining_qty'].toString()) ?? (origQty - consumedQty))
        : (origQty - consumedQty);

    final safeOrigQty = origQty > 0 ? origQty : (consumedQty + (remainingQty > 0 ? remainingQty : 0));
    final double qtyRatio = safeOrigQty > 0 ? (consumedQty / safeOrigQty).clamp(0.0, 1.0) : 0.0;
    final double amtRatio = origAmount > 0 ? (consumedAmount / origAmount).clamp(0.0, 1.0) : 0.0;
    final double progress = qtyRatio > 0 ? qtyRatio : amtRatio;
    final int percent = (progress * 100).round();

    Color badgeBg;
    Color badgeText;
    String statusLabel = status;
    if (isActive) {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF065F46);
      statusLabel = 'ACTIVE';
    } else if (status == 'EXPIRED') {
      badgeBg = const Color(0xFFFEF2F2);
      badgeText = const Color(0xFFDC2626);
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  custName,
                  style: const TextStyle(color: textDark, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: badgeText, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (custPhone.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(custPhone, style: const TextStyle(color: textMuted, fontSize: 12)),
          ],
          const Divider(height: 18, color: borderSubtle),
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$itemName • Daily $dailyQty Nos',
                  style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '₹${origAmount.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF059669), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Advance & Consumed Qty Progress Graph Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Advance Left', style: TextStyle(color: textMuted, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${remainingAmount.clamp(0, double.infinity).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Paid: ₹${origAmount.toStringAsFixed(0)} • Used: ₹${consumedAmount.toStringAsFixed(0)}',
                          style: const TextStyle(color: textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Quantity Left', style: TextStyle(color: textMuted, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '${(safeOrigQty - consumedQty).clamp(0, double.infinity).toStringAsFixed(0)} Nos',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Total: ${safeOrigQty.toInt()} • Consumed: ${consumedQty.toInt()}',
                          style: const TextStyle(color: textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Consumption Progress', style: TextStyle(color: textDark, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: percent >= 90 ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$percent% Consumed',
                        style: TextStyle(
                          color: percent >= 90 ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percent >= 100
                          ? const Color(0xFFDC2626)
                          : percent >= 75
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Period: $startDate to $endDate',
                style: const TextStyle(color: textMuted, fontSize: 11),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 13),
                    label: const Text('Share PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _shareSubscriptionPdf(sub),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.refresh, size: 13),
                    label: const Text('Renew', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _openRenewSubscriptionModal(sub),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareSubscriptionPdf(Map<String, dynamic> sub) async {
    try {
      final custName = (sub['customer_name'] ?? 'Customer').toString();
      final custPhone = (sub['customer_phone'] ?? '').toString();
      final itemName = (sub['item_name'] ?? 'Plan Item').toString();
      final dailyQty = (sub['daily_allowed_qty'] ?? 1).toString();
      final startDate = (sub['start_date'] ?? '').toString();
      final endDate = (sub['end_date'] ?? '').toString();
      final status = (sub['status'] ?? 'ACTIVE').toString().toUpperCase();

      final origAmount = double.tryParse((sub['advance_original_amount'] ?? sub['total_payment_amount'] ?? 0).toString()) ?? 0.0;
      final consumedAmount = double.tryParse((sub['advance_consumed_amount'] ?? 0).toString()) ?? 0.0;
      final remainingAmount = sub['advance_remaining_amount'] != null
          ? (double.tryParse(sub['advance_remaining_amount'].toString()) ?? (origAmount - consumedAmount))
          : (origAmount - consumedAmount);

      final origQty = double.tryParse((sub['advance_original_qty'] ?? 0).toString()) ?? 0.0;
      final consumedQty = double.tryParse((sub['advance_consumed_qty'] ?? 0).toString()) ?? 0.0;
      final remainingQty = sub['advance_remaining_qty'] != null
          ? (double.tryParse(sub['advance_remaining_qty'].toString()) ?? (origQty - consumedQty))
          : (origQty - consumedQty);

      final safeOrigQty = origQty > 0 ? origQty : (consumedQty + (remainingQty > 0 ? remainingQty : 0));
      final double qtyRatio = safeOrigQty > 0 ? (consumedQty / safeOrigQty).clamp(0.0, 1.0) : 0.0;
      final double amtRatio = origAmount > 0 ? (consumedAmount / origAmount).clamp(0.0, 1.0) : 0.0;
      final double progress = qtyRatio > 0 ? qtyRatio : amtRatio;
      final int percent = (progress * 100).round();

      final propCtrl = Provider.of<PropertyInfoController>(context, listen: false);
      PropertyInfo? prop = propCtrl.data;
      if (prop == null) {
        try {
          await propCtrl.load();
          prop = propCtrl.data;
        } catch (_) {}
      }

      final propName = prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'Store Subscription Service';
      final propAddress = prop?.address.isNotEmpty == true ? prop!.address : '';
      final propMobile = prop?.mobile.isNotEmpty == true ? prop!.mobile : '';

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context pContext) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          propName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        if (propAddress.isNotEmpty)
                          pw.Text(propAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        if (propMobile.isNotEmpty)
                          pw.Text('Contact: $propMobile', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: status == 'ACTIVE' ? PdfColors.green50 : PdfColors.grey100,
                        border: pw.Border.all(
                          color: status == 'ACTIVE' ? PdfColors.green700 : PdfColors.grey400,
                        ),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        status,
                        style: pw.TextStyle(
                          color: status == 'ACTIVE' ? PdfColors.green800 : PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),

                pw.Center(
                  child: pw.Text(
                    'SUBSCRIPTION & ADVANCE STATEMENT',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                ),
                pw.SizedBox(height: 14),

                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Customer: $custName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          if (custPhone.isNotEmpty)
                            pw.Text('Phone: $custPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Item: $itemName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text('Daily Quota: $dailyQty Nos/day', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('Period: $startDate to $endDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                pw.Text('Balance & Consumption Overview', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Planned', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Consumed (Used)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Remaining (Balance)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Advance Payment', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${origAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${consumedAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${remainingAmount.clamp(0, double.infinity).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Quantity (Units)', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${safeOrigQty.toInt()} Nos', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${consumedQty.toInt()} Nos', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${(safeOrigQty - consumedQty).clamp(0, double.infinity).toInt()} Nos', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),

                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Overall Consumption Progress:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('$percent% Consumed  -  ${100 - percent}% Balance Left', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Generated: ${DateFormat("dd-MMM-yyyy hh:mm a").format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text('Thank you for choosing $propName!', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final cleanCust = custName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Subscription_Statement_$cleanCust.pdf',
        subject: 'Subscription Statement - $custName',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share subscription PDF: $e')),
        );
      }
    }
  }


  void _openRenewSubscriptionModal(Map<String, dynamic> sub) {
    final custName = (sub['customer_name'] ?? '').toString();
    final custPhone = (sub['customer_phone'] ?? '').toString();
    final itemId = int.tryParse((sub['item_id'] ?? 0).toString()) ?? 0;
    final itemName = (sub['item_name'] ?? 'Product').toString();
    final prevDailyQty = double.tryParse((sub['daily_allowed_qty'] ?? 1).toString()) ?? 1.0;
    final prevEndDateStr = (sub['end_date'] ?? '').toString();

    DateTime nextStart = DateTime.now();
    if (prevEndDateStr.isNotEmpty) {
      final prevEnd = DateTime.tryParse(prevEndDateStr);
      if (prevEnd != null) {
        nextStart = prevEnd.add(const Duration(days: 1));
      }
    }
    if (nextStart.isBefore(DateTime.now())) {
      nextStart = DateTime.now();
    }

    int durationDays = 30;
    double dailyQty = prevDailyQty;
    String paymentMode = 'CASH';

    // Find item price
    Item? matchedItem;
    for (final it in _allItems) {
      if (it.id == itemId || it.itemName.toLowerCase() == itemName.toLowerCase()) {
        matchedItem = it;
        break;
      }
    }
    final itemRate = matchedItem != null ? _getItemPrice(matchedItem) : 60.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final totalAmount = itemRate * dailyQty * durationDays;
          final nextEnd = nextStart.add(Duration(days: durationDays - 1));

          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.autorenew_rounded, color: Color(0xFF2563EB), size: 22),
                          SizedBox(width: 8),
                          Text('Renew Subscription',
                              style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: textMuted),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(color: borderSubtle),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
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
                        Text('$itemName • ₹${itemRate.toStringAsFixed(2)} / unit', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Plan Duration', style: TextStyle(color: textDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [15, 30, 60, 90].map((days) {
                        final isSel = durationDays == days;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$days Days', style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 12)),
                            selected: isSel,
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
                            onSelected: (val) {
                              if (val) setModalState(() => durationDays = days);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daily Quantity:', style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (dailyQty > 1) {
                                setModalState(() => dailyQty -= 1);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.remove, size: 16),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(dailyQty.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                          GestureDetector(
                            onTap: () {
                              setModalState(() => dailyQty += 1);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.add, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Validity Range:', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12)),
                            Text(
                              '${DateFormat('dd MMM yyyy').format(nextStart)} to ${DateFormat('dd MMM yyyy').format(nextEnd)}',
                              style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Renewal Total:', style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('₹${totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF059669), fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Payment Mode', style: TextStyle(color: textDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['CASH', 'UPI', 'CARD', 'CREDIT'].map((mode) {
                      final isSel = paymentMode == mode;
                      return ChoiceChip(
                        label: Text(mode, style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 11.5)),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
                        onSelected: (val) {
                          if (val) setModalState(() => paymentMode = mode);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        try {
                          final payload = {
                            'customer_name': custName,
                            'customer_phone': custPhone,
                            'item_id': itemId > 0 ? itemId : (matchedItem?.id ?? 1),
                            'start_date': DateFormat('yyyy-MM-dd').format(nextStart),
                            'end_date': DateFormat('yyyy-MM-dd').format(nextEnd),
                            'daily_allowed_qty': dailyQty,
                            'total_payment_amount': totalAmount,
                            'payment_mode': paymentMode,
                          };
                          await _salesCtrl.createSubscription(payload);
                          Navigator.pop(modalCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Subscription successfully renewed!'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                          _loadSubscriptions();
                        } catch (e) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            SnackBar(content: Text('Error renewing plan: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                      child: Text('Confirm Renewal (₹${totalAmount.toStringAsFixed(2)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  void _openNewSubscriptionModal() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final bonusQtyCtrl = TextEditingController(text: '0');
    Item? selectedItem = _allItems.isNotEmpty ? _allItems.first : null;
    int durationDays = 30;
    double dailyQty = 1.0;
    DateTime startDate = DateTime.now();
    String paymentMode = 'CASH';
    String deliveryType = 'PICKUP'; // 'PICKUP' or 'HOME'
    List<SaleCustomer> subCustomerSuggestions = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final itemRate = selectedItem != null ? _getItemPrice(selectedItem!) : 0.0;
          final bonusQty = double.tryParse(bonusQtyCtrl.text.trim()) ?? 0.0;
          final payableDays = (bonusQty > 0) ? (durationDays - 1).clamp(0, durationDays) : durationDays;
          final baseAmount = itemRate * dailyQty * payableDays;

          final taxPercent = selectedItem?.taxPercent ?? 0.0;
          final isInclusive = selectedItem != null &&
              (selectedItem!.isTaxInclusive || selectedItem!.taxType.trim().toUpperCase() == 'GST_INCLUSIVE');

          final double taxableAmount;
          final double taxAmount;
          if (isInclusive && taxPercent > 0) {
            taxableAmount = baseAmount / (1 + (taxPercent / 100));
            taxAmount = baseAmount - taxableAmount;
          } else {
            taxableAmount = baseAmount;
            taxAmount = baseAmount * (taxPercent / 100);
          }
          final totalAmount = isInclusive ? baseAmount : (taxableAmount + taxAmount);
          final endDate = startDate.add(Duration(days: durationDays - 1));

          void searchSubCustomer(String query) {
            final q = query.trim().toLowerCase();
            if (q.isEmpty) {
              setModalState(() => subCustomerSuggestions = []);
              return;
            }
            setModalState(() {
              subCustomerSuggestions = _allCustomers.where((c) {
                return c.customerPhone.toLowerCase().contains(q) ||
                    c.customerName.toLowerCase().contains(q);
              }).take(4).toList();
            });
          }

          void pickProductModal() {
            showModalBottomSheet(
              context: modalCtx,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (pickerCtx) {
                String filter = '';
                return StatefulBuilder(
                  builder: (ctx, setPickerState) {
                    final filtered = _allItems.where((it) {
                      if (filter.isEmpty) return true;
                      final f = filter.toLowerCase();
                      return it.itemName.toLowerCase().contains(f) ||
                          it.barcode.toLowerCase().contains(f) ||
                          it.itemCode.toLowerCase().contains(f);
                    }).toList();

                    return Container(
                      height: MediaQuery.of(ctx).size.height * 0.72,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Select Subscription Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search product by name or barcode...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            onChanged: (val) => setPickerState(() => filter = val),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: borderSubtle),
                              itemBuilder: (_, i) {
                                final item = filtered[i];
                                final price = _getItemPrice(item);
                                final isSel = selectedItem?.id == item.id;
                                return ListTile(
                                  dense: true,
                                  selected: isSel,
                                  selectedTileColor: const Color(0xFFEFF6FF),
                                  title: Text(item.itemName, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
                                  subtitle: Text('Rate: ₹${price.toStringAsFixed(2)} • Code: ${item.itemCode}', style: const TextStyle(fontSize: 11)),
                                  trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 18) : null,
                                  onTap: () {
                                    setModalState(() => selectedItem = item);
                                    Navigator.pop(ctx);
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

          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Create New Subscription',
                          style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: textMuted),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(color: borderSubtle),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(fontSize: 13),
                    onChanged: searchSubCustomer,
                    decoration: const InputDecoration(
                      labelText: 'Customer Phone (Search or Enter)',
                      hintText: 'Enter mobile number...',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(fontSize: 13),
                    onChanged: searchSubCustomer,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name (Search or Enter)',
                      hintText: 'Enter customer name...',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (subCustomerSuggestions.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: subCustomerSuggestions.map((c) {
                          return ListTile(
                            dense: true,
                            leading: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFEFF6FF),
                              child: Icon(Icons.person, size: 16, color: Color(0xFF2563EB)),
                            ),
                            title: Text(c.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text(c.customerPhone, style: const TextStyle(fontSize: 11, color: textMuted)),
                            trailing: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF2563EB)),
                            onTap: () {
                              setModalState(() {
                                phoneCtrl.text = c.customerPhone;
                                nameCtrl.text = c.customerName;
                                subCustomerSuggestions = [];
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Searchable Product Picker Trigger
                  InkWell(
                    onTap: pickProductModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFF8FAFC),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 20, color: Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Subscription Product (Tap to Search)', style: TextStyle(color: textMuted, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  selectedItem != null ? '${selectedItem!.itemName} (₹${itemRate.toStringAsFixed(2)})' : 'Tap to select product...',
                                  style: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Daily Qty:', style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (dailyQty > 1) setModalState(() => dailyQty -= 1);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.remove, size: 16),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(dailyQty.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                                GestureDetector(
                                  onTap: () => setModalState(() => dailyQty += 1),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Bonus Qty input
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: bonusQtyCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Bonus Qty',
                            hintText: '0',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Delivery Type (Pickup vs Home)
                  Row(
                    children: [
                      const Text('Delivery:', style: TextStyle(color: textDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('Pickup', style: TextStyle(fontSize: 11.5)),
                        selected: deliveryType == 'PICKUP',
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(color: deliveryType == 'PICKUP' ? Colors.white : textDark),
                        onSelected: (val) {
                          if (val) setModalState(() => deliveryType = 'PICKUP');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Home Delivery', style: TextStyle(fontSize: 11.5)),
                        selected: deliveryType == 'HOME',
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(color: deliveryType == 'HOME' ? Colors.white : textDark),
                        onSelected: (val) {
                          if (val) setModalState(() => deliveryType = 'HOME');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Duration', style: TextStyle(color: textDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [15, 30, 60, 90].map((days) {
                        final isSel = durationDays == days;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$days Days', style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 12)),
                            selected: isSel,
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
                            onSelected: (val) {
                              if (val) setModalState(() => durationDays = days);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Payment Mode
                  const Text('Payment Mode', style: TextStyle(color: textDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['CASH', 'UPI', 'CARD', 'CREDIT'].map((mode) {
                      final isSel = paymentMode == mode;
                      return ChoiceChip(
                        label: Text(mode, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
                        labelStyle: TextStyle(color: isSel ? Colors.white : textDark),
                        onSelected: (val) {
                          if (val) setModalState(() => paymentMode = mode);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Validity Range:', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12)),
                            Text(
                              '${DateFormat('dd MMM yyyy').format(startDate)} to ${DateFormat('dd MMM yyyy').format(endDate)} ($durationDays Days)',
                              style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (bonusQty > 0 || taxPercent > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Taxable: ₹${taxableAmount.toStringAsFixed(2)}${taxPercent > 0 ? ' | GST (${taxPercent.toStringAsFixed(2)}%): ₹${taxAmount.toStringAsFixed(2)}' : ''}',
                                style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                              ),
                              if (bonusQty > 0)
                                Text('Bonus: ${bonusQty.toStringAsFixed(0)} Free', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Plan Price:', style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('₹${totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF059669), fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final phone = phoneCtrl.text.trim();
                        final name = nameCtrl.text.trim();
                        final bonusQty = double.tryParse(bonusQtyCtrl.text.trim()) ?? 0.0;
                        if (phone.isEmpty || name.isEmpty || selectedItem == null) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            const SnackBar(content: Text('Phone, name, and product are required')),
                          );
                          return;
                        }
                        try {
                          final payload = {
                            'customer_name': name,
                            'customer_phone': phone,
                            'item_id': selectedItem!.id,
                            'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                            'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                            'daily_allowed_qty': dailyQty,
                            'bonus_qty': bonusQty,
                            'delivery_type': deliveryType,
                            'total_payment_amount': totalAmount,
                            'payment_mode': paymentMode,
                            if (bonusQty > 0)
                              'selected_schemes': [
                                {
                                  'scheme_type': 'BONUS_QTY',
                                  'scheme_name': 'Bonus Quantity',
                                  'scheme_value': bonusQty,
                                  'bonus_qty': bonusQty,
                                  'discount_amount': 0,
                                  'notes': 'Bonus Qty on Subscription'
                                }
                              ],
                          };
                          await _salesCtrl.createSubscription(payload);
                          Navigator.pop(modalCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Subscription plan created successfully!'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                          _loadSubscriptions();
                        } catch (e) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            SnackBar(content: Text('Error creating plan: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                      child: Text('Create Plan (₹${totalAmount.toStringAsFixed(2)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  // 4. Store Pulse Analytics View
  Widget _buildStorePulseAnalyticsView() {
    final avgBasket = _analyticsBillsCount > 0 ? (_analyticsRevenue / _analyticsBillsCount) : 0.0;
    final String periodLabel = _analyticsDateFilter == 'TODAY'
        ? "Today's"
        : (_analyticsDateFilter == 'WEEK'
            ? "This Week's"
            : (_analyticsDateFilter == 'MONTH' ? "This Month's" : 'Filtered'));

    return RefreshIndicator(
      onRefresh: _loadPulseAndOrders,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopAppBar(title: 'Store Pulse Analytics'),
            const SizedBox(height: 8),
            // Date Filter Chips (Default Day/Today)
            _buildDateFilterChips(
              selectedFilter: _analyticsDateFilter,
              customRange: _analyticsCustomRange,
              onFilterChanged: (filter, range) {
                setState(() {
                  _analyticsDateFilter = filter;
                  _analyticsCustomRange = range;
                  _recalculateAnalytics();
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Highlights
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: "$periodLabel Revenue",
                          value: '₹${_analyticsRevenue.toStringAsFixed(2)}',
                          icon: Icons.payments_outlined,
                          accentColor: const Color(0xFF059669),
                          badgeColor: const Color(0xFFECFDF5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Invoices',
                          value: '$_analyticsBillsCount',
                          icon: Icons.receipt_outlined,
                          accentColor: const Color(0xFF2563EB),
                          badgeColor: const Color(0xFFEFF6FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Cash Collected',
                          value: '₹${_analyticsCash.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet_outlined,
                          accentColor: const Color(0xFFD97706),
                          badgeColor: const Color(0xFFFFFBEB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Online / UPI',
                          value: '₹${_analyticsDigital.toStringAsFixed(2)}',
                          icon: Icons.qr_code_scanner_outlined,
                          accentColor: const Color(0xFF7C3AED),
                          badgeColor: const Color(0xFFF5F3FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Payment Collected',
                          value: '₹${(_analyticsCash + _analyticsDigital).toStringAsFixed(2)}',
                          icon: Icons.price_check_rounded,
                          accentColor: const Color(0xFF059669),
                          badgeColor: const Color(0xFFECFDF5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: '$periodLabel Debited (-)',
                          value: '₹${_analyticsDebitedOut.toStringAsFixed(2)}',
                          icon: Icons.outbox_rounded,
                          accentColor: const Color(0xFFDC2626),
                          badgeColor: const Color(0xFFFEF2F2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Credit & Outstanding Section (Customer & Supplier)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_outlined, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Text(
                              'Credit & Outstandings Overview',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Customer Credit', style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w600)),
                                    const Text('Receivable Due', style: TextStyle(color: textMuted, fontSize: 10)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${_customerCreditOutstanding.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Color(0xFFB45309), fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    if (_analyticsCreditSales > 0) ...[
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Period Due: ₹${_analyticsCreditSales.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Color(0xFFB45309), fontSize: 9.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Supplier Payable', style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.w600)),
                                    const Text('Retailer Need to Pay', style: TextStyle(color: textMuted, fontSize: 10)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${_supplierPayableOutstanding.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Average Basket Value
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                            const Text(
                              'Average Basket Value',
                              style: TextStyle(color: textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${avgBasket.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Inventory Stock Health Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF2563EB)),
                                SizedBox(width: 8),
                                Text(
                                  'Inventory Stock Health',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: _openStockBalanceModal,
                              child: const Row(
                                children: [
                                  Text('View Details', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2563EB), size: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _openStockBalanceModal,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderSubtle),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 16),
                                    SizedBox(width: 4),
                                    Text('Healthy Stock', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Text('|', style: TextStyle(color: borderSubtle)),
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 16),
                                    SizedBox(width: 4),
                                    Text('Need Reorder', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Text('|', style: TextStyle(color: borderSubtle)),
                                Row(
                                  children: [
                                    Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 16),
                                    SizedBox(width: 4),
                                    Text('Out of Stock', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Top Selling Items
                  const Text(
                    'Top Selling Products',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_topItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: const Center(
                        child: Text('Loading sales trends...',
                            style: TextStyle(color: textMuted)),
                      ),
                    )
                  else
                    ..._topItems.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['name'].toString(),
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${item['qty']} sold',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: textMuted, fontSize: 12)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Store Profile & Cashier Logout
  Widget _buildStoreProfileView() {
    final property = context.watch<PropertyInfoController>().data;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopAppBar(title: 'Store Profile & Settings'),
          const SizedBox(height: 16),
          // Outlet Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  property?.propertyName ?? AppBrand.coreBrand,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  property?.address.isNotEmpty == true
                      ? property!.address
                      : 'Connected Store Terminal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
                if (property?.gstNo.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GSTIN: ${property!.gstNo}',
                      style: const TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Server status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderSubtle),
            ),
            child: const Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Color(0xFF10B981), size: 12),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connected to Server',
                    style: TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Frequently Used Biller Tools Hub
          const Text(
            'Biller Tools & Ledgers',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildHubTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Customer Ledger & Credit',
            subtitle: 'Credit balance, customer statements, repayments & advances',
            badge: 'Ledger & Repayment',
            color: const Color(0xFF2563EB),
            bg: const Color(0xFFEFF6FF),
            onTap: _openCustomerLedgerModal,
          ),
          const SizedBox(height: 10),
          _buildHubTile(
            icon: Icons.payments_outlined,
            title: 'Cash & Bank Ledger',
            subtitle: 'Cash book, bank & UPI receipts, money in/out & closing balance',
            badge: 'Cash Book',
            color: const Color(0xFF059669),
            bg: const Color(0xFFECFDF5),
            onTap: _openCashLedgerModal,
          ),
          const SizedBox(height: 10),
          _buildHubTile(
            icon: Icons.receipt_long_outlined,
            title: 'Store Expenses & Outflow',
            subtitle: 'Record daily petty cash, diesel, salary, rent, tea, freight & GST expenses',
            badge: 'Expenses',
            color: const Color(0xFFDC2626),
            bg: const Color(0xFFFEF2F2),
            onTap: _openExpensesModal,
          ),
          const SizedBox(height: 10),
          _buildHubTile(
            icon: Icons.inventory_2_outlined,
            title: 'Item Master & Quick Pricing',
            subtitle: 'Live stock, barcode scanner lookup, edit selling rate & add product',
            badge: 'Catalog & Stock',
            color: const Color(0xFF7C3AED),
            bg: const Color(0xFFF5F3FF),
            onTap: _openItemMasterModal,
          ),
          const SizedBox(height: 10),
          _buildHubTile(
            icon: Icons.inventory_2_rounded,
            title: 'Stock Balance & Health Report',
            subtitle: 'Healthy vs unhealthy items, live stock levels & reorder alerts',
            badge: 'Stock Health',
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
            onTap: _openStockBalanceModal,
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 10),
            _buildHubTile(
              icon: Icons.qr_code_2_rounded,
              title: 'Staff App Setup QR',
              subtitle: 'Generate & print QR code for Waiter, Rider & companion apps auto-config',
              badge: 'Admin Only',
              color: const Color(0xFF0284C7),
              bg: const Color(0xFFF0F9FF),
              onTap: () {
                AppSetupQrDialog.show(context);
              },
            ),
          ],
          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Color(0xFFFECACA)),
              elevation: 0,
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out Session', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              await TokenStorage.clear();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MobileBillingAuthScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHubTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
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
                          title,
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: color,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: textMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar({required String title}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: borderSubtle),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: textDark),
            onPressed: () {
              _loadCatalogAndMetadata();
              _loadPulseAndOrders();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: borderSubtle),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (idx) => setState(() => _currentTab = idx),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'Billing',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.autorenew_rounded),
            label: 'Subs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_rounded),
            label: 'Pulse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: 'Store',
          ),
        ],
      ),
    );
  }
}

class _CartEntry {
  final Item item;
  int quantity;
  _CartEntry({required this.item, required this.quantity});
}

// Live Camera Barcode Scanner Viewfinder Sheet with Live Cart below
class _BarcodeScannerSheet extends StatefulWidget {
  final List<Item> allItems;
  final Map<int, _CartEntry> cart;
  final double Function(Item) getItemPrice;
  final Function(Item) onItemScanned;
  final Function(Item) onIncreaseItem;
  final Function(int) onDecreaseItem;
  final Function(int) onRemoveItem;
  final VoidCallback onProceedToTender;

  const _BarcodeScannerSheet({
    required this.allItems,
    required this.cart,
    required this.getItemPrice,
    required this.onItemScanned,
    required this.onIncreaseItem,
    required this.onDecreaseItem,
    required this.onRemoveItem,
    required this.onProceedToTender,
  });

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [
      BarcodeFormat.all,
    ],
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final TextEditingController _manualBarcodeCtrl = TextEditingController();
  bool _isProcessing = false;
  bool _torchOn = false;
  Item? _lastScannedItem;
  bool _showSuccessAlert = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualBarcodeCtrl.dispose();
    super.dispose();
  }

  void _handleCodeScanned(String rawBarcode) {
    if (_isProcessing) return;
    final code = rawBarcode.trim();
    if (code.isEmpty) return;

    _isProcessing = true;

    // Ring / beep tone and solid vibration feedback
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    Item? matched;
    final cleanCode = code.toLowerCase();

    for (final it in widget.allItems) {
      final itBarcode = it.barcode.trim().toLowerCase();
      final itCode = it.itemCode.trim().toLowerCase();
      final itId = it.id.toString();

      if (itBarcode == cleanCode ||
          itCode == cleanCode ||
          itId == cleanCode ||
          itBarcode.replaceFirst(RegExp(r'^0+'), '') == cleanCode.replaceFirst(RegExp(r'^0+'), '') ||
          (itBarcode.length >= 6 && cleanCode.contains(itBarcode)) ||
          (cleanCode.length >= 6 && itBarcode.contains(cleanCode))) {
        matched = it;
        break;
      }
    }

    if (matched != null) {
      widget.onItemScanned(matched);
      setState(() {
        _lastScannedItem = matched;
        _showSuccessAlert = true;
      });

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _showSuccessAlert = false;
          });
        }
      });

      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _isProcessing = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No item found for barcode: $code'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.90;
    final totalCount = widget.cart.values.fold(0, (sum, e) => sum + e.quantity);
    final totalAmount = widget.cart.values.fold(0.0, (sum, e) => sum + (widget.getItemPrice(e.item) * e.quantity));

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Scan Barcode & Live Cart',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off,
                          color: _torchOn ? Colors.amber : const Color(0xFF2563EB)),
                      onPressed: () {
                        _scannerController.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // TOP: Live Scanner Viewfinder
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _handleCodeScanned(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                // Targeting box with animated laser
                Center(
                  child: Container(
                    width: 260,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _showSuccessAlert ? const Color(0xFF22C55E) : const Color(0xFF2563EB),
                        width: _showSuccessAlert ? 3.0 : 2.0,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: Center(
                      child: Container(
                        height: 2,
                        width: 240,
                        color: _showSuccessAlert ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
                // "Ring / Tee Added" Visual Alert Banner
                if (_showSuccessAlert && _lastScannedItem != null)
                  Positioned(
                    top: 10,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Added: ${_lastScannedItem!.itemName}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '₹${widget.getItemPrice(_lastScannedItem!).toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Manual Barcode entry fallback
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualBarcodeCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Or enter barcode / SKU number...',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onSubmitted: (val) {
                      _handleCodeScanned(val);
                      _manualBarcodeCtrl.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    _handleCodeScanned(_manualBarcodeCtrl.text);
                    _manualBarcodeCtrl.clear();
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // BELOW: Cart / Scanned Items Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Cart Items',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '$totalCount items',
                        style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF059669)),
                ),
              ],
            ),
          ),

          // Scrollable Cart List
          Expanded(
            child: widget.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 44, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('Scan items above to build cart',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: widget.cart.values.length,
                    separatorBuilder: (_, __) => const Divider(height: 8, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final entry = widget.cart.values.toList().reversed.elementAt(idx);
                      final price = widget.getItemPrice(entry.item);
                      final lineTotal = price * entry.quantity;
                      final isJustAdded = _lastScannedItem?.id == entry.item.id;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isJustAdded ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isJustAdded ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.item.itemName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                      if (isJustAdded) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('SCANNED',
                                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('₹${price.toStringAsFixed(2)} each',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            // Stepper
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    widget.onDecreaseItem(entry.item.id);
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.remove, size: 14, color: Color(0xFFDC2626)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('${entry.quantity}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    widget.onIncreaseItem(entry.item);
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Text('₹${lineTotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669))),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                widget.onRemoveItem(entry.item.id);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Tender Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: totalCount > 0 ? widget.onProceedToTender : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    totalCount > 0
                        ? 'Proceed to Tender & Pay (₹${totalAmount.toStringAsFixed(2)})'
                        : 'Scan Items to Tender',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  if (totalCount > 0) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom sheet for tender, customer details, schemes, and one-tap checkout
class _CheckoutModalSheet extends StatefulWidget {
  final Map<int, _CartEntry> cart;
  final List<Item> allItems;
  final double subtotal;
  final double tax;
  final double total;
  final List<SaleScheme> schemes;
  final List<SaleCustomer> customers;
  final List<String> paymentMethods;
  final SalesController salesCtrl;
  final double Function(Item) getItemPrice;
  final Function(Item) onIncreaseItem;
  final Function(int) onDecreaseItem;
  final Function(int) onRemoveItem;
  final Function(SaleOrder) onCheckoutComplete;

  const _CheckoutModalSheet({
    required this.cart,
    required this.allItems,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.schemes,
    required this.customers,
    required this.paymentMethods,
    required this.salesCtrl,
    required this.getItemPrice,
    required this.onIncreaseItem,
    required this.onDecreaseItem,
    required this.onRemoveItem,
    required this.onCheckoutComplete,
  });

  @override
  State<_CheckoutModalSheet> createState() => _CheckoutModalSheetState();
}

class _CheckoutModalSheetState extends State<_CheckoutModalSheet> {
  late String _selectedPaymentMode;
  final TextEditingController _cashTenderedCtrl = TextEditingController();
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerGstinCtrl = TextEditingController();

  // Manual Discount
  String _manualDiscountType = 'AMOUNT'; // 'AMOUNT' (₹) or 'PERCENT' (%)
  final TextEditingController _manualDiscountCtrl = TextEditingController();

  // Tax Mode: 'CGST_SGST' (Local supply) or 'IGST' (Interstate supply)
  String _taxMode = 'CGST_SGST';

  // Additional Charges
  List<BillingCharge> _charges = [];

  // Customer Credit & Advance Summary
  SaleScheme? _selectedScheme;
  SaleCustomer? _selectedCustomer;
  List<SaleCustomer> _customerSuggestions = [];
  double _customerOutstanding = 0.0;
  double _customerAdvance = 0.0;
  bool _loadingCredit = false;
  bool _isSaving = false;

  bool get _hasCustomer =>
      _selectedCustomer != null ||
      _customerPhoneCtrl.text.trim().isNotEmpty ||
      _customerNameCtrl.text.trim().isNotEmpty;

  // Active customer subscriptions
  List<Map<String, dynamic>> _customerSubscriptions = [];
  bool _loadingSubscriptions = false;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMode = widget.paymentMethods.isNotEmpty ? widget.paymentMethods.first : 'CASH';
    _cashTenderedCtrl.text = widget.total.toStringAsFixed(0);
    _customerPhoneCtrl.addListener(_onCustomerSearchChanged);
    _customerNameCtrl.addListener(_onCustomerSearchChanged);
    _manualDiscountCtrl.addListener(() => setState(() {}));

    final settings = Provider.of<SystemSettingsController>(context, listen: false).settings;
    if (settings != null) {
      final isInterstate = settings.billingTaxMode.toUpperCase().contains('IGST') ||
          settings.billingTaxMode.toUpperCase().contains('INTER');
      _taxMode = isInterstate ? 'IGST' : 'CGST_SGST';
      _charges = List<BillingCharge>.from(settings.defaultCharges);
    }
  }

  @override
  void dispose() {
    _cashTenderedCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerGstinCtrl.dispose();
    _manualDiscountCtrl.dispose();
    super.dispose();
  }

  void _onCustomerSearchChanged() {
    final phoneQ = _customerPhoneCtrl.text.trim().toLowerCase();
    final nameQ = _customerNameCtrl.text.trim().toLowerCase();

    if (phoneQ.isEmpty && nameQ.isEmpty) {
      setState(() {
        _customerSuggestions = [];
        _selectedCustomer = null;
        _selectedScheme = null;
        if (_selectedPaymentMode == 'CREDIT') {
          _selectedPaymentMode = 'CASH';
        }
      });
      return;
    }
    setState(() {
      _customerSuggestions = widget.customers.where((c) {
        final matchPhone = phoneQ.isNotEmpty && (c.customerPhone.toLowerCase().contains(phoneQ) || c.customerName.toLowerCase().contains(phoneQ));
        final matchName = nameQ.isNotEmpty && (c.customerName.toLowerCase().contains(nameQ) || c.customerPhone.toLowerCase().contains(nameQ));
        if (phoneQ.isNotEmpty && nameQ.isNotEmpty) {
          return matchPhone || matchName;
        } else if (phoneQ.isNotEmpty) {
          return matchPhone;
        } else {
          return matchName;
        }
      }).take(5).toList();
    });
  }

  void _selectCustomer(SaleCustomer cust) {
    setState(() {
      _selectedCustomer = cust;
      _customerPhoneCtrl.text = cust.customerPhone;
      _customerNameCtrl.text = cust.customerName;
      _customerGstinCtrl.text = cust.customerGstin;
      _customerSuggestions = [];
    });
    _fetchCustomerCredit(cust.customerPhone.isNotEmpty ? cust.customerPhone : cust.customerName);
    _fetchCustomerSubscriptions(cust);
  }

  Future<void> _fetchCustomerSubscriptions(SaleCustomer cust) async {
    setState(() => _loadingSubscriptions = true);
    try {
      final subs = await widget.salesCtrl.listCustomerSubscriptions(
        customerName: cust.customerName,
        customerPhone: cust.customerPhone,
        customerGstin: cust.customerGstin,
        date: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _customerSubscriptions = subs;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingSubscriptions = false);
    }
  }

  bool _isItemEligibleForSubscription(int itemId) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _customerSubscriptions.any((s) {
      final sItemId = int.tryParse((s['item_id'] ?? 0).toString()) ?? 0;
      if (sItemId != itemId) return false;
      final isActive = s['active_subscription'] == true ||
          (s['status'] ?? '').toString().toUpperCase() == 'ACTIVE';
      if (!isActive) return false;
      final startDate = (s['start_date'] ?? '').toString().split('T').first;
      final endDate = (s['end_date'] ?? '').toString().split('T').first;
      if (startDate.isNotEmpty && startDate.compareTo(todayStr) > 0) return false;
      if (endDate.isNotEmpty && endDate.compareTo(todayStr) < 0) return false;
      final rem = double.tryParse((s['today_remaining_qty'] ?? 0).toString()) ?? 0.0;
      return rem > 0;
    });
  }

  Future<void> _fetchCustomerCredit(String searchKey) async {
    if (searchKey.trim().isEmpty) return;
    setState(() => _loadingCredit = true);
    try {
      final summary = await widget.salesCtrl.getCustomerCreditSummary(searchKey.trim());
      if (mounted) {
        setState(() {
          _customerOutstanding = double.tryParse((summary['total_outstanding'] ?? 0).toString()) ?? 0.0;
          _customerAdvance = double.tryParse((summary['total_advance'] ?? 0).toString()) ?? 0.0;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingCredit = false);
    }
  }

  void _openAddCustomerDialog() {
    final nameCtrl = TextEditingController(text: _customerNameCtrl.text);
    final phoneCtrl = TextEditingController(text: _customerPhoneCtrl.text);
    final addrCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Customer', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(labelText: 'Customer Name', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(labelText: 'Mobile Phone', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(labelText: 'Address (Optional)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gstinCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(labelText: 'GSTIN (Optional)', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Phone are required')),
                );
                return;
              }
              try {
                final created = await widget.salesCtrl.createCustomer(
                  customerName: name,
                  customerPhone: phone,
                  customerAddress: addrCtrl.text.trim(),
                  customerGstin: gstinCtrl.text.trim(),
                );
                final newCust = SaleCustomer.fromJson(created);
                widget.customers.add(newCust);
                _selectCustomer(newCust);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  double get _schemeDiscountAmount {
    if (_selectedScheme == null) return 0.0;
    if (_selectedScheme!.discountType == 'PERCENTAGE') {
      return (widget.subtotal * _selectedScheme!.discountValue) / 100.0;
    } else {
      return _selectedScheme!.discountValue;
    }
  }

  double get _manualDiscountAmount {
    final val = double.tryParse(_manualDiscountCtrl.text.trim()) ?? 0.0;
    if (val <= 0) return 0.0;
    if (_manualDiscountType == 'PERCENT') {
      return (widget.subtotal * val) / 100.0;
    }
    return val;
  }

  InvoiceComputation _computeInvoice() {
    final settings = Provider.of<SystemSettingsController>(context, listen: false).settings;
    final isInclusiveMode = settings?.billingTaxMode.toUpperCase().contains('INCLUSIVE') ?? false;

    // Track available subscription units per item (strictly active and not exhausted)
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<int, double> availableSubQtyByItem = {};
    for (final sub in _customerSubscriptions) {
      final isActive = sub['active_subscription'] == true ||
          (sub['status'] ?? '').toString().toUpperCase() == 'ACTIVE';
      if (!isActive) continue;

      // Check validity date range
      final startDate = (sub['start_date'] ?? '').toString().split('T').first;
      final endDate = (sub['end_date'] ?? '').toString().split('T').first;
      if (startDate.isNotEmpty && startDate.compareTo(todayStr) > 0) continue; // Future
      if (endDate.isNotEmpty && endDate.compareTo(todayStr) < 0) continue; // Expired

      final itemId = int.tryParse((sub['item_id'] ?? 0).toString()) ?? 0;
      if (itemId <= 0) continue;

      // Day-capped quota: Must strictly have today_remaining_qty > 0.
      // If exhausted (0), do not apply subscription free qty!
      final remainingToday = double.tryParse((sub['today_remaining_qty'] ?? 0).toString()) ?? 0.0;
      if (remainingToday > 0) {
        availableSubQtyByItem[itemId] =
            (availableSubQtyByItem[itemId] ?? 0.0) + remainingToday;
      }
    }

    final List<SaleItem> rawSaleItems = [];
    for (final entry in widget.cart.values) {
      final item = entry.item;
      final unitPrice = widget.getItemPrice(item);
      final lineTaxPct = item.taxPercent;
      final isItemInclusive = item.isTaxInclusive || isInclusiveMode;
      final totalQty = entry.quantity.toDouble();

      final availSubQty = availableSubQtyByItem[item.id] ?? 0.0;
      if (availSubQty > 0) {
        final freeQty = math.min(totalQty, availSubQty);
        final paidQty = totalQty - freeQty;
        availableSubQtyByItem[item.id] = availSubQty - freeQty;

        if (freeQty > 0) {
          rawSaleItems.add(
            SaleItem(
              itemId: item.id,
              itemCode: item.itemCode,
              itemName: item.itemName,
              barcode: item.barcode,
              hsnSacCode: item.hsnSacCode,
              unit: item.unit.isNotEmpty ? item.unit : 'Nos',
              qty: freeQty,
              originalQty: totalQty,
              rate: 0.0,
              referenceRate: unitPrice,
              originalRate: unitPrice,
              taxType: item.taxType.isNotEmpty ? item.taxType : 'GST',
              taxPercent: lineTaxPct,
              taxGroupId: item.taxGroupId,
              taxGroup: item.taxGroup,
              isTaxInclusive: isItemInclusive,
              isAdvanceFree: true,
              discountApplicable: false,
              schemeApplicable: false,
            ),
          );
        }
        if (paidQty > 0) {
          rawSaleItems.add(
            SaleItem(
              itemId: item.id,
              itemCode: item.itemCode,
              itemName: item.itemName,
              barcode: item.barcode,
              hsnSacCode: item.hsnSacCode,
              unit: item.unit.isNotEmpty ? item.unit : 'Nos',
              qty: paidQty,
              originalQty: paidQty,
              rate: unitPrice,
              isAdvanceFree: false,
              taxType: item.taxType.isNotEmpty ? item.taxType : 'GST',
              taxPercent: lineTaxPct,
              taxGroupId: item.taxGroupId,
              taxGroup: item.taxGroup,
              isTaxInclusive: isItemInclusive,
              discountApplicable: item.discountApplicable,
              schemeApplicable: item.schemeApplicable,
            ),
          );
        }
      } else {
        rawSaleItems.add(
          SaleItem(
            itemId: item.id,
            itemCode: item.itemCode,
            itemName: item.itemName,
            barcode: item.barcode,
            hsnSacCode: item.hsnSacCode,
            unit: item.unit.isNotEmpty ? item.unit : 'Nos',
            qty: totalQty,
            originalQty: totalQty,
            rate: unitPrice,
            isAdvanceFree: false,
            taxType: item.taxType.isNotEmpty ? item.taxType : 'GST',
            taxPercent: lineTaxPct,
            taxGroupId: item.taxGroupId,
            taxGroup: item.taxGroup,
            isTaxInclusive: isItemInclusive,
            discountApplicable: item.discountApplicable,
            schemeApplicable: item.schemeApplicable,
          ),
        );
      }
    }

    return PosBillingEngine.compute(
      items: rawSaleItems,
      taxMode: _taxMode,
      schemeDiscountAmount: _schemeDiscountAmount,
      manualDiscountAmount: _manualDiscountAmount,
      charges: _charges,
    );
  }

  double _calculateSubscriptionAdjustment(List<SaleItem> items) {
    double total = 0.0;
    for (final it in items) {
      if (it.isAdvanceFree) {
        final refRate = (it.referenceRate > 0)
            ? it.referenceRate
            : ((it.originalRate != null && it.originalRate! > 0)
                ? it.originalRate!
                : it.rate);
        final baseAmt = refRate * it.qty;
        if (it.isTaxInclusive) {
          total += baseAmt;
        } else {
          total += it.taxPercent > 0 ? (baseAmt * (1.0 + it.taxPercent / 100.0)) : baseAmt;
        }
      }
    }
    return total;
  }

  void _showTaxBreakdownDialog(InvoiceComputation computation) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isIgst = _taxMode.contains('IGST');
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GST Tax Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    isIgst ? 'Mode: Inter-State (IGST)' : 'Mode: Intra-State (CGST + SGST)',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 5, child: Text('Component', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('Taxable', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('Tax Amt', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (computation.taxSummary.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No tax applicable for this sale', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  )
                else
                  ...computation.taxSummary.map((tax) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text(tax.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 3, child: Text('₹${tax.taxableAmount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                          Expanded(flex: 3, child: Text('₹${tax.taxAmount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                        ],
                      ),
                    );
                  }),
                const Divider(color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total GST Collected:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('₹${computation.totalTax.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  double get _cashTendered => double.tryParse(_cashTenderedCtrl.text.trim()) ?? 0.0;

  Future<void> _submitSale() async {
    setState(() => _isSaving = true);
    try {
      final saleNo = await widget.salesCtrl.getNextSaleNo();
      final settings = Provider.of<SystemSettingsController>(context, listen: false).settings;

      final computation = _computeInvoice();
      final double subAdj = _calculateSubscriptionAdjustment(computation.items);
      final double grossSubtotal = computation.items.fold<double>(0, (sum, i) => sum + ((i.rate > 0 ? i.rate : i.referenceRate) * i.qty));
      final double resolvedSubtotal = grossSubtotal > 0 ? grossSubtotal : computation.subTotal;
      final double totalTax = computation.totalTax;
      final double cgstAmount = computation.amountForCode('CGST');
      final double sgstAmount = computation.amountForCode('SGST');
      final double igstAmount = computation.amountForCode('IGST');
      final double netAmount = (computation.netAmount * 100).round() / 100.0;
      final double roundOffAmount = ((netAmount.roundToDouble() - netAmount) * 100).round() / 100.0;
      final double finalPayable = math.max(0.0, netAmount.roundToDouble());
      final format = settings?.billFormat.isNotEmpty == true ? settings!.billFormat : 'THERMAL_80';
      final resolvedMode = (finalPayable <= 0.01 && subAdj > 0) ? 'SUBSCRIPTION' : _selectedPaymentMode;
      final isCredit = resolvedMode == 'CREDIT';

      if (isCredit) {
        final hasCustomer = (_selectedCustomer != null) ||
            _customerPhoneCtrl.text.trim().isNotEmpty ||
            _customerNameCtrl.text.trim().isNotEmpty;
        if (!hasCustomer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer name or phone is required for credit bills.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
      }

      final double initialPaid = isCredit
          ? 0.0
          : (resolvedMode == 'CASH' ? math.min(_cashTendered, finalPayable) : finalPayable);
      final double amtPaid = isCredit
          ? 0.0
          : (resolvedMode == 'CASH' ? math.min(_cashTendered, finalPayable) : finalPayable);
      final double balDue = isCredit
          ? finalPayable
          : (resolvedMode == 'CASH' ? math.max(0.0, finalPayable - _cashTendered) : 0.0);
      final double chgAmt = (!isCredit && resolvedMode == 'CASH' && _cashTendered > finalPayable)
          ? (_cashTendered - finalPayable)
          : 0.0;

      final saleOrder = SaleOrder(
        saleNo: saleNo,
        saleDate: DateTime.now(),
        status: 'COMPLETED',
        orderType: 'B2C',
        billingCountry: settings?.billingCountry ?? 'India',
        billingTaxMode: _taxMode,
        billFormat: format,
        customerName: _selectedCustomer?.customerName ??
            (_customerNameCtrl.text.trim().isNotEmpty
                ? _customerNameCtrl.text.trim()
                : null),
        customerPhone: _selectedCustomer?.customerPhone ??
            (_customerPhoneCtrl.text.trim().isNotEmpty
                ? _customerPhoneCtrl.text.trim()
                : null),
        customerGstin: _selectedCustomer?.customerGstin ??
            (_customerGstinCtrl.text.trim().isNotEmpty
                ? _customerGstinCtrl.text.trim()
                : null),
        paymentMode: resolvedMode,
        initialAmountPaid: initialPaid,
        amountPaid: amtPaid,
        changeAmount: chgAmt,
        balanceDue: balDue,
        subTotal: resolvedSubtotal,
        totalQty: computation.totalQty,
        taxPercent: computation.subTotal > 0 ? (totalTax * 100 / computation.subTotal) : 0.0,
        schemeId: _selectedScheme?.id,
        schemeName: _selectedScheme?.schemeName,
        schemeDiscount: computation.schemeDiscountAmount,
        manualDiscountValue: double.tryParse(_manualDiscountCtrl.text.trim()) ?? 0.0,
        manualDiscountAmount: computation.manualDiscountAmount,
        taxableAmount: computation.taxableAmount,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        igstAmount: igstAmount,
        totalTax: totalTax,
        taxBreakup: computation.taxSummary,
        charges: computation.charges.map((c) => c.charge).toList(),
        chargeTotal: computation.chargeTotal,
        chargeTaxTotal: computation.chargeTaxTotal,
        totalDiscount: computation.totalDiscount,
        roundOffAmount: roundOffAmount,
        netAmount: finalPayable,
        itemsPreSplit: true,
        items: computation.items,
      );

      await widget.salesCtrl.createSale(saleOrder);
      widget.onCheckoutComplete(saleOrder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sale: ${e.toString()}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final computation = _computeInvoice();
    final double subAdj = _calculateSubscriptionAdjustment(computation.items);
    final double grossSubtotal = computation.items.fold<double>(0, (sum, i) => sum + ((i.rate > 0 ? i.rate : i.referenceRate) * i.qty));
    final double displaySubtotal = grossSubtotal > 0 ? grossSubtotal : computation.subTotal;
    final double finalPayable = math.max(0.0, (computation.netAmount * 100).round() / 100.0);
    final double changeAmt = (_cashTendered - finalPayable) > 0 ? (_cashTendered - finalPayable) : 0.0;
    final bool isIgst = _taxMode.contains('IGST');

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Cart Items & Tender',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.cart.length} items',
                        style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE2E8F0)),

            // --- CART ITEMS LIST ---
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.cart.values.length,
                separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, idx) {
                  final entry = widget.cart.values.elementAt(idx);
                  final price = widget.getItemPrice(entry.item);
                  final isSubscribed = _isItemEligibleForSubscription(entry.item.id);
                  final lineTotal = isSubscribed && entry.quantity <= 1 ? 0.0 : (isSubscribed ? price * (entry.quantity - 1) : price * entry.quantity);

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.item.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (isSubscribed) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('SUB FREE', style: TextStyle(color: Color(0xFF15803D), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              isSubscribed && entry.quantity <= 1
                                  ? 'Free with Subscription'
                                  : '₹${price.toStringAsFixed(2)} each • ${entry.item.taxPercent.toStringAsFixed(0)}% Tax',
                              style: TextStyle(color: isSubscribed ? const Color(0xFF15803D) : const Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Stepper: [-] [qty] [+]
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              widget.onDecreaseItem(entry.item.id);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.remove, size: 14, color: Color(0xFFDC2626)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${entry.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              widget.onIncreaseItem(entry.item);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.add, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '₹${lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          widget.onRemoveItem(entry.item.id);
                          setState(() {});
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0)),

            // --- TAX REGIME TOGGLE (Local Intra-State CGST+SGST vs Interstate IGST) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Tax Supply:', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Intra-State (CGST+SGST)', style: TextStyle(fontSize: 11)),
                    selected: !isIgst,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(color: !isIgst ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    onSelected: (val) {
                      if (val) setState(() => _taxMode = 'CGST_SGST');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('IGST (Inter-State)', style: TextStyle(fontSize: 11)),
                    selected: isIgst,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(color: isIgst ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    onSelected: (val) {
                      if (val) setState(() => _taxMode = 'IGST');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // --- MANUAL DISCOUNT SECTION ---
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.discount_outlined, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Text('Discount:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _manualDiscountType = 'AMOUNT'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _manualDiscountType == 'AMOUNT' ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text('₹ Flat', style: TextStyle(color: _manualDiscountType == 'AMOUNT' ? Colors.white : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _manualDiscountType = 'PERCENT'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _manualDiscountType == 'PERCENT' ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text('% Pct', style: TextStyle(color: _manualDiscountType == 'PERCENT' ? Colors.white : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _manualDiscountCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: _manualDiscountType == 'AMOUNT' ? '₹ 0.00' : '0 %',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- BILL TOTALS WITH TAX BREAKUP (i) BUTTON ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:', style: TextStyle(color: Color(0xFF64748B))),
                Text('₹${displaySubtotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Tax (${isIgst ? 'IGST' : 'GST'}):', style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showTaxBreakdownDialog(computation),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Icon(Icons.info_outline, size: 14, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
                Text('₹${computation.totalTax.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
              ],
            ),
            if (computation.chargeTotal > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Other Charges:', style: TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _charges.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close_rounded, size: 12, color: Color(0xFFDC2626)),
                              SizedBox(width: 2),
                              Text('Remove', style: TextStyle(color: Color(0xFFDC2626), fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text('₹${computation.chargeTotal.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                ],
              ),
            ],
            if (subAdj > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subscription Adjustment:',
                      style: TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('-₹${subAdj.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            if (computation.schemeDiscountAmount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Scheme (${_selectedScheme?.schemeName ?? 'Promo'}):',
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('-₹${computation.schemeDiscountAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            if (computation.manualDiscountAmount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manual Discount:',
                      style: TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('-₹${computation.manualDiscountAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Payable:',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
                Text('₹${finalPayable.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF059669), fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),

            // Scheme / Promotion Selector
            if (widget.schemes.isNotEmpty) ...[
              if (!_hasCustomer) ...[
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Customer selection required to apply schemes. Please select or enter a customer first.'),
                        backgroundColor: Color(0xFFD97706),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.local_offer_outlined, color: Color(0xFF94A3B8), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Apply Scheme / Discount', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                              SizedBox(height: 2),
                              Text('Customer selection required to apply schemes',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        Icon(Icons.lock_outline, size: 16, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                DropdownButtonFormField<SaleScheme?>(
                  initialValue: _selectedScheme,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Apply Scheme / Discount',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    prefixIcon: const Icon(Icons.local_offer_outlined, color: Color(0xFF2563EB), size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  items: [
                    const DropdownMenuItem<SaleScheme?>(
                      value: null,
                      child: Text('No Scheme Applied'),
                    ),
                    ...widget.schemes.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.schemeName),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedScheme = val);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],

            // Customer Info & Autocomplete by Name OR Phone
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customerPhoneCtrl,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Customer Phone / Search',
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF64748B), size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _openAddCustomerDialog,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customerNameCtrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Customer Name (Search or Enter)',
                labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B), size: 18),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            if (_customerSuggestions.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: _customerSuggestions.map((c) {
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.person, size: 16, color: Color(0xFF2563EB)),
                      ),
                      title: Text(c.customerName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: Text(c.customerPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      trailing: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF2563EB)),
                      onTap: () => _selectCustomer(c),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Customer Credit & Advance badges
            if (_loadingCredit)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(height: 16, width: 16, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_customerOutstanding > 0 || _customerAdvance > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_customerOutstanding > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Text(
                            'Credit Due: ₹${_customerOutstanding.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (_customerOutstanding > 0 && _customerAdvance > 0)
                    const SizedBox(width: 8),
                  if (_customerAdvance > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Color(0xFF065F46)),
                          const SizedBox(width: 4),
                          Text(
                            'Advance: ₹${_customerAdvance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // Customer Active Subscriptions Section
            if (_loadingSubscriptions)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(height: 16, width: 16, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_customerSubscriptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, size: 16, color: Color(0xFF16A34A)),
                        SizedBox(width: 6),
                        Text('Customer Active Subscriptions',
                            style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._customerSubscriptions.map((sub) {
                      final itemName = (sub['item_name'] ?? 'Product').toString();
                      final itemId = int.tryParse((sub['item_id'] ?? 0).toString()) ?? 0;
                      final todayRemaining = double.tryParse((sub['today_remaining_qty'] ?? 0).toString()) ?? 0.0;
                      final dailyAllowed = double.tryParse((sub['daily_allowed_qty'] ?? 1).toString()) ?? 1.0;
                      final endDate = (sub['end_date'] ?? '').toString().split('T').first;
                      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      final isExpired = endDate.isNotEmpty && endDate.compareTo(todayStr) < 0;
                      final isQuotaExhausted = todayRemaining <= 0;
                      final isInCart = widget.cart.containsKey(itemId);

                      final origAmount = double.tryParse((sub['advance_original_amount'] ?? sub['total_payment_amount'] ?? 0).toString()) ?? 0.0;
                      final consumedAmount = double.tryParse((sub['advance_consumed_amount'] ?? 0).toString()) ?? 0.0;
                      final remainingAmount = sub['advance_remaining_amount'] != null
                          ? (double.tryParse(sub['advance_remaining_amount'].toString()) ?? (origAmount - consumedAmount))
                          : (origAmount - consumedAmount);

                      final origQty = double.tryParse((sub['advance_original_qty'] ?? 0).toString()) ?? 0.0;
                      final consumedQty = double.tryParse((sub['advance_consumed_qty'] ?? 0).toString()) ?? 0.0;
                      final remainingQty = sub['advance_remaining_qty'] != null
                          ? (double.tryParse(sub['advance_remaining_qty'].toString()) ?? (origQty - consumedQty))
                          : (origQty - consumedQty);

                      final safeOrigQty = origQty > 0 ? origQty : (consumedQty + (remainingQty > 0 ? remainingQty : 0));
                      final double qtyRatio = safeOrigQty > 0 ? (consumedQty / safeOrigQty).clamp(0.0, 1.0) : 0.0;
                      final double amtRatio = origAmount > 0 ? (consumedAmount / origAmount).clamp(0.0, 1.0) : 0.0;
                      final double progress = qtyRatio > 0 ? qtyRatio : amtRatio;
                      final int percent = (progress * 100).round();

                      return Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    isExpired
                                        ? '$itemName • Expired ($endDate)'
                                        : (isQuotaExhausted
                                            ? '$itemName • 0/${dailyAllowed.toInt()} left today (Exhausted)'
                                            : '$itemName • ${todayRemaining.toInt()}/${dailyAllowed.toInt()} Free today'),
                                    style: TextStyle(
                                      color: isExpired || isQuotaExhausted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isExpired)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Plan Expired', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                else if (isQuotaExhausted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Quota Exhausted', style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                else if (isInCart)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check, size: 12, color: Color(0xFF16A34A)),
                                        SizedBox(width: 3),
                                        Text('Applied (FREE)', style: TextStyle(color: Color(0xFF15803D), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () {
                                      try {
                                        final item = widget.allItems.firstWhere((it) => it.id == itemId);
                                        widget.onIncreaseItem(item);
                                        setState(() {});
                                      } catch (_) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Item "$itemName" not found in active catalog')),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add, size: 12, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('Add Free to Cart', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Adv Left: ₹${remainingAmount.clamp(0, double.infinity).toStringAsFixed(0)}',
                                  style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Consumed: ${consumedQty.toInt()}/${safeOrigQty.toInt()} Nos ($percent%)',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  percent >= 100
                                      ? const Color(0xFFDC2626)
                                      : percent >= 75
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Dynamic Payment Methods Selector
            const Text('Payment Mode',
                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...widget.paymentMethods,
                if (subAdj > 0 && !widget.paymentMethods.contains('SUBSCRIPTION')) 'SUBSCRIPTION',
              ].map((mode) {
                final isSel = _selectedPaymentMode == mode;
                final isLockedCredit = mode == 'CREDIT' && !_hasCustomer;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mode, style: TextStyle(
                        color: isSel ? Colors.white : (isLockedCredit ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      )),
                      if (isLockedCredit) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock_outline, size: 12, color: Color(0xFF94A3B8)),
                      ],
                    ],
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: isLockedCredit ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                  side: BorderSide(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                  onSelected: (val) {
                    if (mode == 'CREDIT' && !_hasCustomer) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Customer selection required for Credit billing. Please select or enter a customer first.'),
                          backgroundColor: Color(0xFFDC2626),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    if (val) setState(() => _selectedPaymentMode = mode);
                  },
                );
              }).toList(),
            ),

            if (_selectedPaymentMode == 'CASH') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashTenderedCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Cash Given',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Change Due', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                          Text(
                            '₹${changeAmt.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Color(0xFF059669), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            // Checkout button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _submitSale,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Complete Sale (₹${finalPayable.toStringAsFixed(2)})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog that fetches and displays the FULL itemized lines for a bill
class _BillDetailsDialog extends StatefulWidget {
  final SaleOrder initialOrder;
  final Function(SaleOrder, List<SaleItem>) onWhatsAppShare;
  final Function(SaleOrder, List<SaleItem>) onPrint80mm;
  final Function(SaleOrder)? onModify;

  const _BillDetailsDialog({
    required this.initialOrder,
    required this.onWhatsAppShare,
    required this.onPrint80mm,
    this.onModify,
  });

  @override
  State<_BillDetailsDialog> createState() => _BillDetailsDialogState();
}

class _BillDetailsDialogState extends State<_BillDetailsDialog> {
  bool _loading = true;
  List<SaleItem> _items = [];
  late SaleOrder _order;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _fetchFullSale();
  }

  Future<void> _fetchFullSale() async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.sales}/${_order.saleNo}');
      if (res['data'] != null) {
        final data = res['data'];
        final detailedOrder = SaleOrder.fromJson(data);
        if (mounted) {
          setState(() {
            _order = detailedOrder;
            _items = detailedOrder.items;
            _loading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _items = widget.initialOrder.items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_order.saleNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(DateFormat('dd MMM yyyy, hh:mm a').format(_order.saleDate),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(
                heightFactor: 3,
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_order.customerName != null) ...[
                      Text('Customer: ${_order.customerName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                      if (_order.customerPhone != null)
                        Text('Phone: ${_order.customerPhone}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                      const SizedBox(height: 8),
                    ],
                    const Divider(height: 12, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Itemized Bill & Tax', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('${_items.length} items', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No item lines found in invoice record', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      )
                    else
                      ..._items.map((it) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      it.itemName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Text(
                                    '₹${it.lineTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${it.qty.toInt()} × ₹${it.rate.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFDBEAFE)),
                                    ),
                                    child: Text(
                                      'Tax ${it.taxPercent.toStringAsFixed(0)}%: ₹${it.taxAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Taxable Subtotal:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        Text('₹${_order.subTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Tax (GST):', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('₹${_order.totalTax.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (_order.cgstAmount > 0 || _order.sgstAmount > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('  (CGST: ₹${_order.cgstAmount.toStringAsFixed(2)} | SGST: ₹${_order.sgstAmount.toStringAsFixed(2)})',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                          const SizedBox.shrink(),
                        ],
                      ),
                    ],
                    if (_order.igstAmount > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('  (IGST: ₹${_order.igstAmount.toStringAsFixed(2)})',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                          const SizedBox.shrink(),
                        ],
                      ),
                    ],
                    if (_order.chargeTotal > 0 || _order.charges.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Other Charges:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          Text('₹${_order.chargeTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                    if (_order.schemeDiscount > 0) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Scheme Discount:', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('-₹${_order.schemeDiscount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    if (_order.manualDiscountAmount > 0) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Manual Discount:', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('-₹${_order.manualDiscountAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    if (_order.roundOffAmount.abs() > 0.001) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Round Off:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                          Text('₹${_order.roundOffAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Net Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('₹${_order.netAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Payment Mode: ${_order.paymentMode}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('WhatsApp PDF'),
                            onPressed: () {
                              widget.onWhatsAppShare(_order, _items);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.print_outlined, size: 16),
                            label: const Text('Print Bill'),
                            onPressed: () {
                              widget.onPrint80mm(_order, _items);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (widget.onModify != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            backgroundColor: const Color(0xFFEFF6FF),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Modify This Bill',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onModify!(_order);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

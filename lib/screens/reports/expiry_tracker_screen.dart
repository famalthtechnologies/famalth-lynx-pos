import 'dart:io';
import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

class ExpiryTrackerScreen extends StatefulWidget {
  const ExpiryTrackerScreen({super.key});

  @override
  State<ExpiryTrackerScreen> createState() => _ExpiryTrackerScreenState();
}

class _ExpiryTrackerScreenState extends State<ExpiryTrackerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = false;
  String _statusFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  List<dynamic> _items = [];
  Map<String, dynamic> _summary = {
    'total_tracked': 0,
    'expired': 0,
    'critical': 0,
    'warning': 0,
    'healthy': 0,
    'new_shorter_than_old': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging && mounted) setState(() {});
    });
    _fetchExpiryData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchExpiryData() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{};
      if (_statusFilter != 'ALL') {
        queryParams['status_filter'] = _statusFilter;
      }
      if (_searchCtrl.text.trim().isNotEmpty) {
        queryParams['search'] = _searchCtrl.text.trim();
      }

      final res = await ApiClient.get(
        ApiEndpoints.expiryTracker,
        queryParams: queryParams,
      );

      if (res != null && res['success'] == true) {
        setState(() {
          _items = res['data'] ?? [];
          _summary = Map<String, dynamic>.from(res['summary'] ?? {});
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDC2626),
              content: Text(res?['message'] ?? 'Failed to load expiry tracker data'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Error loading expiry tracker: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerExpiryAlerts() async {
    try {
      final res = await ApiClient.post(ApiEndpoints.expiryAlertsTrigger, {});
      if (res != null && res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(res['message'] ?? 'Expiry alerts dispatched to notifications.')),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Failed to trigger expiry alerts: $e'),
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final workbook = exc.Excel.createExcel();
      final sheet = workbook['Expiry_Register'];
      workbook.setDefaultSheet('Expiry_Register');

      // Header row
      sheet.appendRow([
        exc.TextCellValue('Item Code'),
        exc.TextCellValue('Item Name'),
        exc.TextCellValue('Brand'),
        exc.TextCellValue('Unit'),
        exc.TextCellValue('Current Stock'),
        exc.TextCellValue('Nearest Expiry'),
        exc.TextCellValue('Days Remaining'),
        exc.TextCellValue('Status'),
        exc.TextCellValue('Batches Count'),
        exc.TextCellValue('Expiry Comparison Alert'),
      ]);

      for (final it in _items) {
        sheet.appendRow([
          exc.TextCellValue(it['item_code']?.toString() ?? ''),
          exc.TextCellValue(it['item_name']?.toString() ?? ''),
          exc.TextCellValue(it['brand']?.toString() ?? 'General'),
          exc.TextCellValue(it['unit']?.toString() ?? 'PCS'),
          exc.DoubleCellValue(double.tryParse('${it['current_stock'] ?? 0}') ?? 0.0),
          exc.TextCellValue(it['nearest_expiry_date']?.toString() ?? ''),
          exc.IntCellValue(int.tryParse('${it['days_remaining'] ?? 0}') ?? 0),
          exc.TextCellValue(it['status']?.toString() ?? 'HEALTHY'),
          exc.IntCellValue(int.tryParse('${it['batches_count'] ?? 1}') ?? 1),
          exc.TextCellValue(it['expiry_comparison']?.toString() ?? 'NORMAL'),
        ]);
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'Receiving_Expiry_Tracker_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      final fileBytes = workbook.encode();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes, flush: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text('Excel Report exported: ${file.path}'),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () => OpenFile.open(file.path),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Failed to export Excel: $e'),
          ),
        );
      }
    }
  }

  void _openReceivingLedger(dynamic item) {
    final itemId = item['item_id'] ?? item['item_code'];
    final itemName = item['item_name'] ?? 'Item';
    final itemCode = item['item_code'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => _ReceivingBatchLedgerDialog(
        itemId: itemId,
        itemName: itemName,
        itemCode: itemCode,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SOLD OUT':
      case 'SOLD_OUT':
        return const Color(0xFF64748B);
      case 'EXPIRED':
        return const Color(0xFFDC2626);
      case 'CRITICAL':
        return const Color(0xFFEA580C);
      case 'WARNING':
        return const Color(0xFFD97706);
      case 'HEALTHY':
      case 'GOOD':
      case 'ACTIVE':
      default:
        return const Color(0xFF16A34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildEnterpriseHeader(),
            _buildKpiSummaryBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildRegisterTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterpriseHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFF4F46E5), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Receiving Expiry & Batch Tracker',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Beta',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Shelf-life intelligence, batch ledgers, shorter-expiry detection & inventory risk',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4338CA),
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Dispatch Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                onPressed: _triggerExpiryAlerts,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF99F6E4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                onPressed: _exportToExcel,
              ),
              IconButton(
                tooltip: 'Refresh Data',
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
                onPressed: _fetchExpiryData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBar() {
    final total = _summary['total_tracked'] ?? 0;
    final expired = _summary['expired'] ?? 0;
    final critical = _summary['critical'] ?? 0;
    final warning = _summary['warning'] ?? 0;
    final healthy = _summary['healthy'] ?? 0;
    final shorterExpiryAlerts = _summary['new_shorter_than_old'] ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildKpiCard('Tracked Items', '$total', Icons.inventory_2_outlined, const Color(0xFF3B82F6)),
                const SizedBox(width: 10),
                _buildKpiCard('Expired Items', '$expired', Icons.error_outline_rounded, const Color(0xFFDC2626)),
                const SizedBox(width: 10),
                _buildKpiCard('Critical (<30d)', '$critical', Icons.warning_amber_rounded, const Color(0xFFEA580C)),
                const SizedBox(width: 10),
                _buildKpiCard('Warning (<90d)', '$warning', Icons.access_time_rounded, const Color(0xFFD97706)),
                const SizedBox(width: 10),
                _buildKpiCard('Safe (>90d)', '$healthy', Icons.verified_outlined, const Color(0xFF16A34A)),
                const SizedBox(width: 10),
                _buildKpiCard('Shorter Expiry Alerts', '$shorterExpiryAlerts', Icons.change_circle_outlined, const Color(0xFF7C3AED)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFF0F172A),
              unselectedLabelColor: const Color(0xFF64748B),
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1)),
                ],
              ),
              indicatorPadding: const EdgeInsets.all(4),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Batch Register & Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Shelf-Life & Expiry Analytics', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.9))),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No items match the selected expiry criteria',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try changing filters or resetting search',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        return _buildBatchCard(_items[idx]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by item name, item code, brand...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                _fetchExpiryData();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _fetchExpiryData(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                icon: const Icon(Icons.filter_list_rounded, size: 16),
                label: const Text('Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _fetchExpiryData,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('ALL', 'All Items'),
                const SizedBox(width: 6),
                _filterChip('EXPIRED', 'Expired'),
                const SizedBox(width: 6),
                _filterChip('CRITICAL', 'Critical (<30d)'),
                const SizedBox(width: 6),
                _filterChip('WARNING', 'Warning (<90d)'),
                const SizedBox(width: 6),
                _filterChip('HEALTHY', 'Safe (>90d)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? Colors.white : const Color(0xFF334155),
      ),
      selectedColor: const Color(0xFF1E293B),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: selected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      onSelected: (val) {
        if (val) {
          setState(() => _statusFilter = key);
          _fetchExpiryData();
        }
      },
    );
  }

  Widget _buildBatchCard(dynamic it) {
    final status = it['status'] ?? 'HEALTHY';
    final statusColor = _getStatusColor(status);
    final days = it['days_remaining'] ?? 0;
    final isShorterThanOld = it['expiry_comparison'] == 'NEW_SHORTER_THAN_OLD';
    final batchesCount = it['batches_count'] ?? 1;

    String daysText;
    if (days < 0) {
      daysText = 'Expired ${-days} days ago';
    } else if (days == 0) {
      daysText = 'Expires Today';
    } else {
      daysText = '$days days remaining';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isShorterThanOld
              ? const Color(0xFFF59E0B)
              : (status == 'EXPIRED' ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
          width: isShorterThanOld ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openReceivingLedger(it),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_outlined, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it['item_name'] ?? 'Item',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Code: ${it['item_code'] ?? '-'}  •  Brand: ${it['brand'] ?? 'General'}  •  $batchesCount GRN Receipt Batches',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Expiry & stock details
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 15, color: const Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      'Nearest Expiry: ${it['nearest_expiry_date'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        daysText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Available Stock: ${it['current_stock'] ?? 0} ${it['unit'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if ((it['active_batch_available_qty'] ?? 0) > 0)
                          Text(
                            'Active Batch Qty: ${it['active_batch_available_qty']} ${it['unit'] ?? ''}',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isShorterThanOld) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Shelf-Life Inversion Alert: New received shipment expires sooner (${it['newest_batch_expiry']}) than existing inventory (${it['old_batch_expiry']}) by ${it['days_difference']?.abs() ?? 0} days!',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Click to inspect batch ledger & GRN history →',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No expiry batch data available for analytics',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final expired = _summary['expired'] ?? 0;
    final critical = _summary['critical'] ?? 0;
    final warning = _summary['warning'] ?? 0;
    final healthy = _summary['healthy'] ?? 0;

    final List<_ExpiryChartPoint> chartData = [
      _ExpiryChartPoint('Expired', expired, const Color(0xFFDC2626)),
      _ExpiryChartPoint('Critical (<30d)', critical, const Color(0xFFEA580C)),
      _ExpiryChartPoint('Warning (<90d)', warning, const Color(0xFFD97706)),
      _ExpiryChartPoint('Safe (>90d)', healthy, const Color(0xFF16A34A)),
    ].where((p) => p.count > 0).toList();

    // Top items approaching expiry
    final itemsSortedByDays = [..._items]..sort((a, b) => ((a['days_remaining'] ?? 0) as num).compareTo((b['days_remaining'] ?? 0) as num));
    final topApproaching = itemsSortedByDays.take(7).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doughnut Chart: Expiry Distribution
              Expanded(
                flex: 5,
                child: Container(
                  height: 380,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inventory Expiry Risk Profile',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Proportion of stock items categorized by shelf-life urgency',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SfCircularChart(
                          legend: const Legend(
                            isVisible: true,
                            position: LegendPosition.bottom,
                            overflowMode: LegendItemOverflowMode.wrap,
                          ),
                          series: <CircularSeries>[
                            DoughnutSeries<_ExpiryChartPoint, String>(
                              dataSource: chartData,
                              xValueMapper: (_ExpiryChartPoint data, _) => data.label,
                              yValueMapper: (_ExpiryChartPoint data, _) => data.count,
                              pointColorMapper: (_ExpiryChartPoint data, _) => data.color,
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelPosition: ChartDataLabelPosition.outside,
                              ),
                              innerRadius: '60%',
                              enableTooltip: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Bar Chart: Top items approaching expiry
              Expanded(
                flex: 6,
                child: Container(
                  height: 380,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top Items with Lowest Shelf Life',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Days remaining before stock expiry (prioritize FIFO sale/liquidation)',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SfCartesianChart(
                          primaryXAxis: const CategoryAxis(
                            labelRotation: -20,
                            labelIntersectAction: AxisLabelIntersectAction.hide,
                          ),
                          primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Days Remaining')),
                          series: <CartesianSeries>[
                            BarSeries<dynamic, String>(
                              dataSource: topApproaching,
                              xValueMapper: (dynamic d, _) => (d['item_name'] ?? 'Item').toString().length > 15
                                  ? '${(d['item_name'] ?? '').toString().substring(0, 15)}..'
                                  : (d['item_name'] ?? '').toString(),
                              yValueMapper: (dynamic d, _) => (d['days_remaining'] ?? 0) as num,
                              pointColorMapper: (dynamic d, _) => _getStatusColor(d['status'] ?? 'HEALTHY'),
                              dataLabelSettings: const DataLabelSettings(isVisible: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Batch Risk Ledger summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF4F46E5), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Automated Batch Vigilance Protocols',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The Expiry Watchdog checks incoming Goods Receipts (GRNs). When older stock exists with a longer shelf life than a newly delivered shipment, a warning is raised to prevent supplier batch dumping and optimize FIFO dispensing.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryChartPoint {
  final String label;
  final num count;
  final Color color;

  _ExpiryChartPoint(this.label, this.count, this.color);
}

class _ReceivingBatchLedgerDialog extends StatefulWidget {
  final dynamic itemId;
  final String itemName;
  final String itemCode;

  const _ReceivingBatchLedgerDialog({
    required this.itemId,
    required this.itemName,
    required this.itemCode,
  });

  @override
  State<_ReceivingBatchLedgerDialog> createState() => _ReceivingBatchLedgerDialogState();
}

class _ReceivingBatchLedgerDialogState extends State<_ReceivingBatchLedgerDialog> {
  bool _loading = true;
  List<dynamic> _ledger = [];
  final ScrollController _hScrollCtrl = ScrollController();
  final ScrollController _vScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.expiryLedger(widget.itemId));
      if (res != null && res['success'] == true) {
        setState(() {
          _ledger = res['ledger'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load batch ledger: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SOLD OUT':
      case 'SOLD_OUT':
        return const Color(0xFF64748B);
      case 'EXPIRED':
        return const Color(0xFFDC2626);
      case 'CRITICAL':
        return const Color(0xFFEA580C);
      case 'WARNING':
        return const Color(0xFFD97706);
      case 'ACTIVE':
      default:
        return const Color(0xFF16A34A);
    }
  }

  @override
  void dispose() {
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.itemName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    'Code: ${widget.itemCode}  •  Goods Receipt Batches & Shelf-Life Audit',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 920,
        height: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ledger.isEmpty
                ? const Center(
                    child: Text(
                      'No receiving batch records found for this item.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : Scrollbar(
                    controller: _hScrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _hScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      child: Scrollbar(
                        controller: _vScrollCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _vScrollCtrl,
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                          headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                          dataRowHeight: 48,
                          columnSpacing: 18,
                          columns: const [
                            DataColumn(label: Text('GRN No', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Receipt Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Batch No', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Days Left', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Recv Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Sold Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Available', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _ledger.map((row) {
                            final status = row['status'] ?? 'ACTIVE';
                            final color = _getStatusColor(status);
                            final daysLeft = row['days_left'] ?? 0;
                            final available = NumberFormat.decimalPattern().format(row['qty_available'] ?? 0);
                            final sold = NumberFormat.decimalPattern().format(row['qty_sold'] ?? 0);
                            final recv = NumberFormat.decimalPattern().format(row['qty_received'] ?? 0);
                            final isSoldOut = (row['qty_available'] ?? 0) <= 0;

                            return DataRow(
                              cells: [
                                DataCell(Text(row['grn_no'] ?? '--', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(row['receipt_date'] ?? '--')),
                                DataCell(Text(row['supplier_name'] ?? '--')),
                                DataCell(Text(row['batch_no'] ?? '--')),
                                DataCell(Text(row['expiry_date'] ?? '--', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(
                                  Text(
                                    isSoldOut ? 'Sold Out' : (daysLeft < 0 ? 'Expired' : '$daysLeft d'),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                                  ),
                                ),
                                DataCell(Text(recv)),
                                DataCell(Text(sold, style: TextStyle(color: Colors.grey.shade700))),
                                DataCell(
                                  Text(
                                    available,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !isSoldOut ? const Color(0xFF16A34A) : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${CurrencyService.symbol}${row['purchase_rate'] ?? 0}')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class ExpiryTrackerScreen extends StatefulWidget {
  const ExpiryTrackerScreen({super.key});

  @override
  State<ExpiryTrackerScreen> createState() => _ExpiryTrackerScreenState();
}

class _ExpiryTrackerScreenState extends State<ExpiryTrackerScreen> {
  bool _isLoading = false;
  String _statusFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  List<dynamic> _items = [];
  Map<String, dynamic> _summary = {
    'total_tracked': 0,
    'expired': 0,
    'critical': 0,
    'warning': 0,
    'good': 0,
    'new_shorter_than_old': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchExpiryData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchExpiryData() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{};
      if (_statusFilter != 'ALL') {
        queryParams['status'] = _statusFilter;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Failed to load expiry data')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading expiry tracker: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerExpiryAlerts() async {
    try {
      final res = await ApiClient.post(ApiEndpoints.expiryAlertsTrigger, {});
      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(res['message'] ?? 'Expiry alerts triggered and notifications created!'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger expiry alerts: $e')),
      );
    }
  }

  Future<void> _openReceivingLedger(dynamic item) async {
    final itemId = item['item_id'];
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
    switch (status) {
      case 'EXPIRED':
        return Colors.red.shade700;
      case 'CRITICAL':
        return Colors.deepOrange;
      case 'WARNING':
        return Colors.amber.shade800;
      case 'GOOD':
      default:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Receiving Expiry & Batch Tracker'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Trigger Expiry Notifications',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _triggerExpiryAlerts,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchExpiryData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary KPI Cards
          _buildSummaryCards(),

          // Filters & Search
          _buildFilterBar(),

          // Table / List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No batches found for current filters',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final it = _items[idx];
                          final status = it['expiry_status'] ?? 'GOOD';
                          final statusColor = _getStatusColor(status);
                          final days = it['days_remaining'] ?? 0;
                          final isShorterThanOld = it['expiry_comparison'] == 'NEW_SHORTER_THAN_OLD';

                          return Card(
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isShorterThanOld
                                    ? Colors.orange.shade300
                                    : (status == 'EXPIRED' ? Colors.red.shade200 : Colors.grey.shade200),
                                width: isShorterThanOld ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _openReceivingLedger(it),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                it['item_name'] ?? 'Item',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Code: ${it['item_code'] ?? '-'}  •  Batch: ${it['batch_no'] ?? '-'}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Expiry: ${it['expiry_date'] ?? 'N/A'}',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          days < 0
                                              ? 'Expired ${-days}d ago'
                                              : (days == 0 ? 'Expires today' : '$days days remaining'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Stock: ${it['current_stock'] ?? 0} ${it['unit'] ?? ''}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    if (isShorterThanOld) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade800),
                                            const SizedBox(width: 6),
                                            Text(
                                              '⚠️ New received batch has shorter expiry than older stock!',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange.shade900,
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
                                          'Click to view batch ledger →',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard('Tracked Batches', '${_summary['total_tracked'] ?? 0}', Colors.blueGrey),
            const SizedBox(width: 8),
            _buildKpiCard('Expired', '${_summary['expired'] ?? 0}', Colors.red.shade700),
            const SizedBox(width: 8),
            _buildKpiCard('Critical (<30d)', '${_summary['critical'] ?? 0}', Colors.deepOrange),
            const SizedBox(width: 8),
            _buildKpiCard('Warning (<90d)', '${_summary['warning'] ?? 0}', Colors.amber.shade800),
            const SizedBox(width: 8),
            _buildKpiCard('Shorter Expiry Alert', '${_summary['new_shorter_than_old'] ?? 0}', Colors.purple.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by item name, code or batch...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
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
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _fetchExpiryData,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Filter'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('ALL', 'All'),
                const SizedBox(width: 6),
                _filterChip('EXPIRED', 'Expired'),
                const SizedBox(width: 6),
                _filterChip('CRITICAL', 'Critical (<30d)'),
                const SizedBox(width: 6),
                _filterChip('WARNING', 'Warning (<90d)'),
                const SizedBox(width: 6),
                _filterChip('GOOD', 'Safe (>90d)'),
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
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? Colors.white : Colors.black87,
      ),
      selectedColor: Theme.of(context).primaryColor,
      onSelected: (val) {
        if (val) {
          setState(() => _statusFilter = key);
          _fetchExpiryData();
        }
      },
    );
  }
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
  Map<String, dynamic>? _itemData;

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
          _itemData = res['item'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load batch ledger: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.itemName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  'Code: ${widget.itemCode}  •  Receiving Batch Ledger',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ledger.isEmpty
                ? const Center(child: Text('No receiving records found for this item.'))
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('GRN Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Receipt No', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Batch No', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Expiry', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _ledger.map((row) {
                        return DataRow(
                          cells: [
                            DataCell(Text(row['receiving_date'] ?? '-')),
                            DataCell(Text(row['receipt_no'] ?? '-')),
                            DataCell(Text(row['supplier_name'] ?? '-')),
                            DataCell(Text(row['batch_no'] ?? '-')),
                            DataCell(Text(row['expiry_date'] ?? '-')),
                            DataCell(Text('${row['qty'] ?? 0}')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

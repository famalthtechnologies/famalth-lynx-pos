import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/reports/stock_balance_controller.dart';
import '../../core/currency/currency_service.dart';
import '../../models/reports/stock_item_model.dart';

class MobileStockBalanceSheet extends StatefulWidget {
  const MobileStockBalanceSheet({super.key});

  @override
  State<MobileStockBalanceSheet> createState() => _MobileStockBalanceSheetState();
}

class _MobileStockBalanceSheetState extends State<MobileStockBalanceSheet> {
  final StockBalanceController _ctrl = StockBalanceController();
  final TextEditingController _searchCtrl = TextEditingController();

  String _statusFilter = 'ALL'; // 'ALL', 'NEED_REORDER', 'OUT_OF_STOCK', 'HEALTHY'
  String _selectedCategory = 'ALL';

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _ctrl.load();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  List<String> get _categories {
    final cats = _ctrl.items
        .map((i) => i.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['ALL', ...cats];
  }

  List<StockItem> get _filteredItems {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _ctrl.items.where((item) {
      final matchesSearch = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.code.toLowerCase().contains(q) ||
          item.barcode.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.brand.toLowerCase().contains(q);

      final matchesCategory = _selectedCategory == 'ALL' ||
          item.category.trim().toLowerCase() == _selectedCategory.toLowerCase();

      bool matchesStatus = true;
      if (_statusFilter == 'NEED_REORDER') {
        matchesStatus = item.isNeedReorder;
      } else if (_statusFilter == 'OUT_OF_STOCK') {
        matchesStatus = item.isOutOfStock;
      } else if (_statusFilter == 'HEALTHY') {
        matchesStatus = item.isHealthy;
      }

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  int get _outOfStockCount => _ctrl.items.where((i) => i.isOutOfStock).length;
  int get _needReorderCount => _ctrl.items.where((i) => i.isNeedReorder).length;
  int get _healthyCount => _ctrl.items.where((i) => i.isHealthy).length;
  double get _totalStockValuation =>
      _ctrl.items.fold(0.0, (sum, i) => sum + (i.qty > 0 ? i.value : 0.0));

  void _shareReorderListWhatsApp() async {
    final reorderItems = _ctrl.items.where((i) => i.isNeedReorder).toList();
    if (reorderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All items are currently well-stocked above reorder thresholds!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('*LIVE REORDER & SHORTFALL ALERT*');
    buffer.writeln('Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}');
    buffer.writeln('Total Items Requiring Restock: ${reorderItems.length}\n');

    int idx = 1;
    for (final it in reorderItems) {
      buffer.writeln('$idx. *${it.name}*');
      if (it.brand.isNotEmpty) buffer.writeln('   Brand: ${it.brand}');
      if (it.code.isNotEmpty) buffer.writeln('   Code: ${it.code}');
      buffer.writeln('   Current Stock: ${it.qty.toStringAsFixed(0)} ${it.unit}');
      buffer.writeln('   Min Reorder Level: ${it.reorder.toStringAsFixed(0)} ${it.unit}');
      if (it.shortfall > 0) {
        buffer.writeln('   🚨 Required Shortfall: *${it.shortfall.toStringAsFixed(0)} ${it.unit}*');
      } else if (it.isOutOfStock) {
        buffer.writeln('   ❌ *OUT OF STOCK*');
      }
      buffer.writeln('');
      idx++;
    }

    final encoded = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('whatsapp://send?text=$encoded');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await Clipboard.setData(ClipboardData(text: buffer.toString()));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reorder list copied to clipboard!')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reorder list copied to clipboard!')),
        );
      }
    }
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
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Balance & Health',
                        style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Healthy vs unhealthy items & reorder alerts',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: textMuted),
                  onPressed: _loadData,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: textDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: _ctrl.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Executive Stock Health Metric Cards
                          _buildHealthMetricCards(),
                          const SizedBox(height: 12),

                          // 2. Interactive Filter Chips
                          _buildStatusFilterChips(),
                          const SizedBox(height: 12),

                          // 3. Search and Category Filter Bar
                          _buildSearchAndCategoryRow(),
                          const SizedBox(height: 12),

                          // 4. Items List
                          _buildItemsList(),
                        ],
                      ),
                    ),
                  ),
          ),

          // Bottom Action Bar: Share Reorder List
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share, size: 18),
                label: Text(
                  _needReorderCount > 0
                      ? 'Share Reorder List on WhatsApp ($_needReorderCount Items)'
                      : 'Share Stock Status on WhatsApp',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _shareReorderListWhatsApp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetricCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Healthy Stock',
                subtitle: 'Above min limit',
                count: '$_healthyCount',
                color: const Color(0xFF059669),
                bg: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                icon: Icons.check_circle_outline_rounded,
                onTap: () => setState(() => _statusFilter = 'HEALTHY'),
                isSelected: _statusFilter == 'HEALTHY',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                title: 'Need Reorder',
                subtitle: 'Low / Shortfall',
                count: '$_needReorderCount',
                color: const Color(0xFFD97706),
                bg: const Color(0xFFFFFBEB),
                border: const Color(0xFFFDE68A),
                icon: Icons.warning_amber_rounded,
                onTap: () => setState(() => _statusFilter = 'NEED_REORDER'),
                isSelected: _statusFilter == 'NEED_REORDER',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Out of Stock',
                subtitle: 'Zero / Negative',
                count: '$_outOfStockCount',
                color: const Color(0xFFDC2626),
                bg: const Color(0xFFFEF2F2),
                border: const Color(0xFFFECACA),
                icon: Icons.cancel_outlined,
                onTap: () => setState(() => _statusFilter = 'OUT_OF_STOCK'),
                isSelected: _statusFilter == 'OUT_OF_STOCK',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                title: 'Stock Valuation',
                subtitle: '${_ctrl.items.length} Total Items',
                count: CurrencyService.format(_totalStockValuation),
                color: const Color(0xFF2563EB),
                bg: const Color(0xFFEFF6FF),
                border: const Color(0xFFBFDBFE),
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => setState(() => _statusFilter = 'ALL'),
                isSelected: _statusFilter == 'ALL',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required String count,
    required Color color,
    required Color bg,
    required Color border,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? bg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : border, width: isSelected ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(count, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: textMuted, fontSize: 9.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    final tabs = [
      {'key': 'ALL', 'label': 'All (${_ctrl.items.length})'},
      {'key': 'NEED_REORDER', 'label': '🚨 Need Reorder ($_needReorderCount)'},
      {'key': 'OUT_OF_STOCK', 'label': '❌ Out of Stock ($_outOfStockCount)'},
      {'key': 'HEALTHY', 'label': '✅ Healthy ($_healthyCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSel = _statusFilter == t['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                t['label']!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  color: isSel ? Colors.white : textDark,
                ),
              ),
              selected: isSel,
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: Colors.white,
              side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
              onSelected: (val) {
                if (val) setState(() => _statusFilter = t['key']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchAndCategoryRow() {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 13, color: textDark),
          decoration: InputDecoration(
            hintText: 'Search by item name, barcode, code or brand...',
            hintStyle: const TextStyle(color: textMuted, fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18, color: textMuted),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: textMuted),
                    onPressed: () => _searchCtrl.clear(),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderSubtle),
            ),
          ),
        ),
        if (_categories.length > 2) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      cat == 'ALL' ? 'All Categories' : cat,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSel ? const Color(0xFF1D4ED8) : textDark,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: const Color(0xFFEFF6FF),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSel ? const Color(0xFFBFDBFE) : borderSubtle),
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemsList() {
    final list = _filteredItems;

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              _statusFilter == 'NEED_REORDER' ? Icons.task_alt_rounded : Icons.inventory_2_outlined,
              size: 48,
              color: textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              _statusFilter == 'NEED_REORDER'
                  ? 'No items currently need reordering!'
                  : 'No items match your search / filter criteria.',
              style: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final it = list[idx];
        return _buildItemCard(it);
      },
    );
  }

  Widget _buildItemCard(StockItem item) {
    Color badgeBg;
    Color badgeText;
    Color badgeBorder;
    String statusLabel;
    IconData statusIcon;

    if (item.isOutOfStock) {
      badgeBg = const Color(0xFFFEF2F2);
      badgeText = const Color(0xFFDC2626);
      badgeBorder = const Color(0xFFFECACA);
      statusLabel = 'OUT OF STOCK';
      statusIcon = Icons.cancel_rounded;
    } else if (item.isNeedReorder) {
      badgeBg = const Color(0xFFFFFBEB);
      badgeText = const Color(0xFFD97706);
      badgeBorder = const Color(0xFFFDE68A);
      statusLabel = 'NEED REORDER';
      statusIcon = Icons.warning_amber_rounded;
    } else if (item.stockStatus == 'LOW_BUFFER') {
      badgeBg = const Color(0xFFFFF7ED);
      badgeText = const Color(0xFFC2410C);
      badgeBorder = const Color(0xFFFED7AA);
      statusLabel = 'NEAR MINIMUM';
      statusIcon = Icons.info_outline_rounded;
    } else if (item.isHealthy) {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF059669);
      badgeBorder = const Color(0xFFA7F3D0);
      statusLabel = 'HEALTHY';
      statusIcon = Icons.check_circle_rounded;
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = const Color(0xFF64748B);
      badgeBorder = const Color(0xFFE2E8F0);
      statusLabel = 'NO MIN LIMIT';
      statusIcon = Icons.remove_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderSubtle),
      ),
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
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.code.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(item.code, style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
                          ),
                        if (item.category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(item.category, style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                          ),
                        if (item.brand.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(item.brand, style: const TextStyle(fontSize: 10, color: Color(0xFF7E22CE), fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: badgeText, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(color: badgeText, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Stock balance and shortfall figures
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current Stock
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Stock', style: TextStyle(color: textMuted, fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        item.qty.toStringAsFixed(0),
                        style: TextStyle(
                          color: item.isOutOfStock ? const Color(0xFFDC2626) : textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(item.unit, style: const TextStyle(color: textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),

              // Min Reorder Threshold
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Reorder Level', style: TextStyle(color: textMuted, fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Text(
                    item.reorder > 0 ? '${item.reorder.toStringAsFixed(0)} ${item.unit}' : 'No Limit',
                    style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              // Shortfall / Safety status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.shortfall > 0 ? 'Need to Order' : 'Stock Valuation',
                    style: TextStyle(
                      color: item.shortfall > 0 ? const Color(0xFFDC2626) : textMuted,
                      fontSize: 10.5,
                      fontWeight: item.shortfall > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (item.shortfall > 0)
                    Text(
                      '+${item.shortfall.toStringAsFixed(0)} ${item.unit}',
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      CurrencyService.format(item.value),
                      style: const TextStyle(color: Color(0xFF059669), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

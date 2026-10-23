import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/control_plane_storage.dart';
import '../control_plane/control_plane_login_screen.dart';
import 'data_dictionary_helper.dart';

class _GrowthTrendPoint {
  final String month;
  final int newUsers;
  final int churnUsers;
  final int activeTotal;
  _GrowthTrendPoint(this.month, this.newUsers, this.churnUsers, this.activeTotal);
}

class _StorageDoughnutPoint {
  final String category;
  final double gigabytes;
  final Color color;
  _StorageDoughnutPoint(this.category, this.gigabytes, this.color);
}

class MasterControlPlaneScreen extends StatefulWidget {
  const MasterControlPlaneScreen({super.key});

  @override
  State<MasterControlPlaneScreen> createState() => _MasterControlPlaneScreenState();
}

class _MasterControlPlaneScreenState extends State<MasterControlPlaneScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String _selectedRole = 'OWNER'; // OWNER, RESELLER, DEVELOPER, SUPPORT_LEAD

  // Fleet Overview Data
  Map<String, dynamic> _overview = {};

  // Tenants List
  List<dynamic> _tenants = [];
  String _tenantSearch = '';
  String _renewalFilter = 'ALL'; // ALL, THIS_MONTH, NEXT_MONTH, EXPIRING_SOON
  String? _selectedResellerFilter;

  String _currencySymbol(dynamic tenant) {
    if (tenant == null) return '₹';
    final cur = (tenant['currency'] ?? tenant['custom_metadata']?['currency'] ?? '').toString().toUpperCase();
    if (cur == 'USD' || cur == 'CAD' || cur == 'AUD' || cur == 'SGD') return '\$';
    if (cur == 'EUR') return '€';
    if (cur == 'GBP') return '£';
    if (cur == 'AED') return 'AED ';
    if (cur == 'INR') return '₹';
    final country = (tenant['country'] ?? tenant['custom_metadata']?['country'] ?? '').toString().toLowerCase();
    if (country.contains('united states') || country.contains('usa')) return '\$';
    return '₹';
  }

  bool _isThisMonthRenewal(dynamic t) {
    final dStr = t['next_payment_date'] ?? t['license_end_date'] ?? t['valid_till'];
    if (dStr == null) return false;
    final d = DateTime.tryParse(dStr.toString());
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  bool _isNextMonthRenewal(dynamic t) {
    final dStr = t['next_payment_date'] ?? t['license_end_date'] ?? t['valid_till'];
    if (dStr == null) return false;
    final d = DateTime.tryParse(dStr.toString());
    if (d == null) return false;
    final now = DateTime.now();
    final nextMonth = now.month == 12 ? 1 : now.month + 1;
    final nextYear = now.month == 12 ? now.year + 1 : now.year;
    return d.year == nextYear && d.month == nextMonth;
  }

  List<dynamic> get _filteredTenants {
    var list = _tenants;
    if (_tenantSearch.trim().isNotEmpty) {
      final q = _tenantSearch.trim().toLowerCase();
      list = list.where((t) {
        final name = (t['legal_name'] ?? '').toString().toLowerCase();
        final code = (t['client_code'] ?? '').toString().toLowerCase();
        final email = (t['contact_email'] ?? '').toString().toLowerCase();
        final phone = (t['contact_phone'] ?? '').toString().toLowerCase();
        final country = (t['country'] ?? t['custom_metadata']?['country'] ?? '').toString().toLowerCase();
        return name.contains(q) || code.contains(q) || email.contains(q) || phone.contains(q) || country.contains(q);
      }).toList();
    }
    if (_selectedRole == 'RESELLER' && _selectedResellerFilter != null && _selectedResellerFilter!.isNotEmpty) {
      list = list.where((t) => (t['reseller_id'] ?? '').toString() == _selectedResellerFilter).toList();
    }
    if (_renewalFilter == 'THIS_MONTH') {
      list = list.where(_isThisMonthRenewal).toList();
    } else if (_renewalFilter == 'NEXT_MONTH') {
      list = list.where(_isNextMonthRenewal).toList();
    } else if (_renewalFilter == 'EXPIRING_SOON') {
      list = list.where((t) {
        final days = t['licenseMetrics']?['daysLeft'] ?? 999;
        return days <= 30;
      }).toList();
    }
    return list;
  }

  Future<void> _exportRenewalsCsv() async {
    final filterKey = _renewalFilter == 'THIS_MONTH'
        ? 'this_month'
        : (_renewalFilter == 'NEXT_MONTH' ? 'next_month' : 'all');
    final url = '${ApiClient.baseUrl}/api/v1/control-plane/renewals/export?filter=$filterKey';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Downloading $_renewalFilter Renewals CSV Report...'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text('Could not open download URL for Renewals report.'),
          ),
        );
      }
    }
  }

  Future<void> _downloadTenantInvoice(dynamic tenant) async {
    final tenantId = tenant['id'];
    final url = '${ApiClient.baseUrl}/api/v1/control-plane/invoices/download/$tenantId?t=${DateTime.now().millisecondsSinceEpoch}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0284C7),
            content: Text('Downloading Tax Invoice for ${tenant['legal_name']}...'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text('Could not launch invoice download URL.'),
          ),
        );
      }
    }
  }

  Future<void> _openBulkIncreaseAmountDialog() async {
    String selectedMode = 'ADD_FIXED'; // ADD_FIXED, PERCENT_INCREASE, SET_FIXED
    String targetFilter = _renewalFilter == 'ALL' ? 'ALL' : _renewalFilter;
    final adjustmentController = TextEditingController(text: '500');
    final taxController = TextEditingController();
    bool alsoExtend = false;
    final daysController = TextEditingController(text: '0');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.price_change_outlined, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Text(
                'Bulk Adjust Subscription Pricing',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'By default, client license validity days remain unchanged. Only subscription fee amounts and tax rates are modified.',
                            style: TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: targetFilter,
                    decoration: const InputDecoration(
                      labelText: 'Apply Adjustment To Clients',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                    ),
                    items: [
                      DropdownMenuItem(value: 'ALL', child: Text('All Clients (${_tenants.length})')),
                      DropdownMenuItem(value: 'THIS_MONTH', child: Text('This Month Renewals (${_tenants.where(_isThisMonthRenewal).length})')),
                      DropdownMenuItem(value: 'NEXT_MONTH', child: Text('Next Month Renewals (${_tenants.where(_isNextMonthRenewal).length})')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => targetFilter = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Pricing Adjustment Mode',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ADD_FIXED', child: Text('Add Fixed Amount (+ Amount to current rate)')),
                      DropdownMenuItem(value: 'PERCENT_INCREASE', child: Text('Percentage Increase (+ % to current rate)')),
                      DropdownMenuItem(value: 'SET_FIXED', child: Text('Set Fixed Amount (New fixed rate for all)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedMode = val;
                          if (val == 'PERCENT_INCREASE') {
                            adjustmentController.text = '10';
                          } else if (val == 'ADD_FIXED') {
                            adjustmentController.text = '500';
                          } else {
                            adjustmentController.text = '4999';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: adjustmentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: selectedMode == 'PERCENT_INCREASE' ? 'Percentage % Increase (e.g. 10)' : 'Amount Adjustment (e.g. 500)',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: taxController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Override Tax % (Optional)',
                            hintText: 'Keep current',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Also extend license validity duration (Optional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    subtitle: const Text(
                      'Leave unchecked to adjust pricing ONLY without altering expiration dates',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    value: alsoExtend,
                    onChanged: (val) => setDialogState(() => alsoExtend = val ?? false),
                  ),
                  if (alsoExtend) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: daysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Extra Days to Add to Expiration (e.g. 365, 30)',
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                Navigator.pop(ctx);
                final payload = <String, dynamic>{
                  'amount_mode': selectedMode,
                  'amount_adjustment': double.tryParse(adjustmentController.text) ?? 0,
                  'filter': targetFilter.toLowerCase(),
                  'extend_validity': alsoExtend,
                  'extend_days': alsoExtend ? (int.tryParse(daysController.text) ?? 0) : 0,
                };
                if (taxController.text.trim().isNotEmpty) {
                  payload['tax_percentage'] = double.tryParse(taxController.text.trim());
                }

                final res = await ApiClient.post('/api/v1/control-plane/licenses/bulk-extend', payload);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text(res != null && res['message'] != null
                          ? res['message'].toString()
                          : 'Bulk subscription pricing updated successfully!'),
                    ),
                  );
                }
                _fetchTenants();
              },
              child: const Text('Apply Price Adjustment', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Support Tickets
  List<dynamic> _tickets = [];
  Map<String, dynamic>? _selectedTicket;
  List<dynamic> _ticketMessages = [];
  final TextEditingController _ticketChatInputController = TextEditingController();

  // Data Doctor
  final TextEditingController _sqlQueryController = TextEditingController(
    text: 'SELECT id, item_name, retail_price FROM item_master LIMIT 10;',
  );
  int? _selectedDoctorOutletId;
  String _doctorTargetTenantId = '';
  String _selectedDoctorOutletLabel = '';

  Future<void> _showDoctorOutletSearchDialog() async {
    // Collect all outlets from loaded tenants
    List<Map<String, dynamic>> allOutlets = [];
    for (final t in _tenants) {
      final tenantOutlets = (t['outlets'] as List<dynamic>?) ?? [];
      for (final o in tenantOutlets) {
        allOutlets.add({
          'id': int.tryParse(o['id']?.toString() ?? '') ?? 1,
          'outlet_code': (o['outlet_code'] ?? t['client_code'] ?? 'N/A').toString(),
          'outlet_name': (o['outlet_name'] ?? 'Main Store').toString(),
          'tenant_id': (t['id'] ?? '').toString(),
          'tenant_name': (t['legal_name'] ?? 'Unknown Business').toString(),
          'client_code': (t['client_code'] ?? 'N/A').toString(),
          'is_active': o['is_active'] ?? true,
        });
      }
      if (tenantOutlets.isEmpty) {
        allOutlets.add({
          'id': 1,
          'outlet_code': (t['client_code'] ?? 'N/A').toString(),
          'outlet_name': "${t['legal_name']} (Default Outlet)",
          'tenant_id': (t['id'] ?? '').toString(),
          'tenant_name': (t['legal_name'] ?? 'Unknown Business').toString(),
          'client_code': (t['client_code'] ?? 'N/A').toString(),
          'is_active': true,
        });
      }
    }

    String searchQuery = '';

    void applySelection(Map<String, dynamic> o) {
      if (mounted) {
        setState(() {
          _selectedDoctorOutletId = int.tryParse(o['id']?.toString() ?? '') ?? 1;
          _doctorTargetTenantId = (o['tenant_id'] ?? '').toString();
          final code = o['outlet_code'] ?? 'OUTLET';
          final name = o['tenant_name'] ?? 'Tenant';
          final id = o['id'];
          _selectedDoctorOutletLabel = "${code} - ${name} (ID: #${id})";
        });
      }
      try {
        Navigator.of(context, rootNavigator: true).pop(o);
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Selected Outlet: " + (o['outlet_code'] ?? '') + " - " + (o['tenant_name'] ?? '') + " (ID: #" + (o['id'] ?? '') + ")"),
          backgroundColor: const Color(0xFF0284C7),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setDialogState) {
          final filtered = allOutlets.where((o) {
            final q = searchQuery.toLowerCase().trim();
            if (q.isEmpty) return true;
            final code = (o['outlet_code'] ?? '').toString().toLowerCase();
            final name = (o['outlet_name'] ?? '').toString().toLowerCase();
            final tenantName = (o['tenant_name'] ?? '').toString().toLowerCase();
            final clientCode = (o['client_code'] ?? '').toString().toLowerCase();
            final idStr = (o['id'] ?? '').toString();
            return code.contains(q) || name.contains(q) || tenantName.contains(q) || clientCode.contains(q) || idStr == q;
          }).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF0284C7), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select Target Outlet for Data Doctor',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              height: 460,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by Outlet Code (e.g. OUTLET2026...), Name or Client...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF0284C7)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No matching outlets found. Try searching by Client Code or Outlet Name.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (itemCtx, i) {
                              final o = filtered[i];
                              final isSelected = _selectedDoctorOutletId?.toString() == o['id']?.toString() &&
                                  _doctorTargetTenantId == (o['tenant_id'] ?? '').toString();
                              return Material(
                                color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  mouseCursor: SystemMouseCursors.click,
                                  onTap: () => applySelection(o),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 17,
                                          backgroundColor: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                          child: Text(
                                            "#" + (o['id'] != null ? o['id'].toString() : ''),
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : const Color(0xFF334155),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      (o['tenant_name'] ?? '') + " - " + (o['outlet_name'] ?? ''),
                                                      style: const TextStyle(
                                                        color: Color(0xFF0F172A),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFEFF6FF),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                                    ),
                                                    child: Text(
                                                      "Code: " + (o['outlet_code'] ?? ''),
                                                      style: const TextStyle(
                                                        color: Color(0xFF0284C7),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                "Tenant Code: " + (o['client_code'] ?? '') + " | ID: #" + (o['id'] != null ? o['id'].toString() : ''),
                                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                            foregroundColor: isSelected ? Colors.white : const Color(0xFF0F172A),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              side: BorderSide(
                                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                          onPressed: () => applySelection(o),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isSelected) ...[
                                                const Icon(Icons.check, size: 14, color: Colors.white),
                                                const SizedBox(width: 4),
                                              ],
                                              Text(
                                                isSelected ? 'Selected' : 'Select',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
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
            ),
          );
        },
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedDoctorOutletId = int.tryParse(selected['id']?.toString() ?? '') ?? 1;
        _doctorTargetTenantId = (selected['tenant_id'] ?? '').toString();
        final code = selected['outlet_code'] ?? 'OUTLET';
        final name = selected['tenant_name'] ?? 'Tenant';
        final id = selected['id'];
        _selectedDoctorOutletLabel = "$code - $name (ID: #$id)";
      });
    }
  }
  Map<String, dynamic>? _queryResult;
  bool _isExecutingQuery = false;
  String? _queryError;

  // Diagnostic Error Analyzer
  final TextEditingController _errorAnalyzerController = TextEditingController();
  Map<String, dynamic>? _analyzerResult;
  bool _isAnalyzingError = false;

  // Relationship Managers
  List<dynamic> _rms = [];

  // Master Staff & IAM Users
  List<dynamic> _staffMembers = [];
  List<dynamic> _resellersList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final isAuth = await ControlPlaneStorage.isAuthenticated();
    if (!isAuth && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ControlPlaneLoginScreen()),
      );
    }
    if (mounted) {
      _loadAllControlPlaneData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ticketChatInputController.dispose();
    _sqlQueryController.dispose();
    _errorAnalyzerController.dispose();
    super.dispose();
  }

  Future<void> _loadAllControlPlaneData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchOverview(),
      _fetchTenants(),
      _fetchTickets(),
      _fetchRMs(),
      _fetchStaffMembers(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchStaffMembers() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/staff');
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _staffMembers = res['data']?['staff'] ?? [];
          _resellersList = res['data']?['resellers'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchOverview() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/fleet/overview');
      if (res != null && res['success'] == true && mounted) {
        setState(() => _overview = res['data'] ?? {});
      }
    } catch (_) {}
  }

  Future<void> _fetchTenants() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/tenants?search=$_tenantSearch');
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _tenants = res['data'] ?? [];
          if (_tenants.isNotEmpty && _doctorTargetTenantId.isEmpty) {
            _doctorTargetTenantId = _tenants.first['id'].toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTickets() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/support/tickets');
      if (res != null && res['success'] == true && mounted) {
        setState(() => _tickets = res['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchRMs() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/relationship-managers');
      if (res != null && res['success'] == true && mounted) {
        setState(() => _rms = res['data'] ?? []);
      }
    } catch (_) {}
  }

  // --- ACTIONS ---

  Future<void> _toggleTenantStatus(String tenantId, String currentStatus) async {
    final newStatus = currentStatus == 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE';
    try {
      final res = await ApiClient.patch(
        '/api/v1/control-plane/tenants/$tenantId/status',
        {'status': newStatus, 'reason': 'Toggled via Enterprise Master Control Panel'},
      );
      if (res != null && res['success'] == true) {
        _fetchTenants();
        _fetchOverview();
      }
    } catch (_) {}
  }

  Future<void> _openSendOfferDialog({Map<String, dynamic>? tenant}) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final linkController = TextEditingController();
    final labelController = TextEditingController(text: 'Claim Offer');
    final discountController = TextEditingController();
    String selectedType = 'OFFER'; // OFFER, UPDATE, DISCOUNT, MAINTENANCE

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tenant != null
                      ? 'Send Offer to ${tenant['legal_name']}'
                      : 'Broadcast Offer / Announcement to All Clients',
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tenant != null ? const Color(0xFFF0FDF4) : const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tenant != null ? const Color(0xFFBBF7D0) : const Color(0xFFE9D5FF)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tenant != null ? Icons.person_pin_circle_outlined : Icons.hub_outlined,
                          size: 16,
                          color: tenant != null ? const Color(0xFF16A34A) : const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tenant != null
                                ? 'Recipient: ${tenant['legal_name']} (${tenant['client_code']})'
                                : 'Recipient: Broadcast to all active client dashboards',
                            style: TextStyle(
                              color: tenant != null ? const Color(0xFF166534) : const Color(0xFF6B21A8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Announcement Type',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'OFFER', child: Text('Special Offer / Deal')),
                            DropdownMenuItem(value: 'DISCOUNT', child: Text('Renewal Discount')),
                            DropdownMenuItem(value: 'UPDATE', child: Text('New Software Update')),
                            DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance Notice')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedType = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: discountController,
                          decoration: const InputDecoration(
                            labelText: 'Discount Code (Optional)',
                            hintText: 'e.g. RENEW20',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Offer / Announcement Title',
                      hintText: 'e.g. Exclusive 20% Discount on Annual License Renewal',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Offer Message / Promotional Details',
                      hintText: 'Enter full offer details, terms, or update summary to display on client dashboard popup...',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: linkController,
                          decoration: const InputDecoration(
                            labelText: 'Clickable URL Link (Optional)',
                            hintText: 'https://...',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: labelController,
                          decoration: const InputDecoration(
                            labelText: 'Button Label',
                            hintText: 'Claim Offer',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () async {
                if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: Color(0xFFEF4444), content: Text('Please enter both title and message.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final payload = <String, dynamic>{
                  'target_tenant_id': tenant?['id'],
                  'title': titleController.text.trim(),
                  'message': messageController.text.trim(),
                  'type': selectedType,
                  'badge_text': selectedType,
                  'action_link': linkController.text.trim().isNotEmpty ? linkController.text.trim() : null,
                  'action_url': linkController.text.trim().isNotEmpty ? linkController.text.trim() : null,
                  'action_label': labelController.text.trim().isNotEmpty ? labelController.text.trim() : 'Claim Offer',
                  'discount_code': discountController.text.trim().isNotEmpty ? discountController.text.trim() : null,
                };
                final res = await ApiClient.post('/api/v1/control-plane/announcements', payload);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text(res != null && res['message'] != null
                          ? res['message'].toString()
                          : 'Offer / Announcement published successfully!'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
              label: const Text('Publish Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _modifyQuotaDialog(Map<String, dynamic> tenant) async {
    final metrics = tenant['licenseMetrics'] ?? {};
    final meta = tenant['custom_metadata'] ?? {};
    final activeLic = ((tenant['licenses'] as List<dynamic>?)?.isNotEmpty == true)
        ? (tenant['licenses'] as List<dynamic>).first
        : {};

    final terminalsController = TextEditingController(text: (metrics['maxTerminals'] ?? 3).toString());
    final outletsController = TextEditingController(text: (metrics['maxOutlets'] ?? 1).toString());

    String selectedCountry = (tenant['country'] ?? meta['country'] ?? 'United States').toString();
    String selectedCurrency = (tenant['currency'] ?? meta['currency'] ?? (selectedCountry == 'India' ? 'INR' : 'USD')).toString().toUpperCase();
    final taxNameController = TextEditingController(
      text: (meta['tax_name'] ?? (selectedCurrency == 'USD' ? 'Sales Tax' : selectedCurrency == 'INR' ? 'GST' : 'VAT')).toString(),
    );
    final amountController = TextEditingController(
      text: (activeLic['subscription_amount'] ?? (selectedCurrency == 'USD' ? 99.0 : 4999.0)).toString(),
    );
    final taxRateController = TextEditingController(
      text: (activeLic['tax_percentage'] ?? (selectedCurrency == 'USD' ? 8.25 : 18.0)).toString(),
    );

    final initialValidTill = metrics['validTill'] ?? tenant['license_end_date'] ?? activeLic['valid_till'];
    DateTime selectedValidTillDate = (initialValidTill != null)
        ? (DateTime.tryParse(initialValidTill.toString())?.toLocal() ?? DateTime.now().add(const Duration(days: 365)))
        : DateTime.now().add(const Duration(days: 365));
    final validTillController = TextEditingController(
      text: "${selectedValidTillDate.year}-${selectedValidTillDate.month.toString().padLeft(2, '0')}-${selectedValidTillDate.day.toString().padLeft(2, '0')}",
    );
    final graceController = TextEditingController(
      text: (metrics['gracePeriodDays'] ?? tenant['grace_period_days'] ?? activeLic['grace_period_days'] ?? 15).toString(),
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Modify License Quota & Billing: ${tenant['legal_name']}',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: ['United States', 'India', 'United Kingdom', 'Canada', 'Australia', 'United Arab Emirates', 'International'].contains(selectedCountry)
                              ? selectedCountry
                              : 'United States',
                          decoration: const InputDecoration(
                            labelText: 'Client Country',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'United States', child: Text('United States (USA)')),
                            DropdownMenuItem(value: 'India', child: Text('India')),
                            DropdownMenuItem(value: 'United Kingdom', child: Text('United Kingdom (UK)')),
                            DropdownMenuItem(value: 'Canada', child: Text('Canada')),
                            DropdownMenuItem(value: 'Australia', child: Text('Australia')),
                            DropdownMenuItem(value: 'United Arab Emirates', child: Text('United Arab Emirates (UAE)')),
                            DropdownMenuItem(value: 'International', child: Text('International / Other')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedCountry = val;
                                if (val == 'United States') {
                                  selectedCurrency = 'USD';
                                  taxNameController.text = 'Sales Tax';
                                  taxRateController.text = '8.25';
                                } else if (val == 'India') {
                                  selectedCurrency = 'INR';
                                  taxNameController.text = 'GST';
                                  taxRateController.text = '18.0';
                                } else if (val == 'United Kingdom') {
                                  selectedCurrency = 'GBP';
                                  taxNameController.text = 'VAT';
                                  taxRateController.text = '20.0';
                                } else if (val == 'Canada') {
                                  selectedCurrency = 'CAD';
                                  taxNameController.text = 'HST';
                                  taxRateController.text = '13.0';
                                } else if (val == 'Australia') {
                                  selectedCurrency = 'AUD';
                                  taxNameController.text = 'GST';
                                  taxRateController.text = '10.0';
                                } else if (val == 'United Arab Emirates') {
                                  selectedCurrency = 'AED';
                                  taxNameController.text = 'VAT';
                                  taxRateController.text = '5.0';
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: ['USD', 'INR', 'EUR', 'GBP', 'CAD', 'AUD', 'AED'].contains(selectedCurrency)
                              ? selectedCurrency
                              : 'USD',
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                            DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                            DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                            DropdownMenuItem(value: 'CAD', child: Text('CAD (\$)')),
                            DropdownMenuItem(value: 'AUD', child: Text('AUD (\$)')),
                            DropdownMenuItem(value: 'AED', child: Text('AED (AED)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCurrency = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taxNameController,
                          decoration: const InputDecoration(
                            labelText: 'Tax Name (e.g. Sales Tax, GST)',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: taxRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Tax Rate % (e.g. 8.25, 18.0)',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: validTillController,
                          decoration: InputDecoration(
                            labelText: 'Subscription Expiration Date',
                            hintText: 'YYYY-MM-DD',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF0284C7)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.tryParse(validTillController.text) ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2040),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    validTillController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: graceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Grace Buffer (Days)',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Quick Extend (Max 30d):', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                      ActionChip(
                        label: const Text('+7 Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        onPressed: () {
                          final cur = DateTime.tryParse(validTillController.text) ?? DateTime.now();
                          final base = cur.isAfter(DateTime.now()) ? cur : DateTime.now();
                          final ext = base.add(const Duration(days: 7));
                          setDialogState(() {
                            validTillController.text = "${ext.year}-${ext.month.toString().padLeft(2, '0')}-${ext.day.toString().padLeft(2, '0')}";
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('+15 Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        onPressed: () {
                          final cur = DateTime.tryParse(validTillController.text) ?? DateTime.now();
                          final base = cur.isAfter(DateTime.now()) ? cur : DateTime.now();
                          final ext = base.add(const Duration(days: 15));
                          setDialogState(() {
                            validTillController.text = "${ext.year}-${ext.month.toString().padLeft(2, '0')}-${ext.day.toString().padLeft(2, '0')}";
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('+30 Days (Max)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                        backgroundColor: const Color(0xFFE0F2FE),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        onPressed: () {
                          final cur = DateTime.tryParse(validTillController.text) ?? DateTime.now();
                          final base = cur.isAfter(DateTime.now()) ? cur : DateTime.now();
                          final ext = base.add(const Duration(days: 30));
                          setDialogState(() {
                            validTillController.text = "${ext.year}-${ext.month.toString().padLeft(2, '0')}-${ext.day.toString().padLeft(2, '0')}";
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Base Subscription Amount ($selectedCurrency)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: terminalsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Terminal Seats',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: outletsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Outlets Quota',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                final targetExp = DateTime.tryParse(validTillController.text.trim()) ?? DateTime.now();
                final baseExpiry = selectedValidTillDate.isAfter(DateTime.now()) ? selectedValidTillDate : DateTime.now();
                final maxAllowedDate = baseExpiry.add(const Duration(days: 30));
                if (targetExp.isAfter(maxAllowedDate.add(const Duration(hours: 12)))) {
                  final maxDateFormatted = "${maxAllowedDate.year}-${maxAllowedDate.month.toString().padLeft(2, '0')}-${maxAllowedDate.day.toString().padLeft(2, '0')}";
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 22),
                          SizedBox(width: 8),
                          Text('Extension Limit Exceeded', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      content: Text(
                        'Maximum allowable license extension is 30 days from current expiry.\n\nTarget date cannot exceed $maxDateFormatted. Please select a date within 30 days.',
                        style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                          onPressed: () => Navigator.pop(c),
                          child: const Text('OK', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final autoDue = targetExp.subtract(const Duration(days: 10));
                final autoDueStr = "${autoDue.year}-${autoDue.month.toString().padLeft(2, '0')}-${autoDue.day.toString().padLeft(2, '0')}";

                await ApiClient.post(
                  '/api/v1/control-plane/tenants/${tenant['id']}/modify-license',
                  {
                    'valid_till': validTillController.text.trim(),
                    'next_payment_date': autoDueStr,
                    'grace_period_days': int.tryParse(graceController.text) ?? 15,
                    'max_terminals': int.tryParse(terminalsController.text) ?? 3,
                    'max_outlets': int.tryParse(outletsController.text) ?? 1,
                    'country': selectedCountry,
                    'currency': selectedCurrency,
                    'tax_name': taxNameController.text.trim(),
                    'subscription_amount': double.tryParse(amountController.text),
                    'tax_percentage': double.tryParse(taxRateController.text),
                  },
                );
                _fetchTenants();
              },
              child: const Text('Save Billing & Quota', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickExtendLicenseDialog(Map<String, dynamic> tenant) async {
    final metrics = tenant['licenseMetrics'] ?? {};
    final activeLic = ((tenant['licenses'] as List<dynamic>?)?.isNotEmpty == true)
        ? (tenant['licenses'] as List<dynamic>).first
        : {};
    final initialValidTill = metrics['validTill'] ?? tenant['license_end_date'] ?? activeLic['valid_till'];
    DateTime curExpiry = (initialValidTill != null)
        ? (DateTime.tryParse(initialValidTill.toString())?.toLocal() ?? DateTime.now())
        : DateTime.now();
    final baseTime = curExpiry.isAfter(DateTime.now()) ? curExpiry : DateTime.now();
    final maxAllowedExpiry = baseTime.add(const Duration(days: 30));
    final maxAllowedDateStr = "${maxAllowedExpiry.year}-${maxAllowedExpiry.month.toString().padLeft(2, '0')}-${maxAllowedExpiry.day.toString().padLeft(2, '0')}";
    final curExpiryDateStr = "${curExpiry.year}-${curExpiry.month.toString().padLeft(2, '0')}-${curExpiry.day.toString().padLeft(2, '0')}";

    int selectedExtensionDays = 30;
    DateTime computedNewExpiry = baseTime.add(Duration(days: selectedExtensionDays));
    final manualDateController = TextEditingController(
      text: "${computedNewExpiry.year}-${computedNewExpiry.month.toString().padLeft(2, '0')}-${computedNewExpiry.day.toString().padLeft(2, '0')}",
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          DateTime? parsedInput = DateTime.tryParse(manualDateController.text.trim());
          bool isExceedingLimit = false;
          if (parsedInput != null) {
            isExceedingLimit = parsedInput.isAfter(maxAllowedExpiry.add(const Duration(hours: 12)));
          }

          // Compute due date exactly 10 days before expiry date
          DateTime effectiveExpiry = parsedInput ?? computedNewExpiry;
          DateTime computedDueDate = effectiveExpiry.subtract(const Duration(days: 10));
          String computedDueDateStr = "${computedDueDate.year}-${computedDueDate.month.toString().padLeft(2, '0')}-${computedDueDate.day.toString().padLeft(2, '0')}";

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.more_time_rounded, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extend Subscription: ${tenant['legal_name']}',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Expiry Date:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(
                              curExpiryDateStr,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Maximum Allowed (30d):', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(
                              maxAllowedDateStr,
                              style: const TextStyle(color: Color(0xFF0284C7), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Select Quick Extension (Max 30 Days):', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [7, 15, 30].map((days) {
                      final isSelected = selectedExtensionDays == days;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                              side: BorderSide(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                selectedExtensionDays = days;
                                final ext = baseTime.add(Duration(days: days));
                                manualDateController.text = "${ext.year}-${ext.month.toString().padLeft(2, '0')}-${ext.day.toString().padLeft(2, '0')}";
                              });
                            },
                            child: Text(
                              days == 30 ? '+30d (Max)' : '+${days}d',
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Or Set Exact Expiry Date (Max 30 Days from Current):', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: manualDateController,
                    style: TextStyle(
                      color: isExceedingLimit ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'YYYY-MM-DD',
                      filled: true,
                      fillColor: isExceedingLimit ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF0284C7)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: effectiveExpiry.isAfter(maxAllowedExpiry) ? maxAllowedExpiry : effectiveExpiry,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: maxAllowedExpiry,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              manualDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isExceedingLimit ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1), width: isExceedingLimit ? 1.5 : 1),
                      ),
                    ),
                    onChanged: (val) {
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  // Auto-synced Due Date & Renewal Date Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sync_alt_rounded, size: 14, color: Color(0xFF16A34A)),
                            SizedBox(width: 6),
                            Text('Auto Due & Renew Date (10d Prior):', style: TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          computedDueDateStr,
                          style: const TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  if (isExceedingLimit) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: Extension exceeds 30-day maximum limit! You cannot extend past $maxAllowedDateStr.',
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: isExceedingLimit ? const Color(0xFF94A3B8) : const Color(0xFF0284C7)),
                icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                label: const Text('Apply Extension Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  if (isExceedingLimit) {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: const Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 22),
                            SizedBox(width: 8),
                            Text('Extension Limit Exceeded', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        content: Text(
                          'Maximum allowable extension is 30 days from current expiry ($curExpiryDateStr).\n\nTarget date cannot exceed $maxAllowedDateStr. Please select an extension of 30 days or less.',
                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                        ),
                        actions: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                            onPressed: () => Navigator.pop(c),
                            child: const Text('OK', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  final expiryText = manualDateController.text.trim();
                  await ApiClient.post(
                    '/api/v1/control-plane/tenants/${tenant['id']}/modify-license',
                    {
                      'valid_till': expiryText,
                      'next_payment_date': computedDueDateStr,
                    },
                  );

                  // Instant local refresh
                  if (mounted) {
                    setState(() {
                      tenant['license_end_date'] = expiryText;
                      tenant['next_payment_date'] = computedDueDateStr;
                      metrics['validTill'] = expiryText;
                      metrics['nextPaymentDate'] = computedDueDateStr;
                      activeLic['valid_till'] = expiryText;
                      activeLic['next_payment_date'] = computedDueDateStr;
                      final dLeft = effectiveExpiry.difference(DateTime.now()).inDays;
                      metrics['daysLeft'] = dLeft < 0 ? 0 : dLeft;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('License for ${tenant['legal_name']} extended to $expiryText! Client system updated.'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  }
                  await _fetchTenants();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignRmDialog(Map<String, dynamic> tenant) async {
    String? selectedRmId = tenant['rm_id']?.toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Assign Relationship Manager to ${tenant['legal_name']}',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
          ),
          content: DropdownButtonFormField<String>(
            initialValue: selectedRmId,
            dropdownColor: const Color(0xFFF8FAFC),
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: const InputDecoration(
              labelText: 'Select Relationship Manager',
              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _rms.map<DropdownMenuItem<String>>((rm) {
              return DropdownMenuItem<String>(
                value: rm['id'].toString(),
                child: Text('${rm['full_name']} (${rm['designation']})'),
              );
            }).toList(),
            onChanged: (val) => setDialogState(() => selectedRmId = val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: selectedRmId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await ApiClient.post(
                        '/api/v1/control-plane/tenants/${tenant['id']}/assign-rm',
                        {'rm_id': selectedRmId},
                      );
                      _fetchTenants();
                    },
              child: const Text('Assign RM', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- DATA DOCTOR EXECUTION ---
  Future<void> _executeDoctorQuery() async {
    final sql = _sqlQueryController.text.trim();
    if (sql.isEmpty) return;

    if (RegExp(r'\bDELETE\b', caseSensitive: false).hasMatch(sql)) {
      setState(() {
        _queryError = 'Delete is not allowed. Delete is restricted in Data Doctor.';
        _queryResult = null;
      });
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete is not allowed. Delete is restricted in Data Doctor.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_selectedDoctorOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a target outlet (by Outlet Code or Name) before running SQL queries.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      _showDoctorOutletSearchDialog();
      return;
    }

    setState(() {
      _isExecutingQuery = true;
      _queryError = null;
      _queryResult = null;
    });

    try {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      final res = await ApiClient.post(
        '/api/v1/control-plane/support/data-doctor/execute',
        {
          'sql': sql,
          'outlet_id': _selectedDoctorOutletId,
          'tenant_id': _doctorTargetTenantId,
        },
      );

      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _queryResult = res['data'];
          _isExecutingQuery = false;
        });
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        setState(() {
          _queryError = err.toString().replaceAll('Exception: ', '');
          _isExecutingQuery = false;
        });
      }
    }
  }

  // --- DIAGNOSTIC ERROR ANALYZER ---
  Future<void> _runErrorAnalyzer() async {
    final text = _errorAnalyzerController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isAnalyzingError = true;
      _analyzerResult = null;
    });

    try {
      final res = await ApiClient.post(
        '/api/v1/control-plane/support/analyze-error',
        {'error_text': text, 'stack_trace': text},
      );
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _analyzerResult = res['data'];
          _isAnalyzingError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isAnalyzingError = false);
    }
  }

  String _getRoleTitle(String role) {
    switch (role) {
      case 'OWNER':
        return 'Software Owner Console';
      case 'RESELLER':
        return 'Reseller & Partner Portal';
      case 'DEVELOPER':
        return 'Developer & API Console';
      case 'SUPPORT_LEAD':
        return 'Support Lead / Data Doctor';
      default:
        return 'Unified SaaS Control Plane';
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'OWNER':
        final tCount = _overview['tenants']?['total'] ?? _tenants.length;
        final oCount = _overview['outlets']?['total'] ?? _tenants.length;
        return 'Full root orchestration across all ' + tCount.toString() + ' Tenants, ' + oCount.toString() + ' Outlets, IAM Staff & Master Control Infrastructure.';
      case 'RESELLER':
        return 'Partner dashboard — Managed client outlets, license quota assignments & relationship managers.';
      case 'DEVELOPER':
        return 'Technical diagnostics — Sandboxed SQL Query Studio, schema drift analyzer & outlet-scoped telemetry.';
      case 'SUPPORT_LEAD':
        return 'Live triage desk — Real-time chat with store terminals, outlet-level diagnostics & ticket resolutions.';
      default:
        return 'Enterprise multi-tenant cloud control plane.';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'OWNER':
        return const Color(0xFF2563EB); // Royal Blue
      case 'RESELLER':
        return const Color(0xFF0D9488); // Teal
      case 'DEVELOPER':
        return const Color(0xFF7C3AED); // Violet
      case 'SUPPORT_LEAD':
        return const Color(0xFFEA580C); // Warm Orange
      default:
        return const Color(0xFF0284C7);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'OWNER':
        return Icons.admin_panel_settings_rounded;
      case 'RESELLER':
        return Icons.business_center_rounded;
      case 'DEVELOPER':
        return Icons.terminal_rounded;
      case 'SUPPORT_LEAD':
        return Icons.support_agent_rounded;
      default:
        return Icons.hub_rounded;
    }
  }

  void _onRoleChanged(String? newRole) {
    if (newRole == null) return;
    setState(() => _selectedRole = newRole);

    // Smoothly animate to primary workspace for the selected role
    switch (newRole) {
      case 'OWNER':
        _tabController.animateTo(0); // Fleet Overview
        break;
      case 'RESELLER':
        _tabController.animateTo(1); // Tenants & Outlets
        break;
      case 'DEVELOPER':
        _tabController.animateTo(3); // Data Doctor (SQL Studio)
        break;
      case 'SUPPORT_LEAD':
        _tabController.animateTo(2); // Support Console (Tickets & Live Chat)
        break;
    }

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_getRoleIcon(newRole), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              'Switched to ${_getRoleTitle(newRole)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: _getRoleColor(newRole),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRoleContextRibbon() {
    final roleColor = _getRoleColor(_selectedRole);
    final roleTitle = _getRoleTitle(_selectedRole);
    final roleDesc = _getRoleDescription(_selectedRole);
    final roleIcon = _getRoleIcon(_selectedRole);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: roleColor.withValues(alpha: 0.25), width: 1.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: roleColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(roleIcon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$roleTitle: ',
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: roleDesc,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              switch (_selectedRole) {
                case 'OWNER':
                  _tabController.animateTo(0);
                  break;
                case 'RESELLER':
                  _tabController.animateTo(1);
                  break;
                case 'DEVELOPER':
                  _tabController.animateTo(3);
                  break;
                case 'SUPPORT_LEAD':
                  _tabController.animateTo(2);
                  break;
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: roleColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Focus Console View',
                    style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: roleColor, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildEnterpriseAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : Column(
              children: [
                _buildRoleContextRibbon(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildTenantsTab(),
                      _buildSupportConsoleTab(),
                      _buildDataDoctorTab(),
                      _buildRelationshipManagersTab(),
                      _buildStaffManagementTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildEnterpriseAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)]),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'FAMALTH CLOUD',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            _getRoleTitle(_selectedRole),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ],
      ),
      actions: [
        // Role Selector Dropdown (Software Owner, Reseller, Developer, Support Lead)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRole,
              dropdownColor: const Color(0xFFF8FAFC),
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
              items: const [
                DropdownMenuItem(value: 'OWNER', child: Text('Software Owner Console')),
                DropdownMenuItem(value: 'RESELLER', child: Text('Reseller / Partner Portal')),
                DropdownMenuItem(value: 'DEVELOPER', child: Text('Developer / API Console')),
                DropdownMenuItem(value: 'SUPPORT_LEAD', child: Text('Support Lead / Data Doctor')),
              ],
              onChanged: _onRoleChanged,
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
          tooltip: 'Refresh Telemetry',
          onPressed: _loadAllControlPlaneData,
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          tooltip: 'Logout Control Plane',
          onPressed: () async {
            await ControlPlaneStorage.clear();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ControlPlaneLoginScreen()),
              (route) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF0284C7),
        indicatorWeight: 3,
        labelColor: const Color(0xFF0284C7),
        unselectedLabelColor: const Color(0xFF64748B),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 18), text: 'Fleet Overview'),
          Tab(icon: Icon(Icons.apartment_rounded, size: 18), text: 'Tenants & Outlets'),
          Tab(icon: Icon(Icons.headset_mic_rounded, size: 18), text: 'Support Console'),
          Tab(icon: Icon(Icons.terminal_rounded, size: 18), text: 'Data Doctor (SQL)'),
          Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Relationship Managers'),
          Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 18), text: 'Staff & IAM Roles'),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: FLEET OVERVIEW
  // ==========================================
  Widget _buildOverviewTab() {
    final tenants = _overview['tenants'] ?? {};
    final outlets = _overview['outlets'] ?? {};
    final licenses = _overview['licenses'] ?? {};
    final tickets = _overview['supportTickets'] ?? {};
    final renewals = _overview['renewalsThisMonth'] ?? {};
    final rawTrends = (_overview['growthTrends'] as List<dynamic>?) ?? [];

    final List<_GrowthTrendPoint> trendData = rawTrends.isNotEmpty
        ? rawTrends.map((t) => _GrowthTrendPoint(
            (t['month'] ?? '').toString(),
            int.tryParse(t['newUsers']?.toString() ?? '0') ?? 0,
            int.tryParse(t['churnUsers']?.toString() ?? '0') ?? 0,
            int.tryParse(t['activeTotal']?.toString() ?? '0') ?? 0,
          )).toList()
        : [
            _GrowthTrendPoint('May 26', 1, 0, 7),
            _GrowthTrendPoint('Jun 26', 2, 0, 9),
            _GrowthTrendPoint('Jul 26', 1, 0, 10),
            _GrowthTrendPoint('Aug 26', 0, 0, 10),
            _GrowthTrendPoint('Sep 26', 1, 0, 11),
            _GrowthTrendPoint('Oct 26', 0, 0, 11),
          ];

    final List<_StorageDoughnutPoint> storageData = [
      _StorageDoughnutPoint('POS Orders & Invoices (42%)', 14.8, const Color(0xFF0284C7)),
      _StorageDoughnutPoint('Daily Automated Backups (28%)', 9.8, const Color(0xFF10B981)),
      _StorageDoughnutPoint('Catalog & Images (18%)', 6.3, const Color(0xFFF59E0B)),
      _StorageDoughnutPoint('System & Telemetry Logs (12%)', 4.2, const Color(0xFF8B5CF6)),
    ];

    final totalRev = double.tryParse((licenses['totalRevenue'] ?? 54989.0).toString()) ?? 54989.0;
    final totalPending = double.tryParse((licenses['totalPendingAmount'] ?? 0.0).toString()) ?? 0.0;
    final paidCount = licenses['paidCount'] ?? tenants['active'] ?? 11;
    final pendingCount = licenses['pendingCount'] ?? 0;
    final renewalsCount = renewals['count'] ?? _tenants.where(_isThisMonthRenewal).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Fleet Telemetry & Infrastructure Health',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Real-time operational control across all registered client properties, terminals, and licenses.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _exportRenewalsCsv,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Export Fleet Audit', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _loadAllControlPlaneData,
                icon: const Icon(Icons.refresh, color: Color(0xFF0F172A), size: 18),
                tooltip: 'Refresh Telemetry',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Primary Fleet Health Metrics
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 900;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
                children: [
                  _buildMetricCard(
                    title: 'TOTAL CLIENT TENANTS',
                    value: ((tenants['total'] ?? 0) > 0 ? tenants['total'] : (_tenants.isNotEmpty ? _tenants.length : 0)).toString(),
                    subValue: '${tenants['active'] ?? 0} Active | ${tenants['suspended'] ?? 0} Suspended',
                    icon: Icons.apartment_rounded,
                    accentColor: const Color(0xFF0284C7),
                  ),
                  _buildMetricCard(
                    title: 'ACTIVE OUTLETS',
                    value: ((outlets['total'] ?? 0) > 0 ? outlets['total'] : (_tenants.isNotEmpty ? _tenants.fold(0, (acc, t) => acc + ((t['outlets'] as List?)?.length ?? 1)) : 0)).toString(),
                    subValue: '${outlets['active'] ?? 0} Online Properties',
                    icon: Icons.storefront_rounded,
                    accentColor: const Color(0xFF10B981),
                  ),
                  _buildMetricCard(
                    title: 'WARNING ZONE LICENSES',
                    value: (licenses['inWarningZone'] ?? 0).toString(),
                    subValue: '${licenses['expired'] ?? 0} Expired Lockdowns',
                    icon: Icons.warning_amber_rounded,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                  _buildMetricCard(
                    title: 'OPEN SUPPORT TICKETS',
                    value: (tickets['open'] ?? 0).toString(),
                    subValue: 'Outlet-wise triage active',
                    icon: Icons.confirmation_number_rounded,
                    accentColor: const Color(0xFF8B5CF6),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Financial & Subscription Revenue KPIs
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monetization_on_outlined, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Subscription Financial Health & Revenue Telemetry',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL FLEET REVENUE', style: TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('₹${totalRev.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            const Text('Annual Recurring Subscriptions', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PAID ACTIVE PLANS', style: TextStyle(color: Color(0xFF0369A1), fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('$paidCount Clients', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            const Text('Full Active Licenses Paid', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: pendingCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: pendingCount > 0 ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PENDING COLLECTION', style: TextStyle(color: pendingCount > 0 ? const Color(0xFFB91C1C) : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('$pendingCount Clients', style: TextStyle(color: pendingCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Text('Amount: ₹${totalPending.toStringAsFixed(2)}', style: TextStyle(color: pendingCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B), fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _renewalFilter = 'THIS_MONTH');
                          _tabController.animateTo(1);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE9D5FF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('THIS MONTH RENEWALS', style: TextStyle(color: Color(0xFF7E22CE), fontSize: 11, fontWeight: FontWeight.bold)),
                                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF7E22CE)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('$renewalsCount Accounts', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                              const SizedBox(height: 4),
                              const Text('Click to view & export report', style: TextStyle(color: Color(0xFF9333EA), fontSize: 11)),
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
          const SizedBox(height: 24),

          // Growth Trends and Infrastructure Telemetry Graphs
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 950;
              const chartHeight = 360.0;

              final growthChartWidget = Container(
                height: chartHeight,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Month-on-Month Client Growth & Churn Velocity',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Icon(Icons.show_chart_rounded, size: 16, color: Color(0xFF0284C7)),
                            SizedBox(width: 4),
                            Text('Past 6 Months', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SfCartesianChart(
                        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                        primaryXAxis: const CategoryAxis(
                          majorGridLines: MajorGridLines(width: 0),
                        ),
                        primaryYAxis: const NumericAxis(
                          minimum: 0,
                          axisLine: AxisLine(width: 0),
                          majorTickLines: MajorTickLines(size: 0),
                        ),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: [
                          ColumnSeries<_GrowthTrendPoint, String>(
                            name: 'New Onboarded Clients',
                            dataSource: trendData,
                            xValueMapper: (d, _) => d.month,
                            yValueMapper: (d, _) => d.newUsers,
                            color: const Color(0xFF0284C7),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                          ColumnSeries<_GrowthTrendPoint, String>(
                            name: 'Deactivated / Churn',
                            dataSource: trendData,
                            xValueMapper: (d, _) => d.month,
                            yValueMapper: (d, _) => d.churnUsers,
                            color: const Color(0xFFEF4444),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                          SplineSeries<_GrowthTrendPoint, String>(
                            name: 'Total Active Fleet',
                            dataSource: trendData,
                            xValueMapper: (d, _) => d.month,
                            yValueMapper: (d, _) => d.activeTotal,
                            color: const Color(0xFF10B981),
                            width: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final telemetryWidget = Container(
                height: chartHeight,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cloud Storage & Bandwidth Telemetry',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text('Real-time', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 6,
                      child: SfCircularChart(
                        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                        series: [
                          DoughnutSeries<_StorageDoughnutPoint, String>(
                            dataSource: storageData,
                            xValueMapper: (d, _) => d.category,
                            yValueMapper: (d, _) => d.gigabytes,
                            pointColorMapper: (d, _) => d.color,
                            innerRadius: '60%',
                            dataLabelSettings: const DataLabelSettings(isVisible: false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Database Storage', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              Text('35.1 GB / 100 GB (35.1%)', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              value: 0.351,
                              minHeight: 6,
                              backgroundColor: Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                            ),
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sync Network Bandwidth', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              Text('128.5 GB / 500 GB (25.7%)', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              value: 0.257,
                              minHeight: 6,
                              backgroundColor: Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: growthChartWidget),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: telemetryWidget),
                  ],
                );
              } else {
                return Column(
                  children: [
                    growthChartWidget,
                    const SizedBox(height: 16),
                    telemetryWidget,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Quick Actions Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: Color(0xFFF59E0B)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Quick Actions: Provision new evaluation license, launch sandboxed query, or inspect real-time sync status.',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.manage_accounts_rounded, size: 16, color: Colors.white),
                  label: const Text('Manage Tenants', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () => _tabController.animateTo(2),
                  icon: const Icon(Icons.support_agent_rounded, size: 16, color: Colors.white),
                  label: const Text('Support Desk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subValue,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              Icon(icon, color: accentColor, size: 22),
            ],
          ),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
          Text(subValue, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: TENANTS & OUTLETS
  // ==========================================
  Widget _buildTenantsTab() {
    final filtered = _filteredTenants;
    final thisMonthCount = _tenants.where(_isThisMonthRenewal).length;
    final nextMonthCount = _tenants.where(_isNextMonthRenewal).length;
    final expiringCount = _tenants.where((t) => (t['licenseMetrics']?['daysLeft'] ?? 999) <= 30).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Controls: Search + Renewals Export + Bulk Price Adjust + Refresh
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  onChanged: (val) => setState(() => _tenantSearch = val),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    hintText: 'Search by client business name, code, email, phone, or country...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _exportRenewalsCsv,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Export Renewals (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openBulkIncreaseAmountDialog,
                icon: const Icon(Icons.price_change_outlined, size: 18, color: Colors.white),
                label: const Text('Bulk Adjust Pricing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openSendOfferDialog(),
                icon: const Icon(Icons.campaign_outlined, size: 18),
                label: const Text('Broadcast Offer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _fetchTenants,
                icon: const Icon(Icons.refresh, color: Color(0xFF0F172A), size: 20),
                tooltip: 'Refresh Fleet',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Renewal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('All Clients (${_tenants.length})'),
                  selected: _renewalFilter == 'ALL',
                  selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: _renewalFilter == 'ALL' ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    fontWeight: _renewalFilter == 'ALL' ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _renewalFilter = 'ALL'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('This Month Renewals ($thisMonthCount)'),
                  selected: _renewalFilter == 'THIS_MONTH',
                  selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _renewalFilter == 'THIS_MONTH' ? const Color(0xFFD97706) : const Color(0xFF64748B),
                    fontWeight: _renewalFilter == 'THIS_MONTH' ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _renewalFilter = 'THIS_MONTH'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Next Month Renewals ($nextMonthCount)'),
                  selected: _renewalFilter == 'NEXT_MONTH',
                  selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _renewalFilter == 'NEXT_MONTH' ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                    fontWeight: _renewalFilter == 'NEXT_MONTH' ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _renewalFilter = 'NEXT_MONTH'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Expiring Soon (<30d) ($expiringCount)'),
                  selected: _renewalFilter == 'EXPIRING_SOON',
                  selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: _renewalFilter == 'EXPIRING_SOON' ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                    fontWeight: _renewalFilter == 'EXPIRING_SOON' ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _renewalFilter = 'EXPIRING_SOON'),
                ),
                if (_selectedRole == 'RESELLER' && _resellersList.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedResellerFilter,
                        hint: const Text('All Partner Clients', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Partner Clients', style: TextStyle(fontSize: 12))),
                          ..._resellersList.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(
                            value: r['id'].toString(),
                            child: Text(r['company_name'] ?? 'Reseller', style: const TextStyle(fontSize: 12)),
                          )),
                        ],
                        onChanged: (val) => setState(() => _selectedResellerFilter = val),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Fleet / Clients List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            _renewalFilter != 'ALL'
                                ? 'No client accounts found matching "$_renewalFilter" renewal criteria.'
                                : 'No client accounts found.',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 1),
                      itemBuilder: (ctx, i) {
                        final tenant = filtered[i];
                        final outlets = (tenant['outlets'] as List<dynamic>?) ?? [];
                        final metrics = tenant['licenseMetrics'] ?? {};
                        final rm = tenant['relationship_manager'];
                        final reseller = tenant['reseller'];
                        final isActive = tenant['status'] == 'ACTIVE';
                        final daysLeft = metrics['daysLeft'] ?? 0;
                        final warningLevel = metrics['warningLevel'] ?? 'SAFE';
                        final curSym = _currencySymbol(tenant);

                        final activeLic = ((tenant['licenses'] as List<dynamic>?)?.isNotEmpty == true)
                            ? (tenant['licenses'] as List<dynamic>).first
                            : {};
                        final subtotal = double.tryParse((activeLic['subscription_amount'] ?? 4999.0).toString()) ?? 4999.0;
                        final taxRate = double.tryParse((activeLic['tax_percentage'] ?? (curSym == '\$' ? 8.25 : 18.0)).toString()) ?? (curSym == '\$' ? 8.25 : 18.0);
                        final taxName = tenant['custom_metadata']?['tax_name'] ?? (curSym == '\$' ? 'Sales Tax' : (curSym == '₹' ? 'GST' : 'VAT'));
                        final total = (subtotal + (subtotal * taxRate / 100)).toStringAsFixed(2);

                        final warningColor = warningLevel == 'CRITICAL_RED' || warningLevel == 'EXPIRED'
                            ? const Color(0xFFEF4444)
                            : (warningLevel == 'WARNING_AMBER' ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

                        final country = tenant['country'] ?? tenant['custom_metadata']?['country'] ?? (curSym == '\$' ? 'USA' : 'India');
                        final validTillRaw = metrics['validTill'] ?? tenant['license_end_date'] ?? activeLic['valid_till'];
                        DateTime? validTillDt = validTillRaw != null ? DateTime.tryParse(validTillRaw.toString()) : null;
                        String validTillFormatted = validTillDt != null
                            ? '${validTillDt.year}-${validTillDt.month.toString().padLeft(2, '0')}-${validTillDt.day.toString().padLeft(2, '0')}'
                            : 'N/A';

                        final nextPayment = metrics['nextPaymentDate'] ?? tenant['next_payment_date'] ?? activeLic['next_payment_date'];
                        DateTime? nextPayDt = nextPayment != null ? DateTime.tryParse(nextPayment.toString()) : null;
                        if (validTillDt != null && (nextPayDt == null || nextPayDt.isAfter(validTillDt))) {
                          nextPayDt = validTillDt.subtract(const Duration(days: 10));
                        }
                        String nextPayFormatted = nextPayDt != null
                            ? '${nextPayDt.year}-${nextPayDt.month.toString().padLeft(2, '0')}-${nextPayDt.day.toString().padLeft(2, '0')}'
                            : validTillFormatted;

                        final startRaw = metrics['softwareStartDate'] ?? tenant['software_start_date'] ?? tenant['created_at'];
                        String startDateFormatted = 'N/A';
                        if (startRaw != null) {
                          final dt = DateTime.tryParse(startRaw.toString());
                          if (dt != null) {
                            startDateFormatted = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                          }
                        }

                        final lastActRaw = metrics['lastActivity'] ?? tenant['last_activity'] ?? tenant['updated_at'];
                        String lastActivityFormatted = 'Active Today';
                        if (lastActRaw != null) {
                          final dt = DateTime.tryParse(lastActRaw.toString());
                          if (dt != null) {
                            lastActivityFormatted = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                          }
                        }

                        return ExpansionTile(
                          iconColor: const Color(0xFF0F172A),
                          collapsedIconColor: const Color(0xFF64748B),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isActive ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                              color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                tenant['legal_name'] ?? 'Client Property',
                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tenant['client_code'] ?? '',
                                  style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Country & Currency badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  '$country • $curSym',
                                  style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              // Next payment badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.event_outlined, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Due: $nextPayFormatted',
                                      style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              // License Warning Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: warningColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: warningColor, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.hourglass_bottom_rounded, size: 14, color: warningColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      daysLeft < 0 ? 'Expired (${daysLeft.abs()}d ago)' : '$daysLeft Days Left',
                                      style: TextStyle(color: warningColor, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              // Send Offer Button directly on tile header
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF8B5CF6),
                                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: const Size(0, 28),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => _openSendOfferDialog(tenant: tenant),
                                icon: const Icon(Icons.local_offer_outlined, size: 13),
                                label: const Text('Send Offer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Line 1: Plan Quota & Subscription
                                Text(
                                  'Outlets: ${outlets.length} | Seats: ${metrics['maxTerminals'] ?? 1} | Plan: $curSym$subtotal + $taxName ($taxRate%) = $curSym$total | RM: ${rm != null ? rm['full_name'] : "Unassigned"}${reseller != null ? " | Reseller: ${reseller['company_name']}" : ""}',
                                  style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 5),
                                // Line 2: Software Start Date, Renewal Date, Grace Buffer, Last Activity
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFBFDBFE))),
                                        child: Text(
                                          'Start: $startDateFormatted',
                                          style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE9D5FF))),
                                        child: Text(
                                          'Due & Renew: $nextPayFormatted',
                                          style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFECACA))),
                                        child: Text(
                                          'Expires: $validTillFormatted',
                                          style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFDE68A))),
                                        child: Text(
                                          'Grace: ${metrics['gracePeriodDays'] ?? tenant['grace_period_days'] ?? 15}d',
                                          style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFBBF7D0))),
                                        child: Text(
                                          'Last Active: $lastActivityFormatted',
                                          style: const TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                // Line 3: Email, Phone, Address & Individual Usage Metrics
                                Text(
                                  'Email: ${tenant['contact_email'] != null && tenant['contact_email'].toString().isNotEmpty ? tenant['contact_email'] : "N/A"} • Phone: ${tenant['contact_phone'] != null && tenant['contact_phone'].toString().isNotEmpty ? tenant['contact_phone'] : "N/A"} | Address: ${tenant['billing_address'] != null && tenant['billing_address'].toString().isNotEmpty ? tenant['billing_address'] : "N/A"} | Storage: ${metrics['storageMb'] != null ? "${metrics['storageMb']} MB / 10 GB" : "N/A"} | Bandwidth: ${metrics['bandwidthMb'] != null ? "${metrics['bandwidthMb']} MB / 50 GB" : "N/A"}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              color: Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section 1: License Lifecycle & Activity Telemetry (365d)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        // Start Date
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.play_circle_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                                                  SizedBox(width: 4),
                                                  Text('Software Start Date', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                metrics['softwareStartDate'] != null
                                                    ? DateTime.tryParse(metrics['softwareStartDate'].toString())?.toLocal().toString().split(' ')[0] ?? 'N/A'
                                                    : (tenant['created_at'] != null ? DateTime.tryParse(tenant['created_at'].toString())?.toLocal().toString().split(' ')[0] ?? 'N/A' : 'N/A'),
                                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const VerticalDivider(width: 20),
                                        // Renewal / Expiry Date
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.event_repeat_rounded, size: 14, color: Color(0xFF8B5CF6)),
                                                  SizedBox(width: 4),
                                                  Text('License Renewal / Due Date', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$nextPayFormatted (10d Prior)',
                                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const VerticalDivider(width: 20),
                                        // Grace Period Days
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFF59E0B)),
                                                  SizedBox(width: 4),
                                                  Text('Grace Period', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${metrics['gracePeriodDays'] ?? tenant['grace_period_days'] ?? 15} Days Buffer',
                                                style: const TextStyle(color: Color(0xFFD97706), fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const VerticalDivider(width: 20),
                                        // Last Activity (365d)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.history_rounded, size: 14, color: Color(0xFF10B981)),
                                                  SizedBox(width: 4),
                                                  Text('Last Activity', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                tenant['last_activity'] != null
                                                    ? DateTime.tryParse(tenant['last_activity'].toString())?.toLocal().toString().split('.')[0] ?? 'Active Today'
                                                    : 'Active Today',
                                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Section 2: Individual Client Usage Metrics (Storage & Bandwidth)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        // Individual Storage
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Row(
                                                    children: [
                                                      Icon(Icons.dns_outlined, size: 14, color: Color(0xFF0284C7)),
                                                      SizedBox(width: 4),
                                                      Text('Client Database Storage', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                  Text(
                                                    metrics['storageMb'] != null ? '${metrics['storageMb']} MB / 10,240 MB' : 'N/A',
                                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: metrics['storageMb'] != null ? ((metrics['storageMb'] as num) / 10240.0).clamp(0.0, 1.0) : 0.0,
                                                  minHeight: 6,
                                                  backgroundColor: const Color(0xFFE2E8F0),
                                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        // Individual Bandwidth
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Row(
                                                    children: [
                                                      Icon(Icons.swap_vert_rounded, size: 14, color: Color(0xFF10B981)),
                                                      SizedBox(width: 4),
                                                      Text('Monthly Sync Bandwidth', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                  Text(
                                                    metrics['bandwidthMb'] != null ? '${metrics['bandwidthMb']} MB / 51,200 MB' : 'N/A',
                                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: metrics['bandwidthMb'] != null ? ((metrics['bandwidthMb'] as num) / 51200.0).clamp(0.0, 1.0) : 0.0,
                                                  minHeight: 6,
                                                  backgroundColor: const Color(0xFFE2E8F0),
                                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Section 3: Client & Outlet Profile Information
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Registered Billing Address:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 3),
                                              Text(
                                                (tenant['billing_address'] != null && tenant['billing_address'].toString().isNotEmpty) ? tenant['billing_address'] : 'N/A',
                                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Contact & Tax Credentials:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Email: ${tenant['contact_email'] != null && tenant['contact_email'].toString().isNotEmpty ? tenant['contact_email'] : "N/A"}\nPhone: ${tenant['contact_phone'] != null && tenant['contact_phone'].toString().isNotEmpty ? tenant['contact_phone'] : "N/A"} | Tax ID: ${tenant['tax_identifier'] != null && tenant['tax_identifier'].toString().isNotEmpty ? tenant['tax_identifier'] : "N/A"}',
                                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Section 4: Action Buttons Row
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF8B5CF6),
                                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                                        ),
                                        onPressed: () => _openSendOfferDialog(tenant: tenant),
                                        icon: const Icon(Icons.local_offer_outlined, size: 16),
                                        label: const Text('Send Offer / Update'),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF0284C7),
                                          side: const BorderSide(color: Color(0xFF0284C7)),
                                        ),
                                        onPressed: () => _downloadTenantInvoice(tenant),
                                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                                        label: const Text('Download Tax Invoice'),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF38BDF8),
                                          side: const BorderSide(color: Color(0xFF38BDF8)),
                                        ),
                                        onPressed: () => _modifyQuotaDialog(tenant),
                                        icon: const Icon(Icons.edit_note, size: 16),
                                        label: const Text('License & Pricing Quota'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFD97706),
                                          side: const BorderSide(color: Color(0xFFD97706)),
                                        ),
                                        onPressed: () => _quickExtendLicenseDialog(tenant),
                                        icon: const Icon(Icons.more_time_rounded, size: 16),
                                        label: const Text('Extend Expiry (Max 30d)'),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF10B981),
                                          side: const BorderSide(color: Color(0xFF10B981)),
                                        ),
                                        onPressed: () => _assignRmDialog(tenant),
                                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                                        label: const Text('Assign RM'),
                                      ),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                        ),
                                        onPressed: () => _toggleTenantStatus(tenant['id'], tenant['status']),
                                        icon: Icon(isActive ? Icons.power_settings_new_rounded : Icons.check, size: 16, color: Colors.white),
                                        label: Text(
                                          isActive ? 'Remote Kill-Switch' : 'Activate Client',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Outlets List Header
                                  const Text('Registered Outlets & POS Terminals:', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  ...outlets.map<Widget>((outlet) {
                                    final outletActive = outlet['is_active'] == true;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.storefront, color: Color(0xFF38BDF8), size: 18),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${outlet['outlet_name']} (${outlet['outlet_code']})',
                                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                                            child: Text(
                                              'Machine: ${outlet['hardware_machine_id'] ?? "Standard"}',
                                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            outletActive ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                                            size: 14,
                                            color: outletActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            outletActive ? 'ACTIVE' : 'LOCKED',
                                            style: TextStyle(
                                              color: outletActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                              fontSize: 11,
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
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportConsoleTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Tickets List
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_rounded, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 10),
                        const Text(
                          'Incoming Requests',
                          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Color(0xFF64748B), size: 20),
                          onPressed: _fetchTickets,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _tickets.isEmpty
                        ? const Center(child: Text('No active support tickets.', style: TextStyle(color: Color(0xFF64748B))))
                        : ListView.separated(
                            itemCount: _tickets.length,
                            separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 1),
                            itemBuilder: (ctx, i) {
                              final t = _tickets[i];
                              final isSelected = _selectedTicket?['id'] == t['id'];
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: Colors.white,
                                title: Text(
                                  t['subject'] ?? 'Support Request',
                                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: Text(
                                  'Outlet #${t['outlet_id']} | ${t['status']} | Priority: ${t['priority']}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                ),
                                trailing: Text(
                                  t['ticket_number'] ?? '',
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontFamily: 'monospace'),
                                ),
                                onTap: () async {
                                  setState(() => _selectedTicket = t);
                                  final res = await ApiClient.get('/api/v1/control-plane/support/tickets/${t['id']}');
                                  if (res != null && res['success'] == true && mounted) {
                                    setState(() {
                                      _selectedTicket = res['data'];
                                      _ticketMessages = res['data']?['messages'] ?? [];
                                    });
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Right: Active Ticket Details & Live Chat
          Expanded(
            flex: 6,
            child: _selectedTicket == null
                ? Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text('Select an incoming ticket to inspect diagnostics and chat with the client.', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Ticket Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_selectedTicket?['ticket_number']}: ${_selectedTicket?['subject']}',
                                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      'Outlet #${_selectedTicket?['outlet_id']} | Assigned to: ${_selectedTicket?['agent']?['full_name'] ?? "Auto-Routing"}',
                                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                onPressed: () async {
                                  await ApiClient.post(
                                    '/api/v1/control-plane/support/tickets/${_selectedTicket?['id']}/resolve',
                                    {'resolution_summary': 'Resolved via Central Control Desk.'},
                                  );
                                  _fetchTickets();
                                  setState(() => _selectedTicket = null);
                                },
                                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                label: const Text('Mark Resolved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        // Chat Stream
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _ticketMessages.length,
                            itemBuilder: (ctx, i) {
                              final msg = _ticketMessages[i];
                              final isClient = msg['sender_type'] == 'CLIENT_OUTLET';
                              return Align(
                                alignment: isClient ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  constraints: const BoxConstraints(maxWidth: 400),
                                  decoration: BoxDecoration(
                                    color: isClient ? const Color(0xFFE2E8F0) : const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isClient ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        msg['sender_name'] ?? (isClient ? 'Store Terminal' : 'Support Staff'),
                                        style: TextStyle(
                                          color: isClient ? const Color(0xFF0284C7) : Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        msg['message'] ?? '',
                                        style: TextStyle(
                                          color: isClient ? const Color(0xFF0F172A) : Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Reply input
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ticketChatInputController,
                                  style: const TextStyle(color: Color(0xFF0F172A)),
                                  decoration: const InputDecoration(
                                    hintText: 'Type reply to client...',
                                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send_rounded, color: Color(0xFF0284C7)),
                                onPressed: () async {
                                  final text = _ticketChatInputController.text.trim();
                                  if (text.isEmpty) return;
                                  _ticketChatInputController.clear();
                                  final res = await ApiClient.post(
                                    '/api/v1/control-plane/support/tickets/${_selectedTicket?['id']}/messages',
                                    {'sender_type': 'SUPPORT_STAFF', 'sender_name': 'Central Support Engineer', 'message': text},
                                  );
                                  if (res != null && res['success'] == true && mounted) {
                                    setState(() => _ticketMessages.add(res['data']));
                                  }
                                },
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
    );
  }

  // ==========================================
  // TAB 4: SANDBOXED DATA DOCTOR (SQL)
  // ==========================================
  Widget _buildDataDoctorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sandboxed Data Doctor & Query Studio',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tenant-Isolated, Outlet-Scoped. Mandatory non-trivial WHERE clause strictly enforced on UPDATE and DELETE.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Schema Dictionary Button & Outlet Scope Picker
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      SystemDataDictionary.showDictionaryModal(context, (sql) {
                        setState(() {
                          _sqlQueryController.text = sql;
                        });
                        ScaffoldMessenger.of(context).removeCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Template loaded into SQL editor.'),
                            backgroundColor: Color(0xFF0284C7),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Schema & Table Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _showDoctorOutletSearchDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedDoctorOutletId != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedDoctorOutletId != null ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                          width: _selectedDoctorOutletId != null ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.store_mall_directory_rounded,
                            size: 16,
                            color: _selectedDoctorOutletId != null ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedDoctorOutletId != null
                                ? _selectedDoctorOutletLabel
                                : 'Select Target Outlet (Search Code / Name)',
                            style: TextStyle(
                              color: _selectedDoctorOutletId != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: _selectedDoctorOutletId != null ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick Support Recipes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    const Text(
                      'Common Support Query Recipes (Click to load):',
                      style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        SystemDataDictionary.showDictionaryModal(context, (sql) {
                          setState(() {
                            _sqlQueryController.text = sql;
                          });
                        });
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.search, size: 14, color: Color(0xFF0284C7)),
                          SizedBox(width: 4),
                          Text(
                            'Search All Tables & Columns',
                            style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SystemDataDictionary.commonRecipes.map((recipe) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          avatar: Icon(recipe.icon, size: 14, color: const Color(0xFF0284C7)),
                          label: Text(
                            recipe.title,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          onPressed: () {
                            setState(() {
                              _sqlQueryController.text = recipe.sql;
                            });
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Loaded Recipe: ${recipe.title}'),
                                backgroundColor: const Color(0xFF0284C7),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // SQL Editor
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _sqlQueryController,
                  maxLines: 6,
                  style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 14),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(16),
                    hintText: 'Enter SELECT or UPDATE query (DELETE is restricted)...',
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                    border: InputBorder.none,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      const Text(
                        'Guard: Mandatory WHERE verified prior to execution • DELETE strictly restricted',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                        onPressed: _isExecutingQuery ? null : _executeDoctorQuery,
                        icon: _isExecutingQuery
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.play_arrow_rounded, color: Colors.white),
                        label: const Text('Execute Query', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Error Display
          if (_queryError != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gpp_bad_rounded, color: Color(0xFFEF4444)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_queryError!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          // Success Display with Query Results Table
          if (_queryResult != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Execution Success: ${_queryResult?['rowCount']} rows affected in ${_queryResult?['durationMs']}ms',
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Scoped SQL: ${_queryResult?['sanitizedSql']}',
                    style: const TextStyle(color: Color(0xFF0284C7), fontFamily: 'monospace', fontSize: 12),
                  ),
                  // Tabular Result Set
                  _buildQueryResultTable(),
                ],
              ),
            ),
          const SizedBox(height: 32),
          // Automated Diagnostic Error Analyzer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: Color(0xFFF59E0B)),
                    SizedBox(width: 10),
                    Text(
                      'AI & Heuristic Error & Stack Trace Analyzer',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paste long query dumps, Postgres errors, or stack traces to diagnose root causes and recommended fixes.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _errorAnalyzerController,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'e.g. error: column "tax_id" does not exist at character 45...',
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                  onPressed: _isAnalyzingError ? null : _runErrorAnalyzer,
                  icon: const Icon(Icons.search_rounded, size: 16, color: Colors.black87),
                  label: const Text('Identify Error & Suggest Solution', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
                if (_analyzerResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category: ${_analyzerResult?['category']}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Root Cause: ${_analyzerResult?['rootCause']}', style: const TextStyle(color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text('Recommended Fix: ${_analyzerResult?['recommendedResolution']}', style: const TextStyle(color: Color(0xFF10B981))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryResultTable() {
    final rawData = _queryResult?['data'];
    final opType = _queryResult?['operationType'] ?? 'SELECT';

    if (rawData is! List || rawData.isEmpty) {
      if (opType != 'SELECT') {
        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              Text(
                'Mutation successfully applied: ${_queryResult?['rowCount'] ?? 0} record(s) modified in sandbox.',
                style: const TextStyle(color: Color(0xFF166534), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 18),
            SizedBox(width: 8),
            Text(
              'Query executed successfully. 0 records returned.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Extract all unique columns from all rows
    final columnsSet = <String>{};
    for (final row in rawData) {
      if (row is Map) {
        columnsSet.addAll(row.keys.map((k) => k.toString()));
      }
    }
    final columns = columnsSet.toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                const Text(
                  'Query Result Set',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '${rawData.length} rows returned',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable Data Table
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 600),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                  dataTextStyle: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  dividerThickness: 0.8,
                  columns: columns.map((col) {
                    return DataColumn(
                      label: Text(col.toUpperCase()),
                    );
                  }).toList(),
                  rows: rawData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    final rowMap = row is Map ? row : {};
                    final isEven = index % 2 == 0;

                    return DataRow(
                      color: WidgetStateProperty.all(
                        isEven ? Colors.white : const Color(0xFFF8FAFC),
                      ),
                      cells: columns.map((col) {
                        final val = rowMap[col];
                        final valStr = val == null ? 'NULL' : val.toString();
                        final isNull = val == null;

                        return DataCell(
                          Text(
                            valStr,
                            style: TextStyle(
                              color: isNull ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                              fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
                              fontWeight: isNull ? FontWeight.normal : FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: RELATIONSHIP MANAGERS
  // ==========================================
  Widget _buildRelationshipManagersTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Enterprise Relationship Managers Portfolio',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: _createRmModal,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Onboard New RM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: _rms.length,
              itemBuilder: (ctx, i) {
                final rm = _rms[i];
                final clientCount = (rm['tenants'] as List<dynamic>?)?.length ?? 0;
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF3B82F6),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rm['full_name'] ?? '', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(rm['designation'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text('Assigned Clients: $clientCount Properties', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                      Row(
                        children: [
                          Text(rm['phone'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.chat, color: Color(0xFF22C55E), size: 20),
                            onPressed: () {
                              final wa = (rm['whatsapp_number'] ?? '').toString().replaceAll('+', '').replaceAll(' ', '');
                              launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication);
                            },
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
    );
  }

  void _createRmModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final desigCtrl = TextEditingController(text: 'Senior Account Specialist');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
        title: const Text('Onboard Relationship Manager', style: TextStyle(color: Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Color(0xFF0F172A)), decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Color(0xFF64748B)))),
            TextField(controller: emailCtrl, style: const TextStyle(color: Color(0xFF0F172A)), decoration: const InputDecoration(labelText: 'Official Email', labelStyle: TextStyle(color: Color(0xFF64748B)))),
            TextField(controller: phoneCtrl, style: const TextStyle(color: Color(0xFF0F172A)), decoration: const InputDecoration(labelText: 'Phone / WhatsApp', labelStyle: TextStyle(color: Color(0xFF64748B)))),
            TextField(controller: desigCtrl, style: const TextStyle(color: Color(0xFF0F172A)), decoration: const InputDecoration(labelText: 'Designation', labelStyle: TextStyle(color: Color(0xFF64748B)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiClient.post(
                '/api/v1/control-plane/relationship-managers',
                {'full_name': nameCtrl.text, 'email': emailCtrl.text, 'phone': phoneCtrl.text, 'designation': desigCtrl.text},
              );
              _fetchRMs();
            },
            child: const Text('Create RM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 6: STAFF & IAM ROLES (Isolated Management)
  // ==========================================
  Widget _buildStaffManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identity & Access Management (IAM)',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage Control Plane staff, engineers, resellers, and operator permissions.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openCreateStaffDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Onboard Operator', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Security Isolation Callout
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.security_rounded, color: Color(0xFF0284C7), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Strict Tenant Isolation: Staff accounts here reside exclusively in master_staff_users and use isolated JWT credentials. Cashiers, waiters, and merchant store accounts cannot view or access this directory.',
                    style: TextStyle(color: Color(0xFF334155), fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Staff Cards List
          if (_staffMembers.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Text('No staff members registered.', style: TextStyle(color: Color(0xFF64748B))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _staffMembers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final staff = _staffMembers[i];
                final isActive = staff['is_active'] == true;
                final role = staff['role']?.toString() ?? 'SUPPORT_AGENT';

                Color roleBadgeColor = const Color(0xFF38BDF8);
                if (role == 'SUPER_ADMIN') roleBadgeColor = const Color(0xFFF59E0B);
                if (role == 'DEVELOPER') roleBadgeColor = const Color(0xFFA855F7);
                if (role == 'RESELLER_ADMIN') roleBadgeColor = const Color(0xFF10B981);

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF8FAFC)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: roleBadgeColor.withValues(alpha: 0.2),
                        child: Text(
                          (staff['full_name'] != null && staff['full_name'].toString().isNotEmpty)
                              ? staff['full_name'].toString()[0].toUpperCase()
                              : 'U',
                          style: TextStyle(color: roleBadgeColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  staff['full_name'] ?? 'Unknown',
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleBadgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: roleBadgeColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    role,
                                    style: TextStyle(color: roleBadgeColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIVE' : 'DEACTIVATED',
                                    style: TextStyle(
                                      color: isActive ? const Color(0xFF10B981) : Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Username: ${staff['username']}  •  Email: ${staff['email']}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                                if (staff['phone'] != null && staff['phone'].toString().isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    staff['phone'].toString(),
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Action Buttons
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                        color: const Color(0xFFF8FAFC),
                        onSelected: (action) async {
                          if (action == 'toggle') {
                            await _toggleStaffStatus(staff['id'].toString(), !isActive);
                          } else if (action == 'edit') {
                            _openEditStaffDialog(staff);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, color: Color(0xFF0284C7), size: 18),
                                SizedBox(width: 10),
                                Text('Edit Role & Access', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                                  color: isActive ? Colors.redAccent : const Color(0xFF10B981),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isActive ? 'Deactivate Operator' : 'Reactivate Operator',
                                  style: TextStyle(
                                    color: isActive ? Colors.redAccent : const Color(0xFF10B981),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _toggleStaffStatus(String staffId, bool newStatus) async {
    try {
      final res = await ApiClient.patch(
        '/api/v1/control-plane/staff/$staffId/status',
        {'is_active': newStatus},
      );
      if (res != null && res['success'] == true) {
        _fetchStaffMembers();
      }
    } catch (_) {}
  }

  void _openCreateStaffDialog() {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'SUPPORT_AGENT';
    String? selectedResellerId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Onboard Control Plane Operator', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameCtrl,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Username *',
                      labelStyle: const TextStyle(color: Color(0xFF475569)),
                      hintText: 'e.g. dev_sarah',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      labelStyle: TextStyle(color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Temporary Password *',
                      labelStyle: TextStyle(color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      labelStyle: TextStyle(color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    dropdownColor: const Color(0xFFF8FAFC),
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'IAM Role *',
                      labelStyle: TextStyle(color: Color(0xFF475569)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin (Full Root)')),
                      DropdownMenuItem(value: 'DEVELOPER', child: Text('Developer (Data Doctor & Telemetry)')),
                      DropdownMenuItem(value: 'SUPPORT_AGENT', child: Text('Support Agent (Tickets & Telemetry)')),
                      DropdownMenuItem(value: 'RESELLER_ADMIN', child: Text('Reseller Admin (Channel Partner)')),
                      DropdownMenuItem(value: 'RM', child: Text('Relationship Manager')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                  if (selectedRole == 'RESELLER_ADMIN' && _resellersList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedResellerId,
                      dropdownColor: const Color(0xFFF8FAFC),
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        labelText: 'Assign to Reseller Entity',
                        labelStyle: TextStyle(color: Color(0xFF475569)),
                      ),
                      items: _resellersList.map<DropdownMenuItem<String>>((r) {
                        return DropdownMenuItem<String>(
                          value: r['id'].toString(),
                          child: Text(r['company_name'] ?? 'Reseller'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedResellerId = val),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                if (usernameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                await ApiClient.post('/api/v1/control-plane/staff', {
                  'username': usernameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'password': passwordCtrl.text,
                  'full_name': nameCtrl.text.trim(),
                  'role': selectedRole,
                  'reseller_id': selectedResellerId,
                  'phone': phoneCtrl.text.trim(),
                });
                _fetchStaffMembers();
              },
              child: const Text('Create Operator', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditStaffDialog(Map<String, dynamic> staff) {
    String currentRole = staff['role']?.toString() ?? 'SUPPORT_AGENT';
    final nameCtrl = TextEditingController(text: staff['full_name']);
    final phoneCtrl = TextEditingController(text: staff['phone'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Edit Operator: ${staff['username']}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: currentRole,
                  dropdownColor: const Color(0xFFF8FAFC),
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Role', labelStyle: TextStyle(color: Color(0xFF64748B))),
                  items: const [
                    DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin')),
                    DropdownMenuItem(value: 'DEVELOPER', child: Text('Developer')),
                    DropdownMenuItem(value: 'SUPPORT_AGENT', child: Text('Support Agent')),
                    DropdownMenuItem(value: 'RESELLER_ADMIN', child: Text('Reseller Admin')),
                    DropdownMenuItem(value: 'RM', child: Text('Relationship Manager')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => currentRole = val);
                  },
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () async {
                Navigator.pop(ctx);
                await ApiClient.put('/api/v1/control-plane/staff/${staff['id']}', {
                  'full_name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'role': currentRole,
                });
                _fetchStaffMembers();
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}


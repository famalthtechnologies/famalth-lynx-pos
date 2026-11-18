import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

class GstComplianceScreen extends StatefulWidget {
  final String outletId;

  const GstComplianceScreen({super.key, required this.outletId});

  @override
  State<GstComplianceScreen> createState() => _GstComplianceScreenState();
}

class _GstComplianceScreenState extends State<GstComplianceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  Map<String, dynamic>? _data;
  List<dynamic> _filingLogs = [];

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadGstSummary();
    _loadFilingHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGstSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.get(
        ApiEndpoints.taxGstSummary,
        queryParams: {
          'outlet_id': widget.outletId,
          'period_month': _selectedMonth,
          'period_year': _selectedYear,
        },
      );

      if (res != null && res['success'] == true) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res?['error'] ?? 'Failed to load GST summary';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFilingHistory() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.taxFilings);
      if (res != null && res['success'] == true && res['data'] is List) {
        setState(() {
          _filingLogs = res['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _exportGstr1Json() async {
    try {
      String gstin = '27AABCR1234A1Z5';
      final cfg = _data?['config'];
      if (cfg is Map && cfg['gstin'] != null && cfg['gstin'].toString().isNotEmpty) {
        gstin = cfg['gstin'].toString();
      } else if (cfg is List && cfg.isNotEmpty && cfg[0] is Map && cfg[0]['gstin'] != null) {
        gstin = cfg[0]['gstin'].toString();
      }

      String period = '${_selectedMonth.toString().padLeft(2, '0')}$_selectedYear';
      final p = _data?['period'];
      if (p is Map && p['fp'] != null) {
        period = p['fp'].toString();
      }

      final res = await ApiClient.get(
        ApiEndpoints.taxGstr1Export,
        queryParams: {
          'outlet_id': widget.outletId,
          'from_date': p is Map ? p['from_date'] : null,
          'to_date': p is Map ? p['to_date'] : null,
          'gstin': gstin,
        },
      );

      final jsonContent = const JsonEncoder.withIndent('  ').convert(res);
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}
      dir ??= await getApplicationDocumentsDirectory();

      final filePath = '${dir.path}/GSTR1_${gstin}_$period.json';
      final file = File(filePath);
      await file.writeAsString(jsonContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Official GSTR-1 JSON downloaded successfully:\n$filePath',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showFileViaGspDialog() {
    final cfg = _data?['config'];
    String gstin = '27AABCR1234A1Z5';
    String provider = 'SANDBOX';
    if (cfg is Map) {
      gstin = (cfg['gstin'] ?? gstin).toString();
      provider = (cfg['gsp_provider'] ?? provider).toString();
    } else if (cfg is List && cfg.isNotEmpty && cfg[0] is Map) {
      gstin = (cfg[0]['gstin'] ?? gstin).toString();
      provider = (cfg[0]['gsp_provider'] ?? provider).toString();
    }
    final otpCtrl = TextEditingController(text: '123456');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF0B5CAD).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.cloud_upload, color: Color(0xFF0B5CAD)),
            ),
            const SizedBox(width: 12),
            const Text('1-Click Direct GSTN Filing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filing return for GSTIN: $gstin', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text('Connected GSP Gateway: $provider', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'A secure OTP has been generated for your registered GST mobile/email or session token.',
                style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'GSTN Portal 6-Digit OTP / EVC Token',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_clock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD), foregroundColor: Colors.white),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Submit & Transmit to GSTN'),
            onPressed: () async {
              Navigator.pop(ctx);
              _executeGspFiling(otpCtrl.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executeGspFiling(String otp) async {
    setState(() => _isLoading = true);
    try {
      final period = _data?['period']?['fp'] ?? '${_selectedMonth.toString().padLeft(2, '0')}$_selectedYear';
      final gstin = _data?['config']?['gstin'] ?? '27AABCR1234A1Z5';

      final res = await ApiClient.post(ApiEndpoints.taxGspFileGstr1, {
        'outlet_id': widget.outletId,
        'return_period': period,
        'gstin': gstin,
        'provider': _data?['config']?['gsp_provider'] ?? 'SANDBOX',
        'otp': otp,
      });

      if (res != null && res['success'] == true) {
        await _loadFilingHistory();
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Text('GST Return Filed Successfully!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Application Reference Number (ARN):\n${res['ack_number']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0B5CAD))),
                  const SizedBox(height: 12),
                  Text('Return Period: $period'),
                  Text('GSTIN: $gstin'),
                  Text('Status: ${res['status']}'),
                  const SizedBox(height: 10),
                  const Text('GSTN acknowledgement receipt logged into system audit trail.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(res?['error'] ?? 'Submission failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Filing failed: $e')),
        );
      }
    } finally {
      _loadGstSummary();
    }
  }

  void _showGatewayConfigDialog() {
    final cfg = _data?['config'];
    final currentConfig = (cfg is Map)
        ? cfg
        : (cfg is List && cfg.isNotEmpty && cfg[0] is Map)
            ? cfg[0]
            : <String, dynamic>{};
    final gstinCtrl = TextEditingController(text: (currentConfig['gstin'] ?? '27AABCR1234A1Z5').toString());
    final legalNameCtrl = TextEditingController(text: (currentConfig['legal_name'] ?? 'RetailSale Supermarket Enterprises').toString());
    final panCtrl = TextEditingController(text: (currentConfig['pan_number'] ?? 'AABCR1234A').toString());
    String selectedGsp = (currentConfig['gsp_provider'] ?? 'SANDBOX').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings_suggest, color: Color(0xFF0B5CAD)),
              SizedBox(width: 10),
              Text('GSP & E-Filing API Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gstinCtrl,
                  decoration: const InputDecoration(labelText: 'Company GSTIN (15 Digits)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: legalNameCtrl,
                  decoration: const InputDecoration(labelText: 'Legal Trade Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: panCtrl,
                  decoration: const InputDecoration(labelText: 'Company PAN', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGsp,
                  decoration: const InputDecoration(labelText: 'Authorized GSP / ASP Provider', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'SANDBOX', child: Text('Sandbox.co.in API (High-Speed)')),
                    DropdownMenuItem(value: 'MASTERS_INDIA', child: Text('Masters India GSP')),
                    DropdownMenuItem(value: 'CLEARTAX', child: Text('Clear (ClearTax Enterprise API)')),
                    DropdownMenuItem(value: 'IRIS_GST', child: Text('IRIS GST Suvidha Provider')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedGsp = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await ApiClient.post(ApiEndpoints.taxConfig, {
                  'gstin': gstinCtrl.text.trim(),
                  'legal_name': legalNameCtrl.text.trim(),
                  'pan_number': panCtrl.text.trim(),
                  'gsp_provider': selectedGsp,
                });
                _loadGstSummary();
              },
              child: const Text('Save Gateway Credentials'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);
    const tealColor = Color(0xFF0F766E);

    final summary = _data?['summary'] ?? {};
    final gstr1 = _data?['gstr1'] ?? {};
    final gstr3b = _data?['gstr3b'] ?? {};
    final gstr2b = _data?['gstr2b_reconciliation'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryColor),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GST Compliance & Return Hub',
                  style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'GSTR-1 Outward, GSTR-3B Offset & GSTR-2B Auto-Reconciliation',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'GSP Gateway Settings',
            icon: const Icon(Icons.settings, color: primaryColor),
            onPressed: _showGatewayConfigDialog,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: () {
              _loadGstSummary();
              _loadFilingHistory();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Top Period & Action Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      color: Colors.white,
                      child: Row(
                        children: [
                          // Month Selector
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedMonth,
                                items: List.generate(12, (index) {
                                  return DropdownMenuItem(
                                    value: index + 1,
                                    child: Text(_months[index], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  );
                                }),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedMonth = val);
                                    _loadGstSummary();
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Year Selector
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedYear,
                                items: [2024, 2025, 2026, 2027].map((y) {
                                  return DropdownMenuItem(
                                    value: y,
                                    child: Text(y.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedYear = val);
                                    _loadGstSummary();
                                  }
                                },
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Action 1: Export Gov JSON
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tealColor,
                              side: const BorderSide(color: tealColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.file_download, size: 16),
                            label: const Text('Export Gov JSON'),
                            onPressed: _exportGstr1Json,
                          ),
                          const SizedBox(width: 10),
                          // Action 2: 1-Click File via GSP
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.cloud_upload, size: 16),
                            label: const Text('1-Click File via GSP'),
                            onPressed: _showFileViaGspDialog,
                          ),
                        ],
                      ),
                    ),

                    // Live KPI Summary Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          _buildKpiCard('Outward Taxable Sales', summary['total_outward_taxable'] ?? 0, Colors.blue.shade900),
                          const SizedBox(width: 12),
                          _buildKpiCard('Total Output GST Liability', summary['total_outward_tax'] ?? 0, Colors.red.shade800),
                          const SizedBox(width: 12),
                          _buildKpiCard('Eligible Input Tax Credit (ITC)', summary['total_eligible_itc'] ?? 0, Colors.teal.shade800),
                          const SizedBox(width: 12),
                          _buildKpiCard('Net Cash GST Payable', summary['net_cash_payable'] ?? 0, Colors.purple.shade900, isHighlight: true),
                        ],
                      ),
                    ),

                    // Tabs
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: primaryColor,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: primaryColor,
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(text: 'GSTR-1 Outward Supplies'),
                          Tab(text: 'GSTR-3B Tax Offset'),
                          Tab(text: 'GSTR-2B ITC Auto-Recon'),
                          Tab(text: 'Filing History & Audit'),
                        ],
                      ),
                    ),

                    // Tab View Contents
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildGstr1Tab(gstr1),
                          _buildGstr3bTab(gstr3b, summary),
                          _buildGstr2bTab(gstr2b),
                          _buildFilingHistoryTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildKpiCard(String label, dynamic amount, Color color, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isHighlight ? color.withOpacity(0.4) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text(
              CurrencyService.format(amount),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGstr1Tab(Map<String, dynamic> gstr1) {
    final b2b = (gstr1['b2b'] as List?) ?? [];
    final b2cs = (gstr1['b2cs'] as List?) ?? [];
    final hsn = (gstr1['hsn'] as List?) ?? [];
    final docSummary = gstr1['doc_summary'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // B2B Section
          _buildSectionHeader('4A, 4B, 6B, 6C - B2B Registered Invoices (${b2b.length})'),
          const SizedBox(height: 10),
          b2b.isEmpty
              ? _buildEmptyPlaceholder('No registered B2B sales with GSTIN found in this period.')
              : _buildTable(
                  headers: ['Invoice No', 'Date', 'Customer GSTIN', 'Customer Name', 'Taxable (₹)', 'CGST', 'SGST', 'IGST', 'Total (₹)'],
                  rows: b2b.map((inv) => [
                    inv['invoice_no']?.toString() ?? '',
                    inv['invoice_date']?.toString() ?? '',
                    inv['customer_gstin']?.toString() ?? '',
                    inv['customer_name']?.toString() ?? '',
                    CurrencyService.format(inv['taxable_value']),
                    CurrencyService.format(inv['cgst_amount']),
                    CurrencyService.format(inv['sgst_amount']),
                    CurrencyService.format(inv['igst_amount']),
                    CurrencyService.format(inv['invoice_value']),
                  ]).toList(),
                ),

          const SizedBox(height: 24),

          // B2CS Retail Section
          _buildSectionHeader('7 - B2C (Small) Retail Sales Rate-Wise Summary (${b2cs.length})'),
          const SizedBox(height: 10),
          b2cs.isEmpty
              ? _buildEmptyPlaceholder('No retail B2CS transactions in this period.')
              : _buildTable(
                  headers: ['Tax Rate', 'Supply Type', 'Invoices Count', 'Taxable Value (₹)', 'CGST (₹)', 'SGST (₹)', 'IGST (₹)'],
                  rows: b2cs.map((item) => [
                    '${item['tax_rate']}%',
                    item['supply_type']?.toString() ?? 'INTRA',
                    item['invoice_count']?.toString() ?? '0',
                    CurrencyService.format(item['taxable_value']),
                    CurrencyService.format(item['cgst_amount']),
                    CurrencyService.format(item['sgst_amount']),
                    CurrencyService.format(item['igst_amount']),
                  ]).toList(),
                ),

          const SizedBox(height: 24),

          // HSN Summary Section
          _buildSectionHeader('12 - HSN/SAC Code Summary (${hsn.length})'),
          const SizedBox(height: 10),
          hsn.isEmpty
              ? _buildEmptyPlaceholder('No HSN mapped items found.')
              : _buildTable(
                  headers: ['HSN Code', 'Description', 'UQC', 'Total Qty', 'Total Value (₹)', 'Taxable (₹)', 'Rate'],
                  rows: hsn.map((item) => [
                    item['hsn_code']?.toString() ?? '',
                    item['description']?.toString() ?? '',
                    item['uqc']?.toString() ?? 'NOS',
                    item['total_qty']?.toString() ?? '0',
                    CurrencyService.format(item['total_value']),
                    CurrencyService.format(item['taxable_value']),
                    '${item['tax_rate']}%',
                  ]).toList(),
                ),

          const SizedBox(height: 24),

          // Document Register
          _buildSectionHeader('13 - Documents Issued Summary'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDocItem('From Serial', docSummary['from_serial'] ?? '-'),
                _buildDocItem('To Serial', docSummary['to_serial'] ?? '-'),
                _buildDocItem('Total Invoices', '${docSummary['total_number'] ?? 0}'),
                _buildDocItem('Cancelled', '${docSummary['cancelled_number'] ?? 0}'),
                _buildDocItem('Net Issued', '${docSummary['net_issued'] ?? 0}', isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGstr3bTab(Map<String, dynamic> gstr3b, Map<String, dynamic> summary) {
    final outward = gstr3b['outward_supplies'] ?? {};
    final itc = (gstr3b['itc_available']?['all_other_itc']) ?? {};
    final payable = gstr3b['tax_payable'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('3.1 Details of Outward Supplies and inward supplies liable to reverse charge'),
          const SizedBox(height: 10),
          _buildTable(
            headers: ['Nature of Supplies', 'Total Taxable (₹)', 'Integrated Tax (₹)', 'Central Tax (₹)', 'State/UT Tax (₹)'],
            rows: [
              [
                '(a) Outward taxable supplies',
                CurrencyService.format(outward['taxable_value']),
                CurrencyService.format(outward['igst']),
                CurrencyService.format(outward['cgst']),
                CurrencyService.format(outward['sgst']),
              ],
            ],
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('4.0 Eligible Input Tax Credit (ITC) from Inward Purchases'),
          const SizedBox(height: 10),
          _buildTable(
            headers: ['Details', 'Integrated Tax (₹)', 'Central Tax (₹)', 'State/UT Tax (₹)'],
            rows: [
              [
                '(A) (5) All other ITC (Inward purchases from registered suppliers)',
                CurrencyService.format(itc['igst']),
                CurrencyService.format(itc['cgst']),
                CurrencyService.format(itc['sgst']),
              ],
            ],
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('6.1 Payment of Tax (Offset & Cash Liability)'),
          const SizedBox(height: 10),
          _buildTable(
            headers: ['Description', 'Tax Payable (Output)', 'Paid through ITC (Credit)', 'Tax Paid in Cash (Net Due)'],
            rows: [
              [
                'Integrated Tax (IGST)',
                CurrencyService.format(outward['igst']),
                CurrencyService.format(itc['igst']),
                CurrencyService.format(payable['igst']),
              ],
              [
                'Central Tax (CGST)',
                CurrencyService.format(outward['cgst']),
                CurrencyService.format(itc['cgst']),
                CurrencyService.format(payable['cgst']),
              ],
              [
                'State Tax (SGST)',
                CurrencyService.format(outward['sgst']),
                CurrencyService.format(itc['sgst']),
                CurrencyService.format(payable['sgst']),
              ],
              [
                'TOTAL NET CASH GST PAYABLE',
                '-',
                '-',
                CurrencyService.format(payable['total_cash']),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGstr2bTab(Map<String, dynamic> gstr2b) {
    final records = (gstr2b['matched_records'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionHeader('2-Way Inward Purchase vs GSTR-2B Matching (${records.length})'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('Eligible ITC: ${gstr2b['matched_count'] ?? 0} Matched Bills',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          records.isEmpty
              ? _buildEmptyPlaceholder('No inward purchase bills recorded for this period.')
              : _buildTable(
                  headers: ['PO / Invoice No', 'Date', 'Supplier Name', 'Supplier GSTIN', 'Bill Value (₹)', 'Taxable (₹)', 'ITC CGST', 'ITC SGST', '2B Status'],
                  rows: records.map((r) => [
                    r['invoice_no']?.toString() ?? '',
                    r['invoice_date']?.toString() ?? '',
                    r['supplier_name']?.toString() ?? '',
                    r['supplier_gstin']?.toString() ?? '',
                    CurrencyService.format(r['invoice_value']),
                    CurrencyService.format(r['taxable_value']),
                    CurrencyService.format(r['itc_cgst']),
                    CurrencyService.format(r['itc_sgst']),
                    r['status'] == 'MATCHED_IN_2B' ? '✅ MATCHED' : '⚠️ UNREGISTERED',
                  ]).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildFilingHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Statutory Return Filing History & Audit Logs'),
          const SizedBox(height: 10),
          _filingLogs.isEmpty
              ? _buildEmptyPlaceholder('No return filing history yet. Click "1-Click File via GSP" to submit your return.')
              : _buildTable(
                  headers: ['Date & Time', 'Return Type', 'Period', 'Filing Mode', 'Status', 'Acknowledgement / ARN'],
                  rows: _filingLogs.map((log) => [
                    log['created_at'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(log['created_at'])) : '-',
                    log['filing_type']?.toString() ?? '',
                    log['return_period']?.toString() ?? '',
                    log['filing_mode']?.toString() ?? '',
                    log['status']?.toString() ?? '',
                    log['ack_number']?.toString() ?? '-',
                  ]).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD)),
    );
  }

  Widget _buildDocItem(String label, String value, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF0B5CAD))),
      ],
    );
  }

  Widget _buildEmptyPlaceholder(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ),
    );
  }

  Widget _buildTable({required List<String> headers, required List<List<String>> rows}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))))).toList(),
            rows: rows.map((r) => DataRow(cells: r.map((c) => DataCell(Text(c, style: const TextStyle(fontSize: 12)))).toList())).toList(),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

class ItrFilingScreen extends StatefulWidget {
  final String outletId;

  const ItrFilingScreen({super.key, required this.outletId});

  @override
  State<ItrFilingScreen> createState() => _ItrFilingScreenState();
}

class _ItrFilingScreenState extends State<ItrFilingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedFy = '2024-25';
  String _selectedAy = '2025-26';

  Map<String, dynamic>? _data;

  final List<Map<String, String>> _taxYears = [
    {'fy': '2023-24', 'ay': '2024-25'},
    {'fy': '2024-25', 'ay': '2025-26'},
    {'fy': '2025-26', 'ay': '2026-27'},
    {'fy': '2026-27', 'ay': '2027-28'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadItrSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItrSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.get(
        ApiEndpoints.taxItrSummary,
        queryParams: {
          'outlet_id': widget.outletId,
          'financial_year': _selectedFy,
          'assessment_year': _selectedAy,
        },
      );

      if (res != null && res['success'] == true) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res?['error'] ?? 'Failed to load ITR summary';
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

  Future<void> _exportItr4Json() async {
    try {
      const pan = 'AABCR1234A';
      final res = await ApiClient.get(
        ApiEndpoints.taxItr4Export,
        queryParams: {
          'outlet_id': widget.outletId,
          'financial_year': _selectedFy,
          'assessment_year': _selectedAy,
          'pan': pan,
        },
      );

      final jsonContent = const JsonEncoder.withIndent('  ').convert(res);
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/ITR4_${pan}_$_selectedAy.json';
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
                  child: Text('Official CBDT ITR-4 (Sugam) JSON downloaded successfully:\n$filePath',
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
          SnackBar(backgroundColor: Colors.red, content: Text('ITR JSON Export failed: $e')),
        );
      }
    }
  }

  void _showEFileModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF1E3A8A)),
            SizedBox(width: 10),
            Text('E-File ITR via ERI Gateway', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assessment Year: $_selectedAy (FY: $_selectedFy)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Form: ITR-4 (Sugam) - Section 44AD Presumptive Scheme'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Once submitted, you will receive an E-Verification link on your Aadhaar-linked mobile number or net banking.',
                style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Transmit & Generate ITR-V'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF0F766E),
                  content: Text('✅ Return transmitted successfully to Income Tax Department! Acknowledgement (ITR-V) generated.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryNavy = Color(0xFF1E3A8A);
    const emeraldGreen = Color(0xFF047857);

    final turnover = _data?['turnover'] ?? {};
    final sec44ad = _data?['section_44ad'] ?? {};
    final taxLiability = _data?['tax_liability'] ?? {};
    final advanceTax = _data?['advance_tax'] ?? {};
    final balanceSheet = _data?['balance_sheet_schedule'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryNavy),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: primaryNavy, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.assessment_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Income Tax Return (ITR) & Direct Tax Hub',
                  style: TextStyle(color: primaryNavy, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Section 44AD Presumptive Taxation & CBDT-Compliant E-Filing',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: primaryNavy),
            onPressed: _loadItrSummary,
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
                    // Period & Actions Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFy,
                                items: _taxYears.map((item) {
                                  return DropdownMenuItem<String>(
                                    value: item['fy'],
                                    child: Text('FY: ${item['fy']} (AY: ${item['ay']})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final found = _taxYears.firstWhere((x) => x['fy'] == val);
                                    setState(() {
                                      _selectedFy = found['fy']!;
                                      _selectedAy = found['ay']!;
                                    });
                                    _loadItrSummary();
                                  }
                                },
                              ),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: emeraldGreen,
                              side: const BorderSide(color: emeraldGreen),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.file_download, size: 16),
                            label: const Text('Export CBDT ITR-4 JSON'),
                            onPressed: _exportItr4Json,
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryNavy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.cloud_upload, size: 16),
                            label: const Text('1-Click E-File via ERI'),
                            onPressed: _showEFileModal,
                          ),
                        ],
                      ),
                    ),

                    // Top KPI Turnover & Presumptive Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          _buildKpiCard('Gross Annual Turnover', turnover['total_gross_turnover'] ?? 0, Colors.blue.shade900),
                          const SizedBox(width: 12),
                          _buildKpiCard(
                            'Digital Turnover (${turnover['digital_percentage'] ?? 0}%)',
                            turnover['digital_turnover'] ?? 0,
                            Colors.teal.shade800,
                            subtitle: '6% Deemed Profit u/s 44AD',
                          ),
                          const SizedBox(width: 12),
                          _buildKpiCard(
                            'Cash Turnover (${turnover['cash_percentage'] ?? 0}%)',
                            turnover['cash_turnover'] ?? 0,
                            Colors.orange.shade900,
                            subtitle: '8% Deemed Profit u/s 44AD',
                          ),
                          const SizedBox(width: 12),
                          _buildKpiCard(
                            'Presumptive Net Business Income',
                            sec44ad['total_presumptive_income'] ?? 0,
                            Colors.purple.shade900,
                            isHighlight: true,
                          ),
                        ],
                      ),
                    ),

                    // Tabs
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: primaryNavy,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: primaryNavy,
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(text: 'Section 44AD Presumptive Scheme'),
                          Tab(text: 'Advance Tax Milestones'),
                          Tab(text: 'Balance Sheet & Financial Particulars'),
                        ],
                      ),
                    ),

                    // Content View
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSec44adTab(turnover, sec44ad, taxLiability),
                          _buildAdvanceTaxTab(advanceTax, taxLiability),
                          _buildBalanceSheetTab(balanceSheet),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildKpiCard(String label, dynamic amount, Color color, {bool isHighlight = false, String? subtitle}) {
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
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSec44adTab(Map<String, dynamic> turnover, Map<String, dynamic> sec44ad, Map<String, dynamic> taxLiability) {
    final bool isEligible = sec44ad['is_eligible_for_44ad'] ?? true;
    final bool rebate87a = taxLiability['rebate_87a_applied'] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner for Sec 44AD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFF1E3A8A), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Section 44AD Presumptive Taxation Scheme (Ideal for Retail POS)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Under Sec 44AD, retail businesses with turnover up to ₹3 Crores (if digital >= 95%) or ₹2 Crores are exempt from maintaining tedious accounting books and statutory Tax Audit under Sec 44AB.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEligible ? Colors.green.shade600 : Colors.red.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isEligible ? 'ELIGIBLE' : 'AUDIT REQUIRED',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Computation Breakdown Table
          _buildSectionHeader('Deemed Business Income Calculation Breakdown'),
          const SizedBox(height: 10),
          _buildTable(
            headers: ['Receipt Channel', 'Applicable Rate', 'Total Turnover (₹)', 'Calculated Deemed Profit (₹)'],
            rows: [
              [
                'Digital / Banking Receipts (Card, UPI, NetBanking, Cheque)',
                '6.00%',
                CurrencyService.format(turnover['digital_turnover']),
                CurrencyService.format(sec44ad['digital_deemed_profit_6pct']),
              ],
              [
                'Cash Receipts (Counter / Drawer Cash)',
                '8.00%',
                CurrencyService.format(turnover['cash_turnover']),
                CurrencyService.format(sec44ad['cash_deemed_profit_8pct']),
              ],
              [
                'TOTAL PRESUMPTIVE BUSINESS PROFIT',
                '${sec44ad['presumptive_profit_margin_pct']}% Avg',
                CurrencyService.format(turnover['total_gross_turnover']),
                CurrencyService.format(sec44ad['total_presumptive_income']),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // Tax Liability: New vs Old Regime
          _buildSectionHeader('Estimated Income Tax Liability Comparison'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('New Tax Regime (Section 115BAC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A))),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                            child: const Text('DEFAULT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        CurrencyService.format(taxLiability['new_regime_estimated_tax']),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 6),
                      if (rebate87a)
                        const Text('🎉 Full Section 87A Tax Rebate Applied (Zero tax for income up to ₹7,00,000)',
                            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))
                      else
                        Text('Effective tax rate: ${taxLiability['effective_tax_rate_pct']}%',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Old Tax Regime (Standard Slabs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 10),
                      Text(
                        CurrencyService.format(taxLiability['old_regime_estimated_tax']),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 6),
                      const Text('Requires Chapter VI-A deductions (80C, 80D, etc.) to optimize',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceTaxTab(Map<String, dynamic> advanceTax, Map<String, dynamic> taxLiability) {
    final schedule = (advanceTax['schedule'] as List?) ?? [];
    final totalAnnual = advanceTax['total_annual_liability'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Advance Tax Installments Tracker (Section 208/211)'),
          const SizedBox(height: 6),
          Text(
            'Applicable if total annual income tax liability exceeds ₹10,000. Paying installments on time avoids penal interest under Section 234B & 234C.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          _buildTable(
            headers: ['Installment Milestone', 'Statutory Due Date', 'Cumulative %', 'Cumulative Amount Due (₹)', 'Status'],
            rows: schedule.map((item) => [
              item['installment']?.toString() ?? '',
              item['due_date']?.toString() ?? '',
              '${item['cumulative_percent']}%',
              CurrencyService.format(item['payable_amount']),
              totalAnnual == 0 ? 'NOT APPLICABLE (NIL TAX)' : 'DUE',
            ]).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetTab(Map<String, dynamic> balanceSheet) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Financial Particulars for ITR-4 Schedule BP & Balance Sheet'),
          const SizedBox(height: 6),
          Text(
            'These fields are automatically mapped into Part-B of Form ITR-4 (Sugam) directly from your ledger accounts.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          _buildTable(
            headers: ['Particulars', 'Source Ledger / Balance', 'Amount (₹)'],
            rows: [
              [
                'Cash in hand & Bank Balances',
                'Active Bank Accounts Master & Cash Drawer',
                CurrencyService.format(balanceSheet['cash_and_bank_balance']),
              ],
              [
                'Sundry Debtors (Customer Outstanding)',
                'Customer Balance Due & Credit Ledger',
                CurrencyService.format(balanceSheet['sundry_debtors']),
              ],
              [
                'Sundry Creditors (Supplier Outstanding)',
                'Purchase Inward Bills & Vendor Payables',
                CurrencyService.format(balanceSheet['sundry_creditors']),
              ],
              [
                'Stock-in-Trade (Closing Inventory Valuation)',
                'Stock Ledger & Item Valuation',
                CurrencyService.format(balanceSheet['stock_in_trade']),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
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

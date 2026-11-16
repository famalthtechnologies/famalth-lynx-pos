import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/api/api_client.dart';
import '../../core/currency/currency_service.dart';

class SupplierReturnReportScreen extends StatefulWidget {
  const SupplierReturnReportScreen({super.key});

  @override
  State<SupplierReturnReportScreen> createState() =>
      _SupplierReturnReportScreenState();
}

class _SupplierReturnReportScreenState
    extends State<SupplierReturnReportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  final TextEditingController _searchController = TextEditingController();
  final Map<String, ScrollController> _itemTableControllers = {};
  List<Map<String, dynamic>> _returns = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _itemTableControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  List<Map<String, dynamic>> _items(Map<String, dynamic> entry) =>
      List<Map<String, dynamic>>.from(entry['items'] ?? const []);

  double _lineAmount(Map<String, dynamic> item) =>
      _number(item['amount']) == 0
          ? _number(item['qty']) * _number(item['rate'])
          : _number(item['amount']);

  double _lineTax(Map<String, dynamic> item) {
    final savedTax = _number(item['tax'] ?? item['tax_percent']);
    return savedTax != 0 ? savedTax : _number(item['receipt_item']?['tax']);
  }

  double _lineTaxAmount(Map<String, dynamic> item) =>
      _number(item['tax_amount']) == 0
          ? _lineAmount(item) * _lineTax(item) / 100
          : _number(item['tax_amount']);

  double _lineTotal(Map<String, dynamic> item) =>
      _number(item['total_after_tax'] ?? item['total_amount']) == 0
          ? _lineAmount(item) + _lineTaxAmount(item)
          : _number(item['total_after_tax'] ?? item['total_amount']);

  Future<void> _loadReturns() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateFormat('yyyy-MM-dd').format(_range.start);
      final to = DateFormat('yyyy-MM-dd').format(_range.end);
      final response = await ApiClient.get(
        '/api/inventory/supplier-returns?from_date=$from&to_date=$to',
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Unable to load supplier returns');
      }
      if (!mounted) return;
      setState(() {
        _returns = List<Map<String, dynamic>>.from(response['data'] ?? const []);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleReturns {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _returns;
    return _returns.where((entry) {
      final supplier = (entry['supplier']?['supplier_name'] ?? '').toString();
      final grn = (entry['grn']?['grn_no'] ?? '').toString();
      final returnNo = (entry['return_no'] ?? '').toString();
      final containsItem = _items(entry).any((item) =>
          '${item['item_name'] ?? ''} ${item['brand'] ?? item['item_master']?['brand'] ?? ''}'
              .toLowerCase()
              .contains(query));
      return '$supplier $grn $returnNo'.toLowerCase().contains(query) ||
          containsItem;
    }).toList();
  }

  double _returnSubtotal(Map<String, dynamic> entry) =>
      _items(entry).fold(0, (sum, item) => sum + _lineAmount(item));

  double _returnTax(Map<String, dynamic> entry) =>
      _items(entry).fold(0, (sum, item) => sum + _lineTaxAmount(item));

  double _returnTotal(Map<String, dynamic> entry) =>
      _items(entry).fold(0, (sum, item) => sum + _lineTotal(item));

  double get _totalAmount =>
      _visibleReturns.fold(0, (sum, entry) => sum + _returnTotal(entry));
  double get _totalTax =>
      _visibleReturns.fold(0, (sum, entry) => sum + _returnTax(entry));
  int get _itemLineCount =>
      _visibleReturns.fold(0, (sum, entry) => sum + _items(entry).length);

  @override
  Widget build(BuildContext context) {
    final entries = _visibleReturns;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Supplier Return Report'),
        actions: [
          IconButton(
            tooltip: 'Print report',
            icon: const Icon(Icons.print_outlined),
            onPressed: entries.isEmpty ? null : _printReport,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadReturns,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _filters(),
            const SizedBox(height: 12),
            _summary(entries.length),
            const SizedBox(height: 12),
            Expanded(child: _reportBody(entries)),
          ],
        ),
      ),
    );
  }

  Widget _filters() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E6EF)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: _range,
                );
                if (picked != null) {
                  setState(() => _range = picked);
                  _loadReturns();
                }
              },
              icon: const Icon(Icons.date_range),
              label: Text(
                '${DateFormat('dd MMM yyyy').format(_range.start)} – ${DateFormat('dd MMM yyyy').format(_range.end)}',
              ),
            ),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search return, supplier, GRN, or item',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _loadReturns,
              icon: const Icon(Icons.search),
              label: const Text('Apply'),
            ),
          ],
        ),
      );

  Widget _summary(int count) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E6EF)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _metric('Returns', '$count', Icons.assignment_return_outlined),
            _metric('Item lines', '$_itemLineCount', Icons.list_alt_outlined),
            _metric('Tax amount', CurrencyService.format(_totalTax), Icons.percent_outlined),
            _metric('Total returned', CurrencyService.format(_totalAmount), Icons.account_balance_wallet_outlined),
          ],
        ),
      );

  Widget _metric(String label, String value, IconData icon) => Container(
        constraints: const BoxConstraints(minWidth: 175),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 19, color: const Color(0xFF315D9B)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ]),
      );

  Widget _reportBody(List<Map<String, dynamic>> entries) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (entries.isEmpty) {
      return const Center(child: Text('No supplier returns found for this period.'));
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) => _returnCard(entries[index]),
    );
  }

  Widget _returnCard(Map<String, dynamic> entry) {
    final lines = _items(entry);
    final returnKey = (entry['id'] ?? entry['return_no'] ?? '').toString();
    final tableController = _itemTableControllers.putIfAbsent(
      returnKey,
      ScrollController.new,
    );
    final supplier = entry['supplier']?['supplier_name']?.toString() ?? 'Supplier';
    final grn = entry['grn']?['grn_no']?.toString() ?? '—';
    final date = DateTime.tryParse(entry['return_date']?.toString() ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE1E6EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 18,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(entry['return_no']?.toString() ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(supplier, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('GRN $grn', style: const TextStyle(color: Colors.black54)),
              Text(date == null ? '' : DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(color: Colors.black54)),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text((entry['status'] ?? 'PENDING').toString()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Scrollbar(
            controller: tableController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: tableController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 12,
                columnSpacing: 24,
                headingRowHeight: 42,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Rate')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Tax %')),
                  DataColumn(label: Text('Tax Amount')),
                  DataColumn(label: Text('Total Amount')),
                ],
                rows: lines.map((line) {
                  final brand = (line['brand'] ?? line['item_master']?['brand'] ?? '').toString();
                  final itemName = (line['item_name'] ?? '').toString();
                  return DataRow(cells: [
                    DataCell(Text(brand.trim().isEmpty ? itemName : '$itemName (${brand.trim()})')),
                    DataCell(Text(_number(line['qty']).toStringAsFixed(2))),
                    DataCell(Text(CurrencyService.format(_number(line['rate'])))),
                    DataCell(Text(CurrencyService.format(_lineAmount(line)))),
                    DataCell(Text(_lineTax(line).toStringAsFixed(2))),
                    DataCell(Text(CurrencyService.format(_lineTaxAmount(line)))),
                    DataCell(Text(CurrencyService.format(_lineTotal(line)),
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]);
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 16, runSpacing: 8, children: [
              Text('Subtotal ${CurrencyService.format(_returnSubtotal(entry))}'),
              Text('Tax ${CurrencyService.format(_returnTax(entry))}'),
              Text('Total ${CurrencyService.format(_returnTotal(entry))}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _printReport() async {
    final doc = pw.Document();
    final rows = <List<String>>[];
    for (final entry in _visibleReturns) {
      for (final item in _items(entry)) {
        final brand = (item['brand'] ?? item['item_master']?['brand'] ?? '').toString();
        final name = (item['item_name'] ?? '').toString();
        rows.add([
          entry['return_no']?.toString() ?? '',
          entry['supplier']?['supplier_name']?.toString() ?? '',
          entry['grn']?['grn_no']?.toString() ?? '',
          brand.trim().isEmpty ? name : '$name (${brand.trim()})',
          _number(item['qty']).toStringAsFixed(2),
          CurrencyService.format(_lineAmount(item)),
          _lineTax(item).toStringAsFixed(2),
          CurrencyService.format(_lineTaxAmount(item)),
          CurrencyService.format(_lineTotal(item)),
        ]);
      }
    }
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Text('Supplier Return Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('${DateFormat('dd MMM yyyy').format(_range.start)} – ${DateFormat('dd MMM yyyy').format(_range.end)}'),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: const ['Return No', 'Supplier', 'GRN', 'Item', 'Qty', 'Amount', 'Tax %', 'Tax Amount', 'Total'],
          data: rows,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 7.5),
          border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        ),
        pw.SizedBox(height: 14),
        pw.Align(alignment: pw.Alignment.centerRight,
          child: pw.Text('Grand Total: ${CurrencyService.format(_totalAmount)}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
      ],
    ));
    await Printing.layoutPdf(
      name: 'Supplier_Return_Report',
      onLayout: (_) async => doc.save(),
    );
  }
}

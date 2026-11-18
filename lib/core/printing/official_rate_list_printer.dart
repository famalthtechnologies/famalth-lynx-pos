import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings/property_info_controller.dart';
import '../../models/common/property_info_model.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/item_model.dart';
import '../../utils/branding_storage.dart';
import 'pos_invoice_printer.dart';

/// Official Rate List / Price Schedule generator and printer.
/// Designed for statutory inspections (Legal Metrology, Food Safety, Price Control Officers)
/// and routine public tariff verification.
class OfficialRateListPrinter {
  OfficialRateListPrinter._();

  /// Prompt the user to choose print format and data scope, then layout the rate list.
  static Future<void> showPrintOptionsDialog({
    required BuildContext context,
    List<Item>? currentItems,
    String? currentCategory,
  }) async {
    String formatChoice = 'A4'; // 'A4' or '80MM'
    String scopeChoice = (currentItems != null && currentItems.isNotEmpty) ? 'ALL' : 'ALL';
    bool isGenerating = false;

    PropertyInfo? prop;
    try {
      final propCtrl = Provider.of<PropertyInfoController>(context, listen: false);
      prop = propCtrl.data;
    } catch (_) {}

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.print_rounded, color: Color(0xFF2563EB), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Print Store Rate List',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  const Text(
                    'Store price schedule of goods. Ready to print for customer viewing or official verification.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Format selection
                  const Text(
                    'SELECT PRINT FORMAT',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setModalState(() => formatChoice = 'A4'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: formatChoice == 'A4' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: formatChoice == 'A4' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                width: formatChoice == 'A4' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.description_rounded,
                                  color: formatChoice == 'A4' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  size: 26,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'A4 Official Document',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: formatChoice == 'A4' ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Display & Verification',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setModalState(() => formatChoice = '80MM'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: formatChoice == '80MM' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: formatChoice == '80MM' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                width: formatChoice == '80MM' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  color: formatChoice == '80MM' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  size: 26,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '80mm Thermal POS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: formatChoice == '80MM' ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Thermal Roll Slip',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Data Scope selection
                  const Text(
                    'ITEM SCOPE',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Complete Catalog (All approved items from server)', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Official master store price list', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    value: 'ALL',
                    groupValue: scopeChoice,
                    onChanged: (val) => setModalState(() => scopeChoice = val!),
                  ),
                  if (currentItems != null && currentItems.isNotEmpty)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Current Filtered Items (${currentItems.length} items${currentCategory != null && currentCategory != 'All' ? ' • $currentCategory' : ''})',
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: 'CURRENT',
                      groupValue: scopeChoice,
                      onChanged: (val) => setModalState(() => scopeChoice = val!),
                    ),
                  const SizedBox(height: 20),

                  // Generate and Print button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: isGenerating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.print, size: 20),
                      label: Text(
                        isGenerating ? 'Preparing Rate List...' : 'Generate & Print Rate List',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: isGenerating
                          ? null
                          : () async {
                              setModalState(() => isGenerating = true);
                              try {
                                List<Item> itemsToPrint = [];
                                if (scopeChoice == 'ALL') {
                                  // Fetch all items from server for complete legal compliance
                                  final res = await ApiClient.get('${ApiEndpoints.items}?limit=all');
                                  if (res['data'] is List) {
                                    itemsToPrint = (res['data'] as List)
                                        .map((e) => Item.fromJson(e))
                                        .where((it) => it.isActive && it.isSaleable)
                                        .toList();
                                  }
                                } else {
                                  itemsToPrint = currentItems ?? [];
                                }

                                if (itemsToPrint.isEmpty) {
                                  throw Exception('No active items found to print in the rate list.');
                                }

                                // Sort alphabetically
                                itemsToPrint.sort((a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));

                                if (modalCtx.mounted) Navigator.pop(modalCtx);

                                if (formatChoice == '80MM') {
                                  await _printThermalRateList(itemsToPrint, prop: prop, currentCategory: currentCategory);
                                } else {
                                  await _printA4OfficialRateList(itemsToPrint, prop: prop, currentCategory: currentCategory);
                                }
                              } catch (e) {
                                setModalState(() => isGenerating = false);
                                if (modalCtx.mounted) {
                                  ScaffoldMessenger.of(modalCtx).showSnackBar(
                                    SnackBar(content: Text('Error preparing rate list: $e'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
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

  /// Official A4 Document with statutory verification stamps
  static Future<void> _printA4OfficialRateList(
    List<Item> items, {
    PropertyInfo? prop,
    String? currentCategory,
  }) async {
    final fonts = await PosInvoicePrinter.getInvoiceFonts();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
      ),
    );

    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(prop?.logoPath ?? branding?.logoPath);

    final outletName = (prop?.propertyName.isNotEmpty == true)
        ? prop!.propertyName
        : ((branding?.businessName.isNotEmpty == true) ? branding!.businessName : 'COMMERCIAL ESTABLISHMENT');
    final address = prop?.address ?? '';
    final gstin = prop?.gstNo ?? '';
    final fssai = prop?.fssaiNo ?? '';
    final phone = prop?.mobile ?? '';
    final nowStr = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
    final dateCode = DateFormat('yyyyMMdd').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logo != null)
                          pw.Container(
                            width: 44,
                            height: 44,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(logo, fit: pw.BoxFit.contain),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                outletName.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#0F172A'),
                                ),
                              ),
                              if (address.isNotEmpty)
                                pw.Text(
                                  address,
                                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                                  maxLines: 2,
                                ),
                              pw.Row(
                                children: [
                                  if (gstin.isNotEmpty)
                                    pw.Text(
                                      'GSTIN: $gstin   ',
                                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                                    ),
                                  if (fssai.isNotEmpty)
                                    pw.Text(
                                      'FSSAI: $fssai   ',
                                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                                    ),
                                  if (phone.isNotEmpty)
                                    pw.Text(
                                      'Ph: $phone',
                                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#EFF6FF'),
                          border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE'), width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'STORE PRICE LIST',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A')),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text('Date: $nowStr', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                      pw.Text('Total Items: ${items.length}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E293B'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'OFFICIAL STORE RATE LIST / TARIFF SCHEDULE',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                    pw.Text(
                      'For Customer Reference & Official Verification',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey300),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
            ],
          );
        },
        footer: (pw.Context ctx) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'RetailSale Store Rate Schedule • Ref: RL-$dateCode',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context ctx) {
          final tableData = <List<String>>[];
          for (int i = 0; i < items.length; i++) {
            final it = items[i];
            tableData.add([
              '${i + 1}',
              it.itemCode.isNotEmpty ? it.itemCode : (it.barcode.isNotEmpty ? it.barcode : '-'),
              it.itemName,
              it.brand.isNotEmpty ? it.brand : '-',
              it.itemGroup.isNotEmpty ? it.itemGroup : 'General',
              it.unit.isNotEmpty ? it.unit : 'Nos',
              '${it.taxPercent.toStringAsFixed(0)}%',
              it.mrp > 0 ? it.mrp.toStringAsFixed(2) : it.retailSalePrice.toStringAsFixed(2),
              it.retailSalePrice.toStringAsFixed(2),
            ]);
          }

          return [
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Code', 'Product / Item Name', 'Brand', 'Category', 'Unit', 'Tax', 'MRP', 'Sale Rate'],
              data: tableData,
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
              ),
              headerStyle: pw.TextStyle(
                color: PdfColor.fromHex('#0F172A'),
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 7.5,
              ),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FixedColumnWidth(48),
                2: const pw.FlexColumnWidth(3.0),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(1.8),
                5: const pw.FixedColumnWidth(32),
                6: const pw.FixedColumnWidth(30),
                7: const pw.FixedColumnWidth(46),
                8: const pw.FixedColumnWidth(54),
              },
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.5,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
            ),
            pw.SizedBox(height: 14),

            // Store Declaration & Signatures
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'STORE PRICE DECLARATION & AUTHENTICATION RECORD',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B')),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Certified that the rates specified in this schedule represent the valid and authorized selling prices for goods available at this establishment as on the date printed above. Issued for customer reference and available for official inspection verification.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Store Manager Signature Area
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 180,
                            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Authorized Store In-charge / Manager',
                                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.Text('Signature & Establishment Rubber Stamp', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Verification Area
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 190,
                            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Verified By / Customer / Official Authority',
                                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.Text('Signature, Remarks & Official Stamp (if any)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Official_Rate_List_$dateCode',
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Compact 80mm POS Thermal Slip for receipt printers
  static Future<void> _printThermalRateList(
    List<Item> items, {
    PropertyInfo? prop,
    String? currentCategory,
  }) async {
    final fonts = await PosInvoicePrinter.getInvoiceFonts();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
      ),
    );

    final branding = await BrandingStorage.getCurrentBrandingContext();
    final outletName = (prop?.propertyName.isNotEmpty == true)
        ? prop!.propertyName
        : ((branding?.businessName.isNotEmpty == true) ? branding!.businessName : 'STORE');
    final gstin = prop?.gstNo ?? '';
    final nowStr = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  outletName.toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (gstin.isNotEmpty)
                pw.Center(
                  child: pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 8)),
                ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),
              pw.Center(
                child: pw.Text(
                  '*** STORE RATE LIST ***',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text('Date: $nowStr', style: const pw.TextStyle(fontSize: 7.5)),
              ),
              pw.Center(
                child: pw.Text('Total Items: ${items.length}', style: const pw.TextStyle(fontSize: 7.5)),
              ),
              pw.Divider(thickness: 0.8),

              // Table Headers
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('ITEM DESCRIPTION / BRAND', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('UNIT', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('RATE (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Table rows
              ...items.map((it) {
                final brandTag = it.brand.isNotEmpty ? ' • Brand: ${it.brand}' : '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(it.itemName, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Code: ${it.itemCode.isNotEmpty ? it.itemCode : it.barcode}$brandTag • Tax: ${it.taxPercent.toStringAsFixed(0)}%',
                                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(it.unit.isNotEmpty ? it.unit : 'Nos', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(it.retailSalePrice.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 4),
              pw.Text(
                'Store Price List • Available for Customer & Official Verification',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Store Seal / Sign:\n________________', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Acknowledged / Verified:\n________________', style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Rate_List_80mm_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      onLayout: (format) async => pdf.save(),
    );
  }
}

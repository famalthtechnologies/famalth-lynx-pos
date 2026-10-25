import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/currency/currency_service.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/common/property_info_model.dart';

class ClinicOpdReportPdf {
  static Future<void> printReport({
    required BuildContext context,
    required List<dynamic> appointments,
    required DateTime fromDate,
    required DateTime toDate,
    required String doctorFilter,
    PropertyInfo? property,
  }) async {
    final rangeStr = '${DateFormat('yyyyMMdd').format(fromDate)}_${DateFormat('yyyyMMdd').format(toDate)}';
    final title = 'OPD_Clinic_Report_$rangeStr';

    await Printing.layoutPdf(
      name: title,
      onLayout: (format) async => await generatePdfBytes(
        appointments: appointments,
        fromDate: fromDate,
        toDate: toDate,
        doctorFilter: doctorFilter,
        property: property,
      ),
    );
  }

  static Future<Uint8List> generatePdfBytes({
    required List<dynamic> appointments,
    required DateTime fromDate,
    required DateTime toDate,
    required String doctorFilter,
    PropertyInfo? property,
  }) async {
    final doc = await PosInvoicePrinter.createDocument();

    final clinicName = property?.propertyName ?? 'HEALTHCARE CLINIC & OPD CENTRE';
    final clinicAddress = '${property?.address ?? "Clinical Care Facility"}, ${property?.city ?? ""}'.trim();
    final clinicPhone = property?.mobile ?? '';
    final clinicEmail = property?.email ?? '';

    final isSingleDay = fromDate.year == toDate.year && fromDate.month == toDate.month && fromDate.day == toDate.day;
    final dateRangeLabel = isSingleDay
        ? DateFormat('dd MMM yyyy').format(fromDate)
        : '${DateFormat('dd MMM yyyy').format(fromDate)} to ${DateFormat('dd MMM yyyy').format(toDate)}';

    // Metrics
    final totalPatients = appointments.length;
    final visitedCount = appointments.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'VISITED').length;
    final scheduledCount = appointments.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'SCHEDULED').length;

    double totalFeesCollected = 0.0;
    double totalPayLater = 0.0;
    int packageSessionsCount = 0;
    final Map<String, double> modeTotals = {};

    for (final a in appointments) {
      final fee = double.tryParse('${a['consultation_fee'] ?? 0}') ?? 0.0;
      final paidAmt = double.tryParse('${a['paid_amount'] ?? 0}') ?? 0.0;
      final payStatus = (a['payment_status'] ?? '').toString().toUpperCase();
      final payMode = (a['payment_mode'] ?? 'CASH').toString().toUpperCase();
      final isPack = a['is_package_session'] == true || payStatus == 'PACKAGE_INCLUDED' || payMode == 'PACKAGE_SUBSCRIPTION';

      if (isPack) {
        packageSessionsCount++;
        if (paidAmt > 0) {
          totalFeesCollected += paidAmt;
          modeTotals[payMode] = (modeTotals[payMode] ?? 0.0) + paidAmt;
        }
      } else if (payStatus == 'PAID' || paidAmt > 0) {
        final amt = paidAmt > 0 ? paidAmt : fee;
        totalFeesCollected += amt;
        modeTotals[payMode] = (modeTotals[payMode] ?? 0.0) + amt;
      } else if (payStatus == 'PAY_LATER') {
        totalPayLater += fee;
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal800, width: 2)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          clinicName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                        ),
                        if (clinicAddress.isNotEmpty)
                          pw.Text(clinicAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        if (clinicPhone.isNotEmpty || clinicEmail.isNotEmpty)
                          pw.Text(
                            'Phone: $clinicPhone  |  Email: $clinicEmail',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.teal700,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'OPD CLINICAL REPORT',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Period: $dateRangeLabel', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Doctor: ${doctorFilter == 'ALL' ? 'All Clinicians' : doctorFilter}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Operational KPI Summary Cards
            pw.Row(
              children: [
                _kpiBox('TOTAL PATIENTS', '$totalPatients', PdfColors.blueGrey50, PdfColors.blueGrey800),
                pw.SizedBox(width: 8),
                _kpiBox('ATTENDED / VISITED', '$visitedCount', PdfColors.green50, PdfColors.green800),
                pw.SizedBox(width: 8),
                _kpiBox('IN QUEUE / SCHEDULED', '$scheduledCount', PdfColors.amber50, PdfColors.amber800),
                pw.SizedBox(width: 8),
                _kpiBox('FEES COLLECTED', '${CurrencyService.symbol}${totalFeesCollected.toStringAsFixed(2)}', PdfColors.teal50, PdfColors.teal900),
                pw.SizedBox(width: 8),
                _kpiBox('PACKAGE SESSIONS', '$packageSessionsCount Covered', PdfColors.purple50, PdfColors.purple800),
              ],
            ),
            pw.SizedBox(height: 12),

            // Payment Modes Breakdown Row
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                children: [
                  pw.Text('Financial Collections: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ...modeTotals.entries.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 12),
                    child: pw.Text(
                      '${e.key}: ${CurrencyService.symbol}${e.value.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.teal800),
                    ),
                  )),
                  if (totalPayLater > 0)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 12),
                      child: pw.Text(
                        'Pay Later: ${CurrencyService.symbol}${totalPayLater.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.deepOrange800),
                      ),
                    ),
                  if (packageSessionsCount > 0)
                    pw.Text(
                      'Package Covered: $packageSessionsCount sessions (${CurrencyService.symbol}0.00)',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.purple800),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Appointments Table
            pw.Text(
              'Patient Appointments & Consultations Roster',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
            ),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              headers: [
                'Token',
                'Patient Name',
                'Phone',
                'Clinician / Doctor',
                'Date & Time',
                'Status',
                'Fee Status',
                'Dispensing',
              ],
              data: appointments.map((a) {
                final tok = a['token_number'] != null ? '#${a['token_number']}' : '#${a['id']}';
                final pName = a['patient_name'] ?? 'Patient';
                final phone = a['patient_phone'] ?? '-';
                final doc = a['doctor_name'] ?? 'Doctor';
                final date = a['appointment_date']?.toString() ?? '';
                final time = a['appointment_time']?.toString() ?? '';
                final status = (a['status'] ?? 'SCHEDULED').toString().toUpperCase();
                final payStatus = (a['payment_status'] ?? 'UNPAID').toString().toUpperCase();
                final payMode = (a['payment_mode'] ?? '').toString().toUpperCase();
                final fee = double.tryParse('${a['consultation_fee'] ?? 0}') ?? 0.0;
                final isPack = a['is_package_session'] == true || payStatus == 'PACKAGE_INCLUDED' || payMode == 'PACKAGE_SUBSCRIPTION';

                String feeLabel = '${CurrencyService.symbol}$fee';
                if (isPack) {
                  feeLabel = 'Package Covered (0.00)';
                } else if (payStatus == 'PAID') {
                  feeLabel = 'Paid (${CurrencyService.symbol}$fee)';
                } else if (payStatus == 'PAY_LATER') {
                  feeLabel = 'Pay Later (${CurrencyService.symbol}$fee)';
                }

                final billingStatus = (a['billing_status'] ?? 'PENDING').toString().toUpperCase();
                final dispensingLabel = billingStatus == 'BILLED' ? 'Dispensed' : 'Pending';

                return [
                  tok,
                  pName,
                  phone,
                  doc,
                  '$date $time',
                  status,
                  feeLabel,
                  dispensingLabel,
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 20),
            // Footer Signature
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Report produced by Healthcare Clinic Management System', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 2),
                    pw.Text('Authorized Clinician / Staff Signature', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _kpiBox(String title, String val, PdfColor bg, PdfColor textCol) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: textCol, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: textCol)),
            pw.SizedBox(height: 2),
            pw.Text(val, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textCol)),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/common/property_info_model.dart';

class ClinicPrescriptionPdf {
  static Future<void> printOrDownloadPrescription({
    required BuildContext context,
    required Map<String, dynamic> appointment,
    PropertyInfo? property,
  }) async {
    final patientName = (appointment['patient_name'] ?? 'Patient').toString().replaceAll(' ', '_');
    final docTitle = 'Prescription_${appointment['id']}_$patientName';

    await Printing.layoutPdf(
      name: docTitle,
      onLayout: (format) async => await generatePdfBytes(
        appointment: appointment,
        property: property,
      ),
    );
  }

  static Future<Uint8List> generatePdfBytes({
    required Map<String, dynamic> appointment,
    PropertyInfo? property,
  }) async {
    final doc = await PosInvoicePrinter.createDocument();

    final clinicName = property?.propertyName ?? 'FAMALTH MULTI-SPECIALITY CLINIC';
    final clinicAddress = '${property?.address ?? "Medical Boulevard"}, ${property?.city ?? ""}'.trim();
    final clinicPhone = property?.mobile ?? '+91 98765 43210';
    final clinicEmail = property?.email ?? 'care@famalthclinic.com';
    final clinicGst = property?.gstNo ?? '';
    final clinicDrugLicense = property?.drugLicenseNo ?? '';

    final patientName = appointment['patient_name'] ?? 'Patient';
    final patientPhone = appointment['patient_phone'] ?? '-';
    final patientAge = appointment['patient_age']?.toString() ?? '-';
    final patientGender = (appointment['patient_gender'] ?? '-').toString().toUpperCase();
    final appointmentDate = appointment['appointment_date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final appointmentTime = appointment['appointment_time']?.toString() ?? '';
    final doctorName = (appointment['doctor_name'] ?? 'Dr. Specialist').toString();
    final department = appointment['department'] ?? 'General Medicine';
    final docQual = (appointment['doctor_qualification'] ?? appointment['qualification'] ?? '').toString();
    final docReg = (appointment['doctor_reg_no'] ?? appointment['registration_no'] ?? '').toString();
    final diagnosis = appointment['diagnosis'] ?? appointment['prescription_notes'] ?? 'General Health Consultation';
    final notes = appointment['prescription_notes'] ?? '';
    final token = appointment['id']?.toString() ?? '1';

    final rawMeds = appointment['prescribed_medicines'];
    final List<Map<String, dynamic>> medicines = rawMeds is List
        ? rawMeds.map((m) => Map<String, dynamic>.from(m)).toList()
        : [];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. CLINIC HEADER
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 2)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            clinicName,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            clinicAddress,
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                          pw.Text(
                            'Phone: $clinicPhone  •  Email: $clinicEmail',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                          if (clinicGst.isNotEmpty)
                            pw.Text(
                              'Reg/GST: $clinicGst ${clinicDrugLicense.isNotEmpty ? " • DL: $clinicDrugLicense" : ""}',
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                            ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.blue300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'TOKEN #$token',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.Text(
                            '$appointmentDate ${appointmentTime.isNotEmpty ? "• $appointmentTime" : ""}',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // 2. DOCTOR & PATIENT DEMOGRAPHICS
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Patient Details
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PATIENT INFORMATION',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            patientName,
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          ),
                          pw.Text(
                            'Age: $patientAge Years  •  Gender: $patientGender',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                          ),
                          pw.Text(
                            'Phone: $patientPhone',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 12),

                  // Doctor Details
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ATTENDING CONSULTANT',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            doctorName.startsWith('Dr') ? doctorName : 'Dr. $doctorName',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                          ),
                          if (docQual.isNotEmpty)
                            pw.Text(
                              docQual,
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                            ),
                          if (docReg.isNotEmpty)
                            pw.Text(
                              'Reg No: $docReg',
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                            ),
                          pw.Text(
                            'Department: $department',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                          ),
                          pw.Text(
                            'Consultation Mode: In-Clinic OPD',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // 3. CLINICAL DIAGNOSIS & REASON FOR VISIT
              if (diagnosis.toString().isNotEmpty || (appointment['reason_for_visit'] != null && appointment['reason_for_visit'].toString().isNotEmpty))
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CLINICAL DIAGNOSIS & OBSERVATIONS:',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        diagnosis.toString(),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                      ),
                      if (appointment['reason_for_visit'] != null && appointment['reason_for_visit'].toString().isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Chief Complaints: ${appointment['reason_for_visit']}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ],
                  ),
                ),

              pw.SizedBox(height: 12),

              // 4. Rx SYMBOL & MEDICINES TABLE
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    '℞',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'PRESCRIBED MEDICINES (PHARMACY DISPENSARY)',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              if (medicines.isEmpty)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'No pharmaceutical medications prescribed during this consultation.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  headerHeight: 22,
                  cellHeight: 22,
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(24),
                    1: const pw.FlexColumnWidth(3.5),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(2.2),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FixedColumnWidth(32),
                  },
                  headers: ['#', 'Medicine / Formulation', 'Dosage', 'Frequency / Instructions', 'Duration', 'Qty'],
                  data: medicines.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final m = entry.value;
                    return [
                      '$idx',
                      '${m['item_name'] ?? 'Medicine'}\n(${m['item_code'] ?? '-'})',
                      m['dosage'] ?? '1-0-1',
                      m['frequency'] ?? m['instructions'] ?? 'After Food',
                      m['duration'] ?? '5 Days',
                      '${m['qty'] ?? 1}',
                    ];
                  }).toList(),
                ),

              pw.SizedBox(height: 14),

              // 5. SPECIAL INSTRUCTIONS / ADVICE
              if (notes.toString().isNotEmpty)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.amber200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PHYSICIAN ADVICE & PRECAUTIONS:',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        notes.toString(),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                      ),
                    ],
                  ),
                ),

              pw.Spacer(),

              // 6. DOCTOR SIGNATURE & FOOTER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '• Take medicines as directed with clean drinking water.',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        '• In case of emergency or adverse reaction, report immediately.',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        '• Valid for 7 days from consultation date.',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 140,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey500, width: 1)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              doctorName.startsWith('Dr') ? doctorName : 'Dr. $doctorName',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                            if (docQual.isNotEmpty)
                              pw.Text(
                                docQual,
                                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                              ),
                            if (docReg.isNotEmpty)
                              pw.Text(
                                'Reg No: $docReg',
                                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                              ),
                            pw.Text(
                              'Authorized Medical Practitioner',
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                            ),
                            pw.Text(
                              'Digital Consultation Stamp',
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blue800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Famalth Lynx Clinic & OPD Suite • Get Well Soon',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Generated on ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';

class PublicAppointmentBookingScreen extends StatefulWidget {
  final dynamic initialOutletId;
  final String? initialDoctorName;

  const PublicAppointmentBookingScreen({
    super.key,
    this.initialOutletId,
    this.initialDoctorName,
  });

  @override
  State<PublicAppointmentBookingScreen> createState() => _PublicAppointmentBookingScreenState();
}

class _PublicAppointmentBookingScreenState extends State<PublicAppointmentBookingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Explore & City state
  bool _isLoadingDoctors = false;
  List<dynamic> _cities = [];
  String _selectedCity = 'New Delhi';
  List<dynamic> _specialities = [];
  String _selectedSpeciality = 'ALL';
  final TextEditingController _searchDoctorCtrl = TextEditingController();
  List<dynamic> _doctors = [];

  // Patient History state
  final TextEditingController _historyLookupCtrl = TextEditingController();
  bool _isLoadingHistory = false;
  List<dynamic> _patientHistory = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchDoctorCtrl.dispose();
    _historyLookupCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchCities(),
      _fetchSpecialities(),
    ]);
    await _fetchDoctors();
  }

  Future<void> _fetchCities() async {
    try {
      final res = await ApiClient.get('/api/public/clinic/cities');
      if (res != null && res['success'] == true && res['data'] is List) {
        setState(() {
          _cities = res['data'];
          if (_cities.isNotEmpty && !_cities.contains(_selectedCity)) {
            _selectedCity = _cities.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchSpecialities() async {
    try {
      final res = await ApiClient.get('/api/public/clinic/specialities');
      if (res != null && res['success'] == true && res['data'] is List) {
        setState(() {
          _specialities = res['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDoctors() async {
    setState(() => _isLoadingDoctors = true);
    try {
      final queryParams = <String, dynamic>{
        'city': _selectedCity,
      };
      if (_selectedSpeciality != 'ALL') {
        queryParams['speciality'] = _selectedSpeciality;
      }
      if (_searchDoctorCtrl.text.trim().isNotEmpty) {
        queryParams['search'] = _searchDoctorCtrl.text.trim();
      }

      final res = await ApiClient.get(
        '/api/public/clinic/doctors',
        queryParams: queryParams,
      );

      if (res != null && res['success'] == true) {
        setState(() {
          _doctors = res['data'] ?? [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load doctors: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingDoctors = false);
    }
  }

  Future<void> _fetchPatientHistory() async {
    final q = _historyLookupCtrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your registered email or phone to view history')),
      );
      return;
    }

    setState(() => _isLoadingHistory = true);
    try {
      final isEmail = q.contains('@');
      final res = await ApiClient.get(
        '/api/public/clinic/patient-history',
        queryParams: {
          if (isEmail) 'email': q else 'phone': q,
        },
      );

      if (res != null && res['success'] == true) {
        setState(() {
          _patientHistory = res['data'] ?? [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _openBookingModal(dynamic doctor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DoctorBookingDialog(
        doctor: doctor,
        onBooked: () {
          _tabCtrl.animateTo(1);
          if (_historyLookupCtrl.text.trim().isNotEmpty) {
            _fetchPatientHistory();
          }
        },
      ),
    );
  }

  Future<void> _printPrescriptionOrInvoice(dynamic apt) async {
    final pdf = pw.Document();
    final patientName = apt['patient_name'] ?? 'Patient';
    final patientPhone = apt['patient_phone'] ?? '-';
    final patientEmail = apt['patient_email'] ?? '-';
    final doctorName = apt['doctor_name'] ?? 'General Doctor';
    final clinicName = apt['clinic_name'] ?? 'Famalth Healthcare Clinic';
    final clinicAddress = apt['clinic_address'] ?? '';
    final date = apt['appointment_date'] ?? '';
    final time = apt['appointment_time'] ?? '';
    final notes = apt['prescription_notes'] ?? 'None recorded';
    final medicines = apt['prescribed_medicines'] is List ? apt['prescribed_medicines'] as List : [];
    final fee = apt['consultation_fee'] ?? 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(clinicName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text(clinicAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('MEDICAL PRESCRIPTION & INVOICE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                        pw.Text('Date: $date  Time: $time', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Appointment Ref: #${apt['id'] ?? ''}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.blue900),
                pw.SizedBox(height: 10),

                // Patient Details & Doctor Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PATIENT INFORMATION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text('Name: $patientName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Phone: $patientPhone  |  Email: $patientEmail', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Age: ${apt['patient_age'] ?? '-'}  |  Gender: ${apt['patient_gender'] ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('ATTENDING DOCTOR', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text(doctorName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Department: ${apt['department'] ?? 'General'}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Status: ${apt['status'] ?? 'VISITED'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Clinical Diagnosis
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DOCTOR CLINICAL NOTES & DIAGNOSIS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // Prescribed Medicines Table
                pw.Text('Rx - PRESCRIBED MEDICINES', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 6),
                if (medicines.isEmpty)
                  pw.Text('No medications prescribed during this visit.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Medicine Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Dosage', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Frequency', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Duration', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        ],
                      ),
                      ...medicines.map((m) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(m['item_name'] ?? '', style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(m['dosage'] ?? '1-0-1', style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(m['frequency'] ?? 'After Meals', style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(m['duration'] ?? '5 Days', style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${m['qty'] ?? 1}', style: const pw.TextStyle(fontSize: 9))),
                          ],
                        );
                      }),
                    ],
                  ),

                pw.Spacer(),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Consultation Fee: \$${NumberFormat('#,##0.00').format(fee)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Doctor Signature / Stamp', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 25),
                        pw.Text(doctorName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Doctor Consultation & Clinic Directory'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Explore Doctors (By City)'),
            Tab(icon: Icon(Icons.history_edu), text: 'My Past Consultations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildExploreDoctorsTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildExploreDoctorsTab() {
    return Column(
      children: [
        // 1. City & Specialty Filter Bar (Similar to Retailer Vendor Explore)
        _buildCityAndSpecialtyHeader(),

        // 2. Doctor Directory
        Expanded(
          child: _isLoadingDoctors
              ? const Center(child: CircularProgressIndicator())
              : _doctors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No doctors found in $_selectedCity for selected filters.',
                            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedSpeciality = 'ALL';
                                _searchDoctorCtrl.clear();
                              });
                              _fetchDoctors();
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _doctors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) => _buildDoctorCard(_doctors[idx]),
                    ),
        ),
      ],
    );
  }

  Widget _buildCityAndSpecialtyHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // City Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: _cities.contains(_selectedCity) ? _selectedCity : (_cities.isNotEmpty ? _cities.first : null),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                      items: _cities.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c.toString(),
                          child: Text(c.toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCity = val);
                          _fetchDoctors();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Search Bar
              Expanded(
                child: TextField(
                  controller: _searchDoctorCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search doctor, specialty, or clinic...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchDoctorCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchDoctorCtrl.clear();
                              _fetchDoctors();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _fetchDoctors(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _fetchDoctors,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Specialty Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _specialityChip('ALL', 'All Specialists'),
                ..._specialities.map((s) => _specialityChip(s.toString(), s.toString())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specialityChip(String key, String label) {
    final sel = _selectedSpeciality == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        selectedColor: Colors.blueAccent,
        labelStyle: TextStyle(
          color: sel ? Colors.white : Colors.black87,
          fontSize: 12,
          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (val) {
          if (val) {
            setState(() => _selectedSpeciality = key);
            _fetchDoctors();
          }
        },
      ),
    );
  }

  Widget _buildDoctorCard(dynamic doc) {
    final isVerified = doc['is_verified_badge'] == true;
    final rating = doc['rating'] ?? 4.9;
    final exp = doc['experience_years'] ?? 5;
    final fee = doc['consultation_fee'] ?? 500;
    final days = doc['available_days'] is List ? (doc['available_days'] as List).join(', ') : 'Daily';

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    (doc['name'] ?? 'Dr').toString().replaceAll('Dr. ', '').substring(0, 1).toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blue.shade800),
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Specialty
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              doc['name'] ?? 'Doctor',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 2),
                            Text(
                              'Verified',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${doc['speciality'] ?? 'General'}  •  ${doc['qualification'] ?? ''}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 3),
                                Text('$rating', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$exp+ Years Experience', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Consultation Fee
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${NumberFormat('#,##0').format(fee)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const Text('Consultation Fee', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Clinic Location & Timing
            Row(
              children: [
                Icon(Icons.local_hospital_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${doc['clinic_name'] ?? 'Clinic'}  •  ${doc['address'] ?? ''}, ${doc['city'] ?? ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text('Available: $days', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),

                // BOOK APPOINTMENT ACTION BUTTON
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('Book Appointment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openBookingModal(doc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Patient Universal Medical History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text('View and print your invoices & doctor prescriptions across any clinic on our portal.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _historyLookupCtrl,
                      decoration: InputDecoration(
                        labelText: 'Enter Your Verified Email or Mobile Phone',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        hintText: 'e.g. john@example.com or 9876543210',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _fetchPatientHistory(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _fetchPatientHistory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('View History'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _patientHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_edu_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Enter your email or phone to view all your past appointments.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _patientHistory.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final a = _patientHistory[idx];
                              final status = a['status'] ?? 'SCHEDULED';
                              Color statusColor = Colors.orange;
                              if (status == 'VISITED') statusColor = Colors.green;
                              if (status == 'CANCELLED') statusColor = Colors.red;

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${a['doctor_name'] ?? 'Doctor'}  (${a['department'] ?? 'General'})',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                Text(
                                                  '${a['clinic_name'] ?? 'Clinic'} • ${a['clinic_city'] ?? ''}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_month, size: 15, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text('Date: ${a['appointment_date']} at ${a['appointment_time']}', style: const TextStyle(fontSize: 13)),
                                          const Spacer(),
                                          Text('Fee: \$${a['consultation_fee'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      if (a['prescription_notes'] != null && a['prescription_notes'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                          child: Text(
                                            'Doctor Diagnosis: ${a['prescription_notes']}',
                                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.print, size: 16),
                                            label: const Text('Print Prescription / Invoice'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal.shade700,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _printPrescriptionOrInvoice(a),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorBookingDialog extends StatefulWidget {
  final dynamic doctor;
  final VoidCallback onBooked;

  const _DoctorBookingDialog({required this.doctor, required this.onBooked});

  @override
  State<_DoctorBookingDialog> createState() => _DoctorBookingDialogState();
}

class _DoctorBookingDialogState extends State<_DoctorBookingDialog> {
  // Step 1: Email Verification
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isEmailVerified = false;
  bool _otpSent = false;
  String? _otpMessage;

  // Step 2: Patient Info (Auto-Filled if already registered)
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _gender = 'MALE';

  // Step 3: Date & Time Slot
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = '10:00 AM';
  bool _isSubmitting = false;

  final List<String> _slots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
    '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM',
    '05:00 PM', '05:30 PM', '06:00 PM', '06:30 PM', '07:00 PM', '07:30 PM',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      final res = await ApiClient.post('/api/public/clinic/request-email-otp', {'email': email});
      if (res != null && res['success'] == true) {
        setState(() {
          _otpSent = true;
          _otpMessage = res['message'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending email code: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit verification code')),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final res = await ApiClient.post('/api/public/clinic/verify-email-otp', {
        'email': email,
        'otp': otp,
      });

      if (res != null && res['success'] == true) {
        setState(() {
          _isEmailVerified = true;
        });

        // AUTO-FILL IF REGISTERED USER (NO RE-REGISTRATION NEEDED)
        if (res['is_registered'] == true && res['patient'] != null) {
          final p = res['patient'];
          _nameCtrl.text = p['name'] ?? '';
          _phoneCtrl.text = p['phone'] ?? '';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(res['is_registered'] == true
                  ? 'Email verified! Welcome back, your patient details have been auto-filled.'
                  : 'Email successfully verified! Enter your details to complete booking.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Invalid verification code')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (!_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your email address to receive reports and bills')),
      );
      return;
    }

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient name and phone number are required')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await ApiClient.post('/api/public/clinic/appointment', {
        'outlet_id': widget.doctor['outlet_id'],
        'patient_name': name,
        'patient_phone': phone,
        'patient_email': _emailCtrl.text.trim().toLowerCase(),
        'email_otp': _otpCtrl.text.trim(),
        'patient_age': int.tryParse(_ageCtrl.text.trim()),
        'patient_gender': _gender,
        'appointment_date': formattedDate,
        'appointment_time': _selectedSlot,
        'doctor_name': widget.doctor['name'],
        'doctor_id': widget.doctor['id'],
        'consultation_fee': widget.doctor['consultation_fee'],
        'department': widget.doctor['speciality'],
        'reason_for_visit': _reasonCtrl.text.trim(),
      });

      if (res != null && res['success'] == true) {
        Navigator.pop(context);
        widget.onBooked();

        if (mounted) {
          showDialog(
            context: context,
            builder: (sCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Booking Confirmed!'),
                ],
              ),
              content: Text(
                'Your consultation with ${widget.doctor['name']} at ${widget.doctor['clinic_name']} on $formattedDate at $_selectedSlot has been confirmed! An email confirmation has been dispatched to ${_emailCtrl.text.trim()}.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(sCtx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Failed to book appointment')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: const Icon(Icons.medical_services, color: Colors.blueAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book with ${widget.doctor['name']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.doctor['speciality']} • ${widget.doctor['clinic_name']}',
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
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Mandatory Email Verification for Report & Bill Delivery
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isEmailVerified ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _isEmailVerified ? Colors.green.shade200 : Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_isEmailVerified ? Icons.mark_email_read : Icons.email_outlined, color: _isEmailVerified ? Colors.green : Colors.blueAccent, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _isEmailVerified ? 'Email Verified for Medical Reports & Bills ✓' : '1. Email Verification Required for Reports & Bills',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isEmailVerified ? Colors.green.shade900 : Colors.blue.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_isEmailVerified) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Patient Email *',
                                hintText: 'Enter your email for report delivery',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSendingOtp ? null : _sendEmailOtp,
                            child: _isSendingOtp
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(_otpSent ? 'Resend' : 'Send Code'),
                          ),
                        ],
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '6-Digit Verification Code',
                                  hintText: 'Enter OTP sent to your email',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: _isVerifyingOtp ? null : _verifyEmailOtp,
                              child: _isVerifyingOtp
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Verify Code'),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      Text('Verified Email: ${_emailCtrl.text.trim()}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Patient Profile Information (Auto-Filled If Registered)
              const Text('2. Patient Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *', isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone Number *', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Gender', isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'MALE', child: Text('Male')),
                        DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Consultation Date & Time Slot
              const Text('3. Appointment Date & Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(DateFormat('EEE, dd MMM yyyy').format(_selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _slots.take(10).map((s) {
                  final sel = _selectedSlot == s;
                  return ChoiceChip(
                    label: Text(s),
                    selected: sel,
                    selectedColor: Colors.blueAccent,
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : Colors.black87,
                      fontSize: 11,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedSlot = s);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 4. Reason for Visit
              TextField(
                controller: _reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Symptoms / Reason for Consultation',
                  hintText: 'e.g. Fever, routine health check, joint pain...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _confirmBooking,
          icon: const Icon(Icons.check, size: 16),
          label: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('CONFIRM BOOKING'),
        ),
      ],
    );
  }
}

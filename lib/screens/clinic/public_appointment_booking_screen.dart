import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

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

class _PublicAppointmentBookingScreenState extends State<PublicAppointmentBookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Patient Profile state
  Map<String, dynamic>? _patientProfile;

  // Explore & City state
  bool _isLoadingDoctors = false;
  List<dynamic> _cities = [];
  String _selectedCity = 'Dehradun';
  List<dynamic> _specialities = [];
  String _selectedSpeciality = 'ALL';
  final TextEditingController _searchDoctorCtrl = TextEditingController();
  List<dynamic> _doctors = [];

  // Patient History state
  final TextEditingController _historyLookupCtrl = TextEditingController();
  bool _isLoadingHistory = false;
  List<dynamic> _patientHistory = [];
  List<dynamic> _patientSubscriptions = [];

  // Color palette
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color bgSoftSlate = Color(0xFFF8FAFC);
  static const Color slateCardBorder = Color(0xFFE2E8F0);
  static const Color darkSlate = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 1 && _patientHistory.isEmpty && _historyLookupCtrl.text.trim().isNotEmpty) {
        _fetchPatientHistory();
      }
    });
    _initScreen();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchDoctorCtrl.dispose();
    _historyLookupCtrl.dispose();
    super.dispose();
  }

  Future<void> _initScreen() async {
    await _loadPatientProfile();
    await Future.wait([
      _fetchCities(),
      _fetchSpecialities(),
    ]);
    await _fetchDoctors();
  }

  Future<void> _loadPatientProfile() async {
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedStr = prefs.getString('clinic_patient_profile');
      savedStr ??= prefs.getString('dining_customer_profile');

      if (savedStr != null && savedStr.isNotEmpty) {
        final data = jsonDecode(savedStr);
        if (data is Map<String, dynamic>) {
          _patientProfile = data;
          final lookupTarget = data['phone'] ?? data['email'] ?? '';
          _historyLookupCtrl.text = lookupTarget;
          if (lookupTarget.isNotEmpty) {
            _fetchPatientHistory();
          }
        }
      }
    } catch (e) {
      debugPrint('[CLINIC PROFILE LOAD ERR] $e');
    } finally {
      
    }
  }

  Future<void> _savePatientProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = jsonEncode(profile);
      await prefs.setString('clinic_patient_profile', str);
      await prefs.setString('dining_customer_profile', str);
      setState(() {
        _patientProfile = profile;
        final lookupTarget = profile['phone'] ?? profile['email'] ?? '';
        _historyLookupCtrl.text = lookupTarget;
      });
      if (_historyLookupCtrl.text.isNotEmpty) {
        _fetchPatientHistory();
      }
    } catch (e) {
      debugPrint('[CLINIC PROFILE SAVE ERR] $e');
    }
  }

  Future<void> _clearPatientProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('clinic_patient_profile');
      await prefs.remove('dining_customer_profile');
      setState(() {
        _patientProfile = null;
        _historyLookupCtrl.clear();
        _patientHistory = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out from patient session')),
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchCities() async {
    try {
      final res = await ApiClient.get('/api/public/clinic/cities');
      if (res != null && res['success'] == true && res['data'] is List) {
        setState(() {
          _cities = res['data'];
          if (_cities.isNotEmpty && !_cities.contains(_selectedCity)) {
            _selectedCity = _cities.first.toString();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load doctors: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDoctors = false);
    }
  }

  Future<void> _fetchPatientHistory() async {
    String q = '';
    if (_patientProfile != null) {
      q = (_patientProfile!['phone'] ?? _patientProfile!['email'] ?? '').toString().trim();
      _historyLookupCtrl.text = q;
    } else {
      q = _historyLookupCtrl.text.trim();
    }

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

      // Also fetch patient therapy packages
      try {
        final subRes = await ApiClient.get(
          ApiEndpoints.publicPatientSubscriptions,
          queryParams: {
            if (isEmail) 'email': q else 'phone': q,
          },
        );
        if (subRes != null && subRes['success'] == true && mounted) {
          setState(() {
            _patientSubscriptions = subRes['data'] ?? [];
          });
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _openRegistrationModal({VoidCallback? onSuccess}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PatientRegistrationBottomSheet(
        initialProfile: _patientProfile,
        onProfileSaved: (profile) {
          _savePatientProfile(profile);
          if (onSuccess != null) {
            onSuccess();
          }
        },
      ),
    );
  }

  void _handleBookAppointment(dynamic doctor) {
    if (_patientProfile == null) {
      // Must register first
      _openRegistrationModal(
        onSuccess: () {
          _openBookingModal(doctor);
        },
      );
    } else {
      _openBookingModal(doctor);
    }
  }

  void _openBookingModal(dynamic doctor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DoctorBookingDialog(
        doctor: doctor,
        patientProfile: _patientProfile,
        patientSubscriptions: _patientSubscriptions,
        onBooked: () {
          _tabCtrl.animateTo(1);
          if (_historyLookupCtrl.text.trim().isNotEmpty) {
            _fetchPatientHistory();
          }
        },
      ),
    );
  }

  Future<void> _openWhatsApp(String phone, String doctorName) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp number not available for this doctor/clinic')),
      );
      return;
    }
    final msg = Uri.encodeComponent('Hello Dr. $doctorName, I would like to inquire about a clinic consultation.');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not initiate phone call')),
        );
      }
    }
  }

  Future<void> _printPrescriptionOrInvoice(dynamic apt) async {
    final pdf = pw.Document();
    final patientName = apt['patient_name'] ?? 'Patient';
    final patientPhone = apt['patient_phone'] ?? '-';
    final patientEmail = apt['patient_email'] ?? '-';
    final doctorName = apt['doctor_name'] ?? 'General Doctor';
    final clinicName = apt['clinic_name'] ?? 'Healthcare Clinic';
    final clinicAddress = apt['clinic_address'] ?? '';
    final date = apt['appointment_date'] ?? '';
    final time = apt['appointment_time'] ?? '';
    final notes = apt['prescription_notes'] ?? 'None recorded';
    final medicines = apt['prescribed_medicines'] is List ? apt['prescribed_medicines'] as List : [];
    final fee = double.tryParse('${apt['consultation_fee'] ?? 0}') ?? 0.0;

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
                        pw.Text(clinicName,
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal900)),
                        pw.Text(clinicAddress,
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('MEDICAL PRESCRIPTION & INVOICE',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal700)),
                        pw.Text('Date: $date  Time: $time',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Appointment Ref: #${apt['id'] ?? ''}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.teal800),
                pw.SizedBox(height: 10),

                // Patient Details & Doctor Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PATIENT INFORMATION',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal800)),
                        pw.Text('Name: $patientName',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Phone: $patientPhone  |  Email: $patientEmail',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(
                            'Age: ${apt['patient_age'] ?? '-'}  |  Gender: ${apt['patient_gender'] ?? '-'}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('ATTENDING CLINICIAN',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal800)),
                        pw.Text(doctorName,
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Department: ${apt['department'] ?? 'General'}',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Status: ${apt['status'] ?? 'VISITED'}',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),

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
                      pw.Text('CLINICAL NOTES & DIAGNOSIS',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900)),
                      pw.SizedBox(height: 4),
                      pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Prescribed Medicines Table
                pw.Text('Rx - PRESCRIBED MEDICINES',
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal900)),
                pw.SizedBox(height: 6),
                if (medicines.isEmpty)
                  pw.Text('No medications prescribed during this visit.',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('Medicine Name',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('Dosage',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('Frequency',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('Duration',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('Qty',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        ],
                      ),
                      ...medicines.map((m) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(m['item_name'] ?? '',
                                    style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(m['dosage'] ?? '1-0-1',
                                    style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(m['frequency'] ?? 'After Meals',
                                    style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(m['duration'] ?? '5 Days',
                                    style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text('${m['qty'] ?? 1}',
                                    style: const pw.TextStyle(fontSize: 9))),
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
                    pw.Text('Consultation Fee: ${CurrencyService.code} ${fee.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Doctor Signature / Clinical Stamp',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 25),
                        pw.Text(doctorName,
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
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
      backgroundColor: bgSoftSlate,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: primaryTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: primaryTeal, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Doctor & Clinic Consultations',
                  style: TextStyle(
                    color: darkSlate,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Explore Verified Specialists & Book Appointments',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: primaryTeal,
              indicatorWeight: 3,
              labelColor: primaryTeal,
              unselectedLabelColor: Colors.blueGrey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.search_rounded, size: 18), text: 'Explore Doctors & Clinics'),
                Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'My Past Consultations'),
              ],
            ),
          ),
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
        // 1. Patient Profile Banner (Swiggy / Dining standard)
        _buildPatientStatusBanner(),

        // 2. City & Speciality Filter Bar
        _buildCityAndSpecialtyHeader(),

        // 3. Doctors & Multi-Doctor Clinics Directory
        Expanded(
          child: _isLoadingDoctors
              ? const Center(child: CircularProgressIndicator(color: primaryTeal))
              : _doctors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medical_services_outlined, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No doctors found in $_selectedCity for selected filters.',
                            style: TextStyle(fontSize: 15, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            onPressed: () {
                              setState(() {
                                _selectedSpeciality = 'ALL';
                                _searchDoctorCtrl.clear();
                              });
                              _fetchDoctors();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryTeal,
                              side: const BorderSide(color: primaryTeal),
                            ),
                            label: const Text('Reset All Filters'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: _doctors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (ctx, idx) => _DoctorClinicCard(
                        doctor: _doctors[idx],
                        onBook: (selectedDoc) => _handleBookAppointment(selectedDoc),
                        onCall: (phone) => _callPhone(phone),
                        onWhatsApp: (phone, docName) => _openWhatsApp(phone, docName),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPatientStatusBanner() {
    final hasProfile = _patientProfile != null;
    final name = hasProfile ? (_patientProfile!['name'] ?? 'Patient') : 'Guest Patient';
    final phone = hasProfile ? (_patientProfile!['phone'] ?? '') : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: hasProfile ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        border: Border(
          bottom: BorderSide(
            color: hasProfile ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: hasProfile ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
            child: Icon(
              hasProfile ? Icons.person_rounded : Icons.person_outline_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      hasProfile ? 'Logged in as ' : 'Welcome, ',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800),
                    ),
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkSlate),
                    ),
                    if (hasProfile) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Verified Profile',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  hasProfile
                      ? 'Phone: $phone • Details will auto-fill on booking'
                      : 'Register once for 1-tap bookings & digital prescriptions',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                ),
              ],
            ),
          ),
          if (hasProfile) ...[
            TextButton.icon(
              onPressed: () => _openRegistrationModal(),
              icon: const Icon(Icons.edit, size: 14, color: primaryTeal),
              label: const Text('Edit Profile', style: TextStyle(fontSize: 11, color: primaryTeal, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            IconButton(
              icon: const Icon(Icons.logout, size: 16, color: Colors.grey),
              tooltip: 'Sign Out / Change Patient',
              visualDensity: VisualDensity.compact,
              onPressed: _clearPatientProfile,
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: () => _openRegistrationModal(),
              icon: const Icon(Icons.app_registration, size: 14),
              label: const Text('Register / Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCityAndSpecialtyHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // City Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: slateCardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: primaryTeal, size: 18),
                    const SizedBox(width: 4),
                    DropdownButton<String>(
                      value: _cities.contains(_selectedCity)
                          ? _selectedCity
                          : (_cities.isNotEmpty ? _cities.first.toString() : null),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryTeal),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: darkSlate, fontSize: 13),
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
              const SizedBox(width: 10),

              // Search Input Bar
              Expanded(
                child: TextField(
                  controller: _searchDoctorCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search doctor, specialty, clinic...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.blueGrey),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: slateCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: slateCardBorder),
                    ),
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
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Specialty Filter Pills with Icons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _specialityPill('ALL', 'All Specialists', Icons.medical_services_rounded),
                _specialityPill('Cardiologist', 'Cardiology', Icons.favorite_rounded),
                _specialityPill('General Physician', 'General Physician', Icons.health_and_safety_rounded),
                _specialityPill('Pediatrician', 'Pediatrics', Icons.child_care_rounded),
                _specialityPill('Dermatologist', 'Dermatology', Icons.face_retouching_natural_rounded),
                ..._specialities
                    .where((s) => !['ALL', 'Cardiologist', 'General Physician', 'Pediatrician', 'Dermatologist']
                        .contains(s.toString()))
                    .map((s) => _specialityPill(s.toString(), s.toString(), Icons.medical_information_rounded)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specialityPill(String key, String label, IconData icon) {
    final sel = _selectedSpeciality.toLowerCase() == key.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 16, color: sel ? Colors.white : primaryTeal),
        label: Text(label),
        selected: sel,
        selectedColor: primaryTeal,
        backgroundColor: Colors.white,
        side: BorderSide(color: sel ? primaryTeal : slateCardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(
          color: sel ? Colors.white : darkSlate,
          fontSize: 12,
          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
        ),
        onSelected: (val) {
          setState(() => _selectedSpeciality = val ? key : 'ALL');
          _fetchDoctors();
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: slateCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history_edu_rounded, color: primaryTeal, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'My Patient Medical History & Consultations',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkSlate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'View all your upcoming and past doctor appointments, clinical diagnosis, and print medical prescriptions.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (_patientProfile != null) ...[
                      // Logged-in verified patient header: strictly locked to user's registered profile!
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFDCFCE7),
                              child: Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _patientProfile!['name'] ?? 'Registered Patient',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Verified Patient', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Mobile: ' + (_patientProfile!['phone'] ?? '-') + '  •  Email: ' + (_patientProfile!['email'] ?? '-'),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF166534), size: 20),
                              tooltip: 'Refresh My Records',
                              onPressed: _fetchPatientHistory,
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.logout_rounded, size: 14, color: Colors.red),
                              label: const Text('Sign Out', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                              onPressed: _clearPatientProfile,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Not logged in: lookup via phone / email
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _historyLookupCtrl,
                              decoration: InputDecoration(
                                labelText: 'Registered Mobile Phone or Email',
                                prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                                hintText: 'Enter your phone or email to view your records',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _fetchPatientHistory(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _fetchPatientHistory,
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('View My Records'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Active Therapy Packages & Subscriptions (filtered strictly for clinic therapy packages)
              (() {
                final clinicPackages = _patientSubscriptions.where((sub) {
                  final nameLower = (sub['package_name'] ?? '').toString().toLowerCase();
                  return !(nameLower.contains('milk') ||
                      nameLower.contains('rice') ||
                      nameLower.contains('backpack') ||
                      nameLower.contains('oil') ||
                      nameLower.contains('ghee') ||
                      nameLower.contains('dairy'));
                }).toList();

                if (clinicPackages.isEmpty) return const SizedBox.shrink();

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: Color(0xFF7C3AED), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'My Active Therapy & Treatment Packages',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF581C87)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${clinicPackages.length} Active',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...clinicPackages.map((sub) {
                            final total = int.tryParse('${sub['total_sessions']}') ?? 6;
                            final done = int.tryParse('${sub['services_consumed']}') ?? 0;
                            final left = int.tryParse('${sub['remaining_sessions']}') ?? (total - done);
                            final prog = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        sub['package_name'] ?? 'Therapy Package',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$done of $total Consumed ($left Left)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF7C3AED)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: prog,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Validity: ${sub['start_date'] ?? ''} to ${sub['end_date'] ?? 'End of Month'}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              })(),

              if (_isLoadingHistory)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: primaryTeal)),
                )
              else if (_patientHistory.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No appointments found for ' + (_historyLookupCtrl.text.trim().isEmpty ? 'your account' : _historyLookupCtrl.text.trim()) + '.',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        const Text('Book your first consultation to track prescriptions and bills here.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _patientHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final a = _patientHistory[idx];
                    final status = (a['status'] ?? 'SCHEDULED').toString().toUpperCase();
                    Color statusColor = Colors.orange;
                    if (status == 'VISITED' || status == 'COMPLETED') statusColor = const Color(0xFF16A34A);
                    if (status == 'CANCELLED') statusColor = Colors.red;

                    final fee = double.tryParse('${a['consultation_fee'] ?? 0}') ?? 0.0;
                    final payStatus = a['payment_status'] ?? 'PAY_LATER';

                    return Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: slateCardBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: primaryTeal.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, color: primaryTeal),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['doctor_name'] ?? 'Doctor',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkSlate),
                                      ),
                                      Text(
                                        a['department'] ?? 'General Consultation',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  '${a['appointment_date']} at ${a['appointment_time']}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                const Icon(Icons.payments_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  '${CurrencyService.format(fee)} ($payStatus)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: darkSlate),
                                ),
                              ],
                            ),
                            if (a['reason_for_visit'] != null && a['reason_for_visit'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Symptoms/Reason: ${a['reason_for_visit']}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: 250,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.print_rounded, size: 16),
                                    label: const Text('Download / Print Rx & Invoice'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryTeal,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _printPrescriptionOrInvoice(a),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DOCTOR & MULTI-DOCTOR CLINIC CARD (SWIGGY/DINING GRADE)
// ---------------------------------------------------------------------------
class _DoctorClinicCard extends StatefulWidget {
  final dynamic doctor;
  final ValueChanged<dynamic> onBook;
  final ValueChanged<String> onCall;
  final void Function(String phone, String doctorName) onWhatsApp;

  const _DoctorClinicCard({
    required this.doctor,
    required this.onBook,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  State<_DoctorClinicCard> createState() => _DoctorClinicCardState();
}

class _DoctorClinicCardState extends State<_DoctorClinicCard> {
  late dynamic _activeDoctor;
  List<dynamic> _clinicDoctors = [];

  @override
  void initState() {
    super.initState();
    _activeDoctor = widget.doctor;
    if (widget.doctor['clinic_doctors'] is List) {
      _clinicDoctors = widget.doctor['clinic_doctors'];
    } else {
      _clinicDoctors = [widget.doctor];
    }
  }

  @override
  void didUpdateWidget(covariant _DoctorClinicCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctor != widget.doctor) {
      _activeDoctor = widget.doctor;
      if (widget.doctor['clinic_doctors'] is List) {
        _clinicDoctors = widget.doctor['clinic_doctors'];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _activeDoctor;
    final isVerified = doc['is_verified_badge'] != false;
    final rawRating = doc['rating'];
    final num? rating = (rawRating is num && rawRating > 0 && (doc['rating_count'] ?? 0) > 0) ? rawRating : null;
    final exp = doc['experience_years'] ?? 8;
    final fee = doc['consultation_fee'] ?? 500;
    final regNo = doc['registration_no'] ?? '';
    final clinicName = widget.doctor['clinic_name'] ?? 'Healthcare Clinic';
    final address = widget.doctor['address'] ?? '';
    final city = widget.doctor['city'] ?? '';
    final phone = widget.doctor['phone'] ?? '';
    final whatsapp = widget.doctor['whatsapp'] ?? phone;

    final hasMultipleDoctors = _clinicDoctors.length > 1;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Doctor Avatar, Name, Speciality & Fee
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Avatar
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF0F766E).withOpacity(0.12),
                  child: Text(
                    (doc['name'] ?? 'Dr')
                        .toString()
                        .replaceAll('Dr. ', '')
                        .replaceAll('Dr ', '')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF0F766E)),
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              doc['name'] ?? 'Doctor',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: Color(0xFF0D9488), size: 18),
                            const SizedBox(width: 2),
                            const Text(
                              'Verified',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${doc['speciality'] ?? 'General Physician'} • ${doc['qualification'] ?? 'MBBS'}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                      ),
                      if (regNo.toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Reg: $regNo',
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                        ),
                      ],
                      const SizedBox(height: 6),

                      // Badges: Real Rating (if available) & Experience
                      Row(
                        children: [
                          if (rating != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 14),
                                  const SizedBox(width: 3),
                                  Text('$rating', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$exp+ Years Clinical Exp.',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Consultation Fee Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text(
                        CurrencyService.format(fee),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text('Consultation Fee', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),

            // Multi-Doctor Clinic Selector
            if (hasMultipleDoctors) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
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
                        const Icon(Icons.people_alt_rounded, size: 15, color: Color(0xFF0F766E)),
                        const SizedBox(width: 6),
                        Text(
                          '${_clinicDoctors.length} Doctors available at $clinicName (Select to view fee):',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _clinicDoctors.map((d) {
                        final isSelected = d['id'] == _activeDoctor['id'];
                        final dFee = d['consultation_fee'] ?? 0;
                        return ChoiceChip(
                          avatar: Icon(Icons.person, size: 14, color: isSelected ? Colors.white : const Color(0xFF0F766E)),
                          label: Text('${d['name']} (${CurrencyService.format(dFee)})'),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0F766E),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1)),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _activeDoctor = Map<String, dynamic>.from(widget.doctor as Map)
                                  ..addAll(Map<String, dynamic>.from(d as Map));
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 22),

            // Clinic Location, Schedule & Actions
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$clinicName • $address, $city',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Builder(
                  builder: (ctx) {
                    final rawDays = (doc['available_days'] is List ? (doc['available_days'] as List).join(', ') : (doc['available_days'] ?? 'Mon - Sat')).toString();
                    final startTime = (doc['start_time'] ?? '09:00 AM').toString();
                    final endTime = (doc['end_time'] ?? '06:00 PM').toString();
                    return Text('Schedule: ' + rawDays + ' (' + startTime + ' - ' + endTime + ')',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w600));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions Row: Direct WhatsApp, Call, Book Appointment
            Row(
              children: [
                if (whatsapp.toString().isNotEmpty) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF25D366)),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => widget.onWhatsApp(whatsapp.toString(), doc['name'] ?? ''),
                  ),
                  const SizedBox(width: 8),
                ],
                if (phone.toString().isNotEmpty) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call_outlined, size: 14, color: Color(0xFF0F766E)),
                    label: const Text('Call Clinic', style: TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF99F6E4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => widget.onCall(phone.toString()),
                  ),
                ],
                const Spacer(),

                // BOOK APPOINTMENT ACTION BUTTON
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text('Book Consultation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => widget.onBook(_activeDoctor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PATIENT REGISTRATION BOTTOM SHEET (SWIGGY / DINING STANDARD)
// ---------------------------------------------------------------------------
class _PatientRegistrationBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;
  final ValueChanged<Map<String, dynamic>> onProfileSaved;

  const _PatientRegistrationBottomSheet({
    this.initialProfile,
    required this.onProfileSaved,
  });

  @override
  State<_PatientRegistrationBottomSheet> createState() => _PatientRegistrationBottomSheetState();
}

class _PatientRegistrationBottomSheetState extends State<_PatientRegistrationBottomSheet> {
  // Mode: 0 = Sign In (Existing Patient), 1 = Register / Edit Profile
  int _activeMode = 1;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _gender = 'MALE';

  // Login controllers
  final _loginEmailCtrl = TextEditingController();

  // Verification OTP state
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  String _targetEmail = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      final p = widget.initialProfile!;
      _nameCtrl.text = p['name'] ?? '';
      _phoneCtrl.text = p['phone'] ?? '';
      _emailCtrl.text = p['email'] ?? '';
      _loginEmailCtrl.text = p['email'] ?? '';
      _ageCtrl.text = p['age'] != null ? '${p['age']}' : '';
      _addressCtrl.text = p['address'] ?? '';
      _gender = p['gender'] ?? 'MALE';
      _activeMode = 1; // Edit profile
    } else {
      _activeMode = 0; // Default to Sign In if not logged in
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _loginEmailCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRegistrationOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim().toLowerCase();
    setState(() {
      _isSendingOtp = true;
      _targetEmail = email;
    });

    try {
      final res = await ApiClient.post('/api/public/clinic/request-email-otp', {'email': email});
      if (res != null && res['success'] == true) {
        setState(() {
          _otpSent = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0F766E),
              content: Text('Verification code sent to $email. Please enter it below.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Failed to send verification code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending email code: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _sendLoginOtp() async {
    final email = _loginEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid registered email address')),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _targetEmail = email;
    });

    try {
      final res = await ApiClient.post('/api/public/clinic/request-email-otp', {'email': email});
      if (res != null && res['success'] == true) {
        setState(() {
          _otpSent = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0F766E),
              content: Text('Login code sent to $email. Enter it to sign in.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Failed to send login code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending code: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtpAndComplete() async {
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
        'email': _targetEmail,
        'otp': otp,
      });

      if (res != null && res['success'] == true) {
        Map<String, dynamic> profile;

        if (_activeMode == 0 && res['patient'] != null) {
          // Existing patient login
          final p = res['patient'];
          profile = {
            'name': p['name'] ?? 'Patient',
            'phone': p['phone'] ?? '',
            'email': _targetEmail,
            'age': p['age'] ?? 25,
            'gender': p['gender'] ?? 'MALE',
            'address': p['address'] ?? '',
            'is_email_verified': true,
            'registered_at': DateTime.now().toIso8601String(),
          };
        } else {
          // New registration or edit profile
          profile = {
            'name': _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : (res['patient']?['name'] ?? 'Patient'),
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : (res['patient']?['phone'] ?? ''),
            'email': _targetEmail,
            'age': int.tryParse(_ageCtrl.text.trim()) ?? (res['patient']?['age'] ?? 25),
            'gender': _gender,
            'address': _addressCtrl.text.trim(),
            'is_email_verified': true,
            'registered_at': DateTime.now().toIso8601String(),
          };
        }

        if (!mounted) return;
        Navigator.pop(context); // Close dialog on verify
        widget.onProfileSaved(profile);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(_activeMode == 0
                ? 'Welcome back, ${profile['name']}! Signed in successfully.'
                : 'Email verified and patient profile registered!'),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Invalid verification code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialProfile != null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_pin_rounded, color: Color(0xFF0F766E), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditMode
                            ? 'Edit Patient Profile'
                            : (_activeMode == 0 ? 'Patient Sign In' : 'Quick Patient Registration'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        _activeMode == 0
                            ? 'Sign in with your email to access history & 1-tap bookings'
                            : 'Register with verified email to receive digital prescriptions & bills',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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

            if (!isEditMode && !_otpSent) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Existing Patient Sign In')),
                      selected: _activeMode == 0,
                      selectedColor: const Color(0xFF0F766E),
                      labelStyle: TextStyle(
                        color: _activeMode == 0 ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (v) => setState(() {
                        _activeMode = 0;
                        _otpSent = false;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('New Patient Sign Up')),
                      selected: _activeMode == 1,
                      selectedColor: const Color(0xFF0F766E),
                      labelStyle: TextStyle(
                        color: _activeMode == 1 ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (v) => setState(() {
                        _activeMode = 1;
                        _otpSent = false;
                      }),
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 24),

            // OTP VERIFICATION STEP (COMMON FOR BOTH LOGIN & REGISTRATION)
            if (_otpSent) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mark_email_read_rounded, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Verification code sent to $_targetEmail',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-Digit Email Code *',
                        hintText: 'e.g. 123456',
                        prefixIcon: Icon(Icons.password_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _isSendingOtp ? null : (_activeMode == 0 ? _sendLoginOtp : _sendRegistrationOtp),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Resend Code', style: TextStyle(fontSize: 12)),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: _isVerifyingOtp
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.verified_rounded, size: 16),
                          label: const Text('VERIFY & CLOSE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          onPressed: _isVerifyingOtp ? null : _verifyOtpAndComplete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_activeMode == 0 && !isEditMode) ...[
              // SIGN IN MODE FORM
              TextField(
                controller: _loginEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Registered Patient Email *',
                  hintText: 'e.g. studentsdav6@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSendingOtp
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login_rounded),
                  label: const Text('SEND LOGIN CODE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSendingOtp ? null : _sendLoginOtp,
                ),
              ),
            ] else ...[
              // REGISTER / EDIT PROFILE FORM
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Patient Full Name *',
                        hintText: 'e.g. Ajay Prajapati',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter patient full name' : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Mobile Phone *',
                              hintText: 'e.g. 6395059482',
                              prefixIcon: const Icon(Icons.phone_android_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Age',
                              hintText: 'e.g. 25',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address * (For Report & Verification Code)',
                        hintText: 'e.g. studentsdav6@gmail.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'MALE', child: Text('Male')),
                              DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                              DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                            ],
                            onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _addressCtrl,
                            decoration: InputDecoration(
                              labelText: 'City / Residential Area',
                              hintText: 'e.g. Dehradun',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isSendingOtp
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label: const Text('VERIFY EMAIL & SAVE PROFILE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSendingOtp ? null : _sendRegistrationOtp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoctorBookingDialog extends StatefulWidget {
  final dynamic doctor;
  final Map<String, dynamic>? patientProfile;
  final List<dynamic>? patientSubscriptions;
  final VoidCallback onBooked;

  const _DoctorBookingDialog({
    required this.doctor,
    this.patientProfile,
    this.patientSubscriptions,
    required this.onBooked,
  });

  @override
  State<_DoctorBookingDialog> createState() => _DoctorBookingDialogState();
}

class _DoctorBookingDialogState extends State<_DoctorBookingDialog> {
  late dynamic _selectedDoctor;
  List<dynamic> _availableClinicDoctors = [];
  List<dynamic> _activePackages = [];
  dynamic _selectedPackage;

  // Patient Info (Auto-Filled from Profile)
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _gender = 'MALE';

  // Date & Time Slot
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = '10:00 AM';
  bool _isSubmitting = false;

  // Payment Options
  String _paymentOption = 'PAY_LATER'; // 'PAY_LATER', 'PREPAID', 'PACKAGE'
  String _prepaidMode = 'UPI'; // 'UPI', 'CARD', 'ONLINE_GATEWAY'
  final _packageNameCtrl = TextEditingController(text: 'Therapy Care Plan');
  final _sessionNumCtrl = TextEditingController(text: '1');
  final _totalSessionsCtrl = TextEditingController(text: '6');

  // OTP Verification for guest bookings
  bool _otpSent = false;
  final _otpCtrl = TextEditingController();
  bool _isSendingOtp = false;

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address first')),
      );
      return;
    }
    setState(() => _isSendingOtp = true);
    try {
      final res = await ApiClient.post('/api/public/clinic/request-email-otp', {'email': email});
      if (res != null && res['success'] == true) {
        setState(() => _otpSent = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Verification code sent to $email'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Failed to send verification code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending code: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  List<String> _generateSlotsForDoctor() {
    final startTimeStr = (_selectedDoctor['start_time'] ?? '09:00 AM').toString();
    final endTimeStr = (_selectedDoctor['end_time'] ?? '06:00 PM').toString();
    final intervalMins = int.tryParse('${_selectedDoctor['slot_duration_minutes'] ?? 30}') ?? 30;

    int parseMinutes(String timeStr) {
      try {
        final parts = timeStr.trim().split(' ');
        final timeParts = parts[0].split(':');
        int h = int.parse(timeParts[0]);
        int m = int.parse(timeParts[1]);
        if (parts.length > 1) {
          final period = parts[1].toUpperCase();
          if (period == 'PM' && h < 12) h += 12;
          if (period == 'AM' && h == 12) h = 0;
        }
        return h * 60 + m;
      } catch (_) {
        return 9 * 60;
      }
    }

    String formatMinutes(int totalMins) {
      int h = (totalMins ~/ 60) % 24;
      int m = totalMins % 60;
      final period = h >= 12 ? 'PM' : 'AM';
      int displayH = h % 12;
      if (displayH == 0) displayH = 12;
      return '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    }

    int startMins = parseMinutes(startTimeStr);
    int endMins = parseMinutes(endTimeStr);
    if (endMins <= startMins) endMins = startMins + 480;

    final List<String> result = [];
    for (int cur = startMins; cur < endMins; cur += intervalMins) {
      result.add(formatMinutes(cur));
    }
    return result.isNotEmpty ? result : [
      '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM',
      '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM',
    ];
  }

  static const Map<int, List<String>> _weekdayAliases = {
    DateTime.monday: ['MON', 'MONDAY'],
    DateTime.tuesday: ['TUE', 'TUESDAY'],
    DateTime.wednesday: ['WED', 'WEDNESDAY'],
    DateTime.thursday: ['THU', 'THURSDAY'],
    DateTime.friday: ['FRI', 'FRIDAY'],
    DateTime.saturday: ['SAT', 'SATURDAY'],
    DateTime.sunday: ['SUN', 'SUNDAY'],
  };

  List<String> _getDoctorAvailableDays(dynamic doc) {
    if (doc == null) return ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final rawDays = doc['available_days'];
    List<String> daysList = [];
    if (rawDays is List) {
      daysList = rawDays.map((x) => x.toString().trim().toUpperCase()).where((x) => x.isNotEmpty).toList();
    } else if (rawDays is String && rawDays.trim().isNotEmpty) {
      final str = rawDays.trim();
      if (str.startsWith('[') && str.endsWith(']')) {
        try {
          final decoded = jsonDecode(str);
          if (decoded is List) {
            daysList = decoded.map((x) => x.toString().trim().toUpperCase()).where((x) => x.isNotEmpty).toList();
          }
        } catch (_) {}
      }
      if (daysList.isEmpty) {
        daysList = str.split(',').map((x) => x.trim().toUpperCase()).where((x) => x.isNotEmpty).toList();
      }
    }
    if (daysList.isEmpty) {
      daysList = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    }
    return daysList;
  }

  bool _isDoctorAvailableOn(DateTime date, dynamic doc) {
    final days = _getDoctorAvailableDays(doc);
    final aliases = _weekdayAliases[date.weekday] ?? [];
    return days.any((d) {
      final clean = d.replaceAll(RegExp(r'[^A-Z]'), '');
      return aliases.any((a) => clean == a || clean.startsWith(a) || a.startsWith(clean));
    });
  }

  DateTime _findNextAvailableDate(DateTime fromDate, dynamic doc) {
    final now = DateTime.now();
    DateTime cursor = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final todayStart = DateTime(now.year, now.month, now.day);
    if (cursor.isBefore(todayStart)) {
      cursor = todayStart;
    }
    for (int i = 0; i < 90; i++) {
      final candidate = cursor.add(Duration(days: i));
      if (_isDoctorAvailableOn(candidate, doc)) {
        return candidate;
      }
    }
    return cursor;
  }

  String _getDoctorAvailableDaysDisplay(dynamic doc) {
    final days = _getDoctorAvailableDays(doc);
    return days.join(', ');
  }

  @override
  void initState() {
    super.initState();
    _selectedDoctor = widget.doctor;
    if (widget.doctor['clinic_doctors'] is List) {
      _availableClinicDoctors = widget.doctor['clinic_doctors'];
    } else {
      _availableClinicDoctors = [widget.doctor];
    }

    // Auto-select the first available date for this doctor starting today
    final now = DateTime.now();
    _selectedDate = _findNextAvailableDate(DateTime(now.year, now.month, now.day), _selectedDoctor);

    // Auto-fill from patientProfile
    if (widget.patientProfile != null) {
      final p = widget.patientProfile!;
      _nameCtrl.text = p['name'] ?? '';
      _phoneCtrl.text = p['phone'] ?? '';
      _emailCtrl.text = p['email'] ?? '';
      _ageCtrl.text = p['age'] != null ? '${p['age']}' : '25';
      _gender = p['gender'] ?? 'MALE';
    }

    if (widget.patientSubscriptions != null && widget.patientSubscriptions!.isNotEmpty) {
      _activePackages = widget.patientSubscriptions!.where((p) {
        final total = int.tryParse('${p['total_sessions']}') ?? 6;
        final done = int.tryParse('${p['services_consumed']}') ?? 0;
        return (total - done) > 0;
      }).toList();
    } else {
      _fetchActiveSubscriptions();
    }
  }

  void _autoSelectFirstActivePackage() {
    // Left available as a manual helper if needed
  }

  Future<void> _fetchActiveSubscriptions() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    try {
      final res = await ApiClient.get('/api/public/clinic/patient-subscriptions', queryParams: {'phone': phone});
      if (res != null && res['data'] is List && mounted) {
        setState(() {
          _activePackages = (res['data'] as List).where((p) {
            final total = int.tryParse('${p['total_sessions']}') ?? 6;
            final done = int.tryParse('${p['services_consumed']}') ?? 0;
            return (total - done) > 0;
          }).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    _reasonCtrl.dispose();
    _packageNameCtrl.dispose();
    _sessionNumCtrl.dispose();
    _totalSessionsCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient name and phone number are required')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      double fee = double.tryParse('${_selectedDoctor['consultation_fee'] ?? 0}') ?? 0.0;

      String payStatus = 'PAY_LATER';
      String? payMode = 'PAY_LATER';
      double paidAmt = 0.0;
      bool isPack = false;
      String? packName;
      int? sessNum;
      int? totSess;

      if (_paymentOption == 'PREPAID') {
        payStatus = 'PAID';
        payMode = _prepaidMode;
        paidAmt = fee;
      } else if (_paymentOption == 'PACKAGE') {
        payStatus = 'PACKAGE_INCLUDED';
        payMode = 'PACKAGE_SUBSCRIPTION';
        isPack = true;
        packName = _selectedPackage?['package_name'] ?? (_packageNameCtrl.text.trim().isNotEmpty ? _packageNameCtrl.text.trim() : 'Therapy Care Plan');
        sessNum = int.tryParse(_sessionNumCtrl.text.trim()) ?? 1;
        totSess = int.tryParse(_totalSessionsCtrl.text.trim()) ?? 6;
        fee = 0.0; // Covered by active package -> by default fee is 0!
        paidAmt = 0.0;
      }

      final isVerifiedUser = widget.patientProfile != null || (widget.patientProfile?['is_verified'] == true);
      final otpVal = _otpCtrl.text.trim();

      final res = await ApiClient.post('/api/public/clinic/appointment', {
        'outlet_id': _selectedDoctor['outlet_id'] ?? widget.doctor['outlet_id'],
        'patient_name': name,
        'patient_phone': phone,
        'patient_email': email,
        'is_verified': isVerifiedUser,
        'is_email_verified': isVerifiedUser,
        'email_otp': otpVal.isNotEmpty ? otpVal : null,
        'patient_age': int.tryParse(_ageCtrl.text.trim()),
        'patient_gender': _gender,
        'appointment_date': formattedDate,
        'appointment_time': _selectedSlot,
        'doctor_name': _selectedDoctor['name'],
        'doctor_id': _selectedDoctor['id'],
        'consultation_fee': fee,
        'payment_status': payStatus,
        'payment_mode': payMode,
        'paid_amount': paidAmt,
        'package_name': packName,
        'session_number': sessNum,
        'total_package_sessions': totSess,
        'is_package_session': isPack,
        'department': _selectedDoctor['speciality'],
        'reason_for_visit': _reasonCtrl.text.trim(),
      });

      if (res != null && res['success'] == true) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onBooked();

        if (mounted) {
          showDialog(
            context: context,
            builder: (sCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
                  SizedBox(width: 10),
                  Text('Booking Confirmed!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your appointment with ${_selectedDoctor['name']} has been confirmed!',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📅 Scheduled Date: $formattedDate at $_selectedSlot', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                        const SizedBox(height: 4),
                        Text('🏥 Clinic / OPD: ${widget.doctor['clinic_name'] ?? 'Main Clinic'}', style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
                        const SizedBox(height: 4),
                        Text(isPack ? '🎟️ Covered by Package: $packName' : '💳 Consultation Fee: ${CurrencyService.format(fee)} ($payStatus)', style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
                        const SizedBox(height: 4),
                        Text('🔖 Token / Ref No: #${res['data']?['id'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF166534))),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(sCtx),
                  child: const Text('View My Consultations'),
                ),
              ],
            ),
          );
        }
      } else if (res != null && res['requires_email_verification'] == true) {
        if (!_otpSent) {
          _sendOtp();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Verification code sent to your email. Please enter the OTP to confirm.'),
              backgroundColor: const Color(0xFFD97706),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Failed to book appointment')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawFee = double.tryParse('${_selectedDoctor['consultation_fee'] ?? 0}') ?? 0.0;
    final fee = _paymentOption == 'PACKAGE' ? 0.0 : rawFee;
    final hasMultiDoctors = _availableClinicDoctors.length > 1;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0F766E).withOpacity(0.12),
            child: const Icon(Icons.medical_services_rounded, color: Color(0xFF0F766E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book with ${_selectedDoctor['name']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  '${_selectedDoctor['speciality']} • ${widget.doctor['clinic_name']}',
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
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Doctor Switcher (If multiple clinicians at this clinic)
              if (hasMultiDoctors) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Doctor at this Clinic (Fee Auto-updates):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _selectedDoctor['id'] as int?,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: _availableClinicDoctors.map<DropdownMenuItem<int>>((d) {
                          final dFee = d['consultation_fee'] ?? 0;
                          return DropdownMenuItem<int>(
                            value: d['id'] as int,
                            child: Text(
                              '${d['name']} - ${d['speciality']} (${CurrencyService.format(dFee)})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            final match = _availableClinicDoctors.firstWhere((d) => d['id'] == newId, orElse: () => _selectedDoctor);
                            setState(() {
                              _selectedDoctor = Map<String, dynamic>.from(widget.doctor as Map)
                                ..addAll(Map<String, dynamic>.from(match as Map));

                              // Auto-adjust date if current date is not an available day for the newly selected doctor
                              if (!_isDoctorAvailableOn(_selectedDate, _selectedDoctor)) {
                                final now = DateTime.now();
                                _selectedDate = _findNextAvailableDate(DateTime(now.year, now.month, now.day), _selectedDoctor);
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Auto-Filled Patient Profile Header
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Patient Details (Auto-filled from your registered profile):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Patient Name & Phone
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Patient Full Name *', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile Phone *', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Email, Age & Gender
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email Address', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
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
              if (_otpSent) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: '6-Digit Email Verification Code',
                            hintText: 'Enter OTP sent to email',
                            counterText: '',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.mark_email_read_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _isSendingOtp ? null : _sendOtp,
                        icon: _isSendingOtp
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, size: 16),
                        label: const Text('Resend Code', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // 2. Appointment Date & Time Slot
              const Text('Appointment Date & Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16, color: Color(0xFF0F766E)),
                      label: Text(DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                      onPressed: () async {
                        final now = DateTime.now();
                        final firstDate = DateTime(now.year, now.month, now.day);
                        final lastDate = firstDate.add(const Duration(days: 90));

                        DateTime initial = _selectedDate;
                        if (initial.isBefore(firstDate) || !_isDoctorAvailableOn(initial, _selectedDoctor)) {
                          initial = _findNextAvailableDate(firstDate, _selectedDoctor);
                        }
                        if (initial.isAfter(lastDate)) initial = lastDate;

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: firstDate,
                          lastDate: lastDate,
                          selectableDayPredicate: (DateTime day) {
                            return _isDoctorAvailableOn(day, _selectedDoctor);
                          },
                          helpText: 'Select Available Consultation Date',
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Scheduled Working Days info badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCCFBF1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Scheduled Days: ${_getDoctorAvailableDaysDisplay(_selectedDoctor)} (Unavailable days disabled)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (ctx) {
                  final isAvailable = _isDoctorAvailableOn(_selectedDate, _selectedDoctor);

                  if (!isAvailable) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dr. ' + (_selectedDoctor['name'] ?? 'Doctor').toString() + ' is not scheduled on ' + DateFormat('EEEE').format(_selectedDate) + '. Available days: ' + _getDoctorAvailableDaysDisplay(_selectedDoctor) + '. Please pick an active working day.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final dynamicSlots = _generateSlotsForDoctor();
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: dynamicSlots.map((s) {
                      final sel = _selectedSlot == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: sel,
                        selectedColor: const Color(0xFF0F766E),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: sel ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1)),
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedSlot = s);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 3. Consultation Fee & Payment Mode
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payment_rounded, color: Color(0xFF0F766E), size: 18),
                        const SizedBox(width: 6),
                        const Text('Consultation Fee & Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _paymentOption == 'PACKAGE' ? const Color(0xFFFAF5FF) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _paymentOption == 'PACKAGE' ? const Color(0xFFD8B4FE) : const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            _paymentOption == 'PACKAGE' ? 'Covered by Package (Free €0.00)' : 'Fee: ${CurrencyService.format(fee)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _paymentOption == 'PACKAGE' ? const Color(0xFF7C3AED) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Active Packages Selector (Auto 0 Fee)
                    if (_activePackages.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.stars_rounded, color: Color(0xFF7C3AED), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'My Active Treatment / Therapy Packages (Select to Cover Fee):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6B21A8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ..._activePackages.map((sub) {
                                  final isSel = _paymentOption == 'PACKAGE' && _selectedPackage?['id'] == sub['id'];
                                  final total = int.tryParse('${sub['total_sessions']}') ?? 6;
                                  final done = int.tryParse('${sub['services_consumed']}') ?? 0;
                                  final left = int.tryParse('${sub['remaining_sessions']}') ?? (total - done);
                                  return ChoiceChip(
                                    avatar: Icon(Icons.check_circle, size: 14, color: isSel ? Colors.white : const Color(0xFF7C3AED)),
                                    label: Text('${sub['package_name']} ($left Left) • Free (€0.00)'),
                                    selected: isSel,
                                    selectedColor: const Color(0xFF7C3AED),
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: isSel ? Colors.white : const Color(0xFF581C87),
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _paymentOption = 'PACKAGE';
                                          _selectedPackage = sub;
                                          _packageNameCtrl.text = sub['package_name'] ?? 'Therapy Package';
                                          _sessionNumCtrl.text = '${done + 1}';
                                          _totalSessionsCtrl.text = '$total';
                                        });
                                      }
                                    },
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Payment Mode Chips (Respecting Gateway Enablement & Universal Modes)
                    Builder(
                      builder: (ctx) {
                        final isGatewayEnabled = _selectedDoctor['is_gateway_enabled'] == true;
                        if (!isGatewayEnabled && _paymentOption == 'PREPAID') {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _paymentOption = 'PAY_LATER');
                          });
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              label: Text(_activePackages.isNotEmpty ? 'Standard Consultation (${CurrencyService.format(rawFee)})' : 'Pay Later at Clinic (Reception Desk)'),
                              selected: _paymentOption == 'PAY_LATER',
                              selectedColor: const Color(0xFF0F766E),
                              labelStyle: TextStyle(
                                color: _paymentOption == 'PAY_LATER' ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 11,
                                fontWeight: _paymentOption == 'PAY_LATER' ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (v) {
                                setState(() {
                                  _paymentOption = 'PAY_LATER';
                                  _selectedPackage = null;
                                });
                              },
                            ),
                            if (isGatewayEnabled) ...[
                              ChoiceChip(
                                label: const Text('Prepay Online Gateway'),
                                selected: _paymentOption == 'PREPAID',
                                selectedColor: const Color(0xFF16A34A),
                                labelStyle: TextStyle(
                                  color: _paymentOption == 'PREPAID' ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 11,
                                  fontWeight: _paymentOption == 'PREPAID' ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (v) => setState(() => _paymentOption = 'PREPAID'),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    if (_paymentOption == 'PREPAID') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Gateway Mode: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          ...['UPI', 'CARD', 'ONLINE_GATEWAY'].map((m) {
                            final sel = _prepaidMode == m;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(m),
                                selected: sel,
                                selectedColor: const Color(0xFF16A34A),
                                labelStyle: TextStyle(
                                  color: sel ? Colors.white : Colors.black87,
                                  fontSize: 10,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (v) => setState(() => _prepaidMode = m),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],

                    if (_paymentOption == 'PACKAGE') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _packageNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Package / Care Plan Name',
                          hintText: 'e.g. Physiotherapy 6-Sessions Care Plan',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sessionNumCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Current Session #', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _totalSessionsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Total Free / Covered', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Reason for Consultation
              TextField(
                controller: _reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Symptoms / Reason for Consultation (Optional)',
                  hintText: 'e.g. Fever, routine checkup, back pain...',
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
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: _isSubmitting ? null : _confirmBooking,
          icon: const Icon(Icons.check, size: 16),
          label: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('CONFIRM & BOOK APPOINTMENT'),
        ),
      ],
    );
  }
}

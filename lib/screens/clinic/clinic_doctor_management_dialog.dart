import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

class ClinicDoctorManagementDialog extends StatefulWidget {
  final VoidCallback? onDoctorsChanged;

  const ClinicDoctorManagementDialog({
    super.key,
    this.onDoctorsChanged,
  });

  @override
  State<ClinicDoctorManagementDialog> createState() => _ClinicDoctorManagementDialogState();
}

class _ClinicDoctorManagementDialogState extends State<ClinicDoctorManagementDialog> {
  bool _loading = true;
  List<dynamic> _doctors = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicDoctors);
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _doctors = res['data'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load clinic doctors: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDoctorFormModal([dynamic doctor]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DoctorProfileFormDialog(
        doctor: doctor,
        onSaved: () {
          _fetchDoctors();
          widget.onDoctorsChanged?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clinic Doctor Profiles & Public Directory Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Manage consulting doctors, consultation fees, public listing settings & referral tracking',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 880,
        height: 520,
        child: Column(
          children: [
            // Top action bar
            Row(
              children: [
                Text(
                  '${_doctors.length} Registered Doctor${_doctors.length == 1 ? "" : "s"} in Clinic',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Doctor Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _openDoctorFormModal(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Doctors list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _doctors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add_disabled_rounded, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('No doctors configured yet for this clinic.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              const Text('Click "Add Doctor Profile" to register consulting specialists.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _doctors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) => _buildDoctorCard(_doctors[idx]),
                        ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(dynamic doc) {
    final bool isPublic = doc['is_public_listed'] == true;
    final fee = NumberFormat('#,##0.00').format(doc['consultation_fee'] ?? 0);
    final totalPatients = doc['total_patients'] ?? 0;
    final totalFees = NumberFormat('#,##0.00').format(doc['total_fees_collected'] ?? 0);
    final medSales = NumberFormat('#,##0.00').format(doc['referred_medicine_sales'] ?? 0);

    final displayOpts = doc['public_display_options'] is Map ? doc['public_display_options'] : {};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF0284C7).withOpacity(0.1),
                child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0284C7), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          doc['full_name'] ?? 'Doctor',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPublic ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isPublic ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isPublic ? Icons.public : Icons.public_off, size: 12, color: isPublic ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                isPublic ? 'Public Online' : 'Internal Only',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPublic ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${doc['speciality'] ?? 'Specialist'}  •  ${doc['qualification'] ?? ''} ${doc['registration_no'] != null && doc['registration_no'].toString().isNotEmpty ? " • Reg: ${doc['registration_no']}" : ""}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                    Text(
                      'Phone: ${doc['mobile'] ?? '--'}  •  WhatsApp: ${doc['whatsapp_no'] ?? '--'}  •  Email: ${doc['contact_email'] ?? '--'}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Fee badge & Edit button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      'Fee: ${CurrencyService.symbol}$fee',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Edit Profile & Public Settings', style: TextStyle(fontSize: 11)),
                    onPressed: () => _openDoctorFormModal(doc),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 18),

          // Statistics & Public Display Flags
          Row(
            children: [
              _statBadge(Icons.groups_rounded, '$totalPatients Patients', const Color(0xFF0284C7)),
              const SizedBox(width: 8),
              _statBadge(Icons.account_balance_wallet_rounded, 'OPD Fees: ${CurrencyService.symbol}$totalFees', const Color(0xFF059669)),
              const SizedBox(width: 8),
              _statBadge(Icons.medication_rounded, 'Referred Rx Sales: ${CurrencyService.symbol}$medSales', const Color(0xFF7C3AED)),
              const Spacer(),
              // Public display tags
              if (isPublic) ...[
                Text(
                  'Public Display: ${displayOpts['show_clinic_name'] == true ? "Clinic, " : ""}${displayOpts['show_doctor_name'] == true ? "Doctor, " : ""}${displayOpts['show_fees'] == true ? "Fees, " : ""}${displayOpts['show_phone'] == true ? "Contact" : ""}'.replaceAll(RegExp(r', $'), ''),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _DoctorProfileFormDialog extends StatefulWidget {
  final dynamic doctor;
  final VoidCallback onSaved;

  const _DoctorProfileFormDialog({this.doctor, required this.onSaved});

  @override
  State<_DoctorProfileFormDialog> createState() => _DoctorProfileFormDialogState();
}

class _DoctorProfileFormDialogState extends State<_DoctorProfileFormDialog> {
  final _nameCtrl = TextEditingController();
  final _specialityCtrl = TextEditingController(text: 'General Physician');
  final _qualificationCtrl = TextEditingController(text: 'MBBS, MD');
  final _regNoCtrl = TextEditingController();
  final _expCtrl = TextEditingController(text: '5');
  final _feeCtrl = TextEditingController(text: '500');
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _isPublicListed = true;

  // Display options
  bool _showClinicName = true;
  bool _showDoctorName = true;
  bool _showAddress = true;
  bool _showPhone = true;
  bool _showWhatsapp = true;
  bool _showEmail = true;
  bool _showFees = true;

  // Working Schedule & Timings
  List<String> _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  String _startTime = '09:00 AM';
  String _endTime = '06:00 PM';
  int _slotDuration = 30;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.doctor != null) {
      final d = widget.doctor;
      _nameCtrl.text = d['full_name'] ?? '';
      _specialityCtrl.text = d['speciality'] ?? 'General Physician';
      _qualificationCtrl.text = d['qualification'] ?? 'MBBS, MD';
      _regNoCtrl.text = d['registration_no'] ?? '';
      _expCtrl.text = '${d['experience_years'] ?? 5}';
      _feeCtrl.text = '${d['consultation_fee'] ?? 500}';
      _phoneCtrl.text = d['mobile'] ?? '';
      _whatsappCtrl.text = d['whatsapp_no'] ?? '';
      _emailCtrl.text = d['contact_email'] ?? '';
      _cityCtrl.text = d['doctor_city'] ?? '';
      _bioCtrl.text = d['doctor_bio'] ?? '';
      _isPublicListed = d['is_public_listed'] != false;

      final opts = d['public_display_options'];
      if (opts is Map) {
        _showClinicName = opts['show_clinic_name'] != false;
        _showDoctorName = opts['show_doctor_name'] != false;
        _showAddress = opts['show_address'] != false;
        _showPhone = opts['show_phone'] != false;
        _showWhatsapp = opts['show_whatsapp'] != false;
        _showEmail = opts['show_email'] != false;
        _showFees = opts['show_fees'] != false;
        if (opts['start_time'] != null) _startTime = opts['start_time'].toString();
        if (opts['end_time'] != null) _endTime = opts['end_time'].toString();
        if (opts['slot_duration_minutes'] != null) _slotDuration = int.tryParse(opts['slot_duration_minutes'].toString()) ?? 30;
      }
      if (d['available_days'] != null && d['available_days'].toString().isNotEmpty) {
        _selectedDays = d['available_days'].toString().split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specialityCtrl.dispose();
    _qualificationCtrl.dispose();
    _regNoCtrl.dispose();
    _expCtrl.dispose();
    _feeCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter doctor full name.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'full_name': _nameCtrl.text.trim(),
        'speciality': _specialityCtrl.text.trim(),
        'qualification': _qualificationCtrl.text.trim(),
        'registration_no': _regNoCtrl.text.trim(),
        'experience_years': int.tryParse(_expCtrl.text.trim()) ?? 0,
        'consultation_fee': double.tryParse(_feeCtrl.text.trim()) ?? 0.0,
        'mobile': _phoneCtrl.text.trim(),
        'whatsapp_no': _whatsappCtrl.text.trim().isNotEmpty ? _whatsappCtrl.text.trim() : _phoneCtrl.text.trim(),
        'contact_email': _emailCtrl.text.trim().toLowerCase(),
        'doctor_city': _cityCtrl.text.trim(),
        'doctor_bio': _bioCtrl.text.trim(),
        'is_public_listed': _isPublicListed,
        'available_days': _selectedDays.join(','),
        'public_display_options': {
          'show_clinic_name': _showClinicName,
          'show_doctor_name': _showDoctorName,
          'show_address': _showAddress,
          'show_phone': _showPhone,
          'show_whatsapp': _showWhatsapp,
          'show_email': _showEmail,
          'show_fees': _showFees,
          'available_days': _selectedDays.join(','),
          'start_time': _startTime,
          'end_time': _endTime,
          'slot_duration_minutes': _slotDuration,
        },
      };

      dynamic res;
      if (widget.doctor != null && widget.doctor['id'] != null) {
        res = await ApiClient.put(ApiEndpoints.clinicDoctor(widget.doctor['id']), payload);
      } else {
        res = await ApiClient.post(ApiEndpoints.clinicDoctors, payload);
      }

      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(res['message'] ?? 'Doctor profile saved successfully!'),
          ),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save doctor profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.doctor != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit_rounded : Icons.person_add_rounded, color: const Color(0xFF0284C7)),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Doctor Profile & Public Display' : 'Add New Consulting Doctor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic details
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Doctor Full Name * (e.g. Dr. Sneha Rao)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _specialityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Speciality (e.g. Cardiologist)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qualificationCtrl,
                      decoration: InputDecoration(
                        labelText: 'Qualifications (e.g. MBBS, MD)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _regNoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Medical Reg / License #',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _feeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Consultation Fee (${CurrencyService.symbol}) *',
                        prefixText: '${CurrencyService.symbol} ',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _expCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Experience (Years)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Contact Details
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _whatsappCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp Number',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Practicing City (e.g. New Delhi)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _bioCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Doctor Bio / Clinical Expertise Summary',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 14),

              // CLINIC & DOCTOR WORKING SCHEDULE / TIMING SETTINGS
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: Color(0xFF16A34A), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Doctor Consultation Schedule & Working Hours',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                          ),
                        ),
                        // Quick Presets
                        TextButton(
                          onPressed: () => setState(() => _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('Mon-Sat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('Mon-Fri', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('All 7 Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Available Days (Patient appointments are only allowed on these days):', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                        final sel = _selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: sel,
                          selectedColor: const Color(0xFF16A34A),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: sel ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 11,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedDays.add(day);
                              } else {
                                if (_selectedDays.length > 1) _selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _startTime,
                            decoration: InputDecoration(
                              labelText: 'Shift Start Time',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: ['08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (v) => setState(() => _startTime = v ?? '09:00 AM'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _endTime,
                            decoration: InputDecoration(
                              labelText: 'Shift End Time',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: ['01:00 PM', '02:00 PM', '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (v) => setState(() => _endTime = v ?? '06:00 PM'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _slotDuration,
                            decoration: InputDecoration(
                              labelText: 'Slot Duration',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 15, child: Text('15 Mins', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 20, child: Text('20 Mins', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 30, child: Text('30 Mins', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 45, child: Text('45 Mins', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 60, child: Text('60 Mins', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (v) => setState(() => _slotDuration = v ?? 30),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // PUBLIC PROFILE & DIRECTORY SETTINGS
              Container(
                padding: const EdgeInsets.all(14),
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
                        const Icon(Icons.public, color: Color(0xFF0284C7), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Public Profile & Online Booking Settings',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Switch.adaptive(
                          value: _isPublicListed,
                          onChanged: (v) => setState(() => _isPublicListed = v),
                        ),
                      ],
                    ),
                    Text(
                      _isPublicListed
                          ? 'This doctor will be publicly visible for patients in online directory and booking portal.'
                          : 'This doctor is hidden from public view and only available internally in clinic console.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),

                    if (_isPublicListed) ...[
                      const Divider(height: 18),
                      const Text(
                        'Select Details to Display to Public:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _checkOpt('Clinic Name', _showClinicName, (v) => setState(() => _showClinicName = v)),
                          _checkOpt('Doctor Name', _showDoctorName, (v) => setState(() => _showDoctorName = v)),
                          _checkOpt('Clinic Address & City', _showAddress, (v) => setState(() => _showAddress = v)),
                          _checkOpt('Phone Number', _showPhone, (v) => setState(() => _showPhone = v)),
                          _checkOpt('WhatsApp Number', _showWhatsapp, (v) => setState(() => _showWhatsapp = v)),
                          _checkOpt('Email Address', _showEmail, (v) => setState(() => _showEmail = v)),
                          _checkOpt('Consultation Fee', _showFees, (v) => setState(() => _showFees = v)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Save Changes' : 'Create Doctor Profile'),
        ),
      ],
    );
  }

  Widget _checkOpt(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          visualDensity: VisualDensity.compact,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
      ],
    );
  }
}

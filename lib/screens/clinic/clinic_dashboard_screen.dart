import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../inventory/salescreen.dart';

class ClinicDashboardScreen extends StatefulWidget {
  const ClinicDashboardScreen({super.key});

  @override
  State<ClinicDashboardScreen> createState() => _ClinicDashboardScreenState();
}

class _ClinicDashboardScreenState extends State<ClinicDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = false;
  List<dynamic> _appointments = [];
  Map<String, dynamic> _analytics = {};

  String _statusFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchAppointments();
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{
        'from_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      };
      if (_statusFilter != 'ALL') {
        queryParams['status'] = _statusFilter;
      }
      if (_searchCtrl.text.trim().isNotEmpty) {
        queryParams['search'] = _searchCtrl.text.trim();
      }

      final res = await ApiClient.get(
        ApiEndpoints.clinicAppointments,
        queryParams: queryParams,
      );

      if (res != null && res['success'] == true) {
        setState(() {
          _appointments = res['data'] ?? [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load appointments: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAnalytics() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicAnalytics);
      if (res != null && res['success'] == true) {
        setState(() {
          _analytics = Map<String, dynamic>.from(res['data'] ?? {});
        });
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(dynamic appointmentId, String newStatus) async {
    try {
      final res = await ApiClient.patch(
        ApiEndpoints.clinicAppointmentStatus(appointmentId),
        {'status': newStatus},
      );
      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment marked as $newStatus')),
        );
        _fetchAppointments();
        _fetchAnalytics();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _sendToBilling(dynamic appointment) async {
    try {
      final res = await ApiClient.post(
        ApiEndpoints.clinicAppointmentSendToBilling(appointment['id']),
        {},
      );

      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Prescription successfully sent to Billing draft! Opening POS...'),
          ),
        );
        _fetchAppointments();

        // Navigate to salescreen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SaleScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Could not send to billing')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send to billing: $e')),
      );
    }
  }

  void _openConsultationDialog(dynamic appointment) {
    showDialog(
      context: context,
      builder: (ctx) => _DoctorPrescriptionDialog(
        appointment: appointment,
        onSaved: () {
          _fetchAppointments();
          _fetchAnalytics();
        },
        onSendBilling: () => _sendToBilling(appointment),
      ),
    );
  }

  void _openNewAppointmentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _NewAppointmentDialog(
        onCreated: () {
          _fetchAppointments();
          _fetchAnalytics();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.medical_services_outlined, size: 24),
            SizedBox(width: 8),
            Text('Clinic & Doctor Consultation'),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'Appointments'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Reports & Analytics'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchAppointments();
              _fetchAnalytics();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildAppointmentsTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewAppointmentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Book Appointment'),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return Column(
      children: [
        _buildStatsBar(),
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _appointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No appointments found for selected filter.', style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _openNewAppointmentDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Book Appointment'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _appointments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) => _buildAppointmentCard(_appointments[idx]),
                    ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _kpiChip('Total Today', '${_appointments.length}', Colors.blue),
            const SizedBox(width: 8),
            _kpiChip('Visited', '${_appointments.where((a) => a['status'] == 'VISITED').length}', Colors.green),
            const SizedBox(width: 8),
            _kpiChip('Scheduled', '${_appointments.where((a) => a['status'] == 'SCHEDULED').length}', Colors.orange),
            const SizedBox(width: 8),
            _kpiChip('Draft Sent', '${_appointments.where((a) => a['billing_status'] == 'DRAFT_SENT').length}', Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _kpiChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(dateStr),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _fetchAppointments();
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search patient name, phone, doctor...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _fetchAppointments(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _fetchAppointments,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('ALL', 'All'),
                const SizedBox(width: 6),
                _filterChip('SCHEDULED', 'Scheduled'),
                const SizedBox(width: 6),
                _filterChip('VISITED', 'Visited'),
                const SizedBox(width: 6),
                _filterChip('CANCELLED', 'Cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final sel = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        color: sel ? Colors.white : Colors.black87,
      ),
      selectedColor: Theme.of(context).primaryColor,
      onSelected: (val) {
        if (val) {
          setState(() => _statusFilter = key);
          _fetchAppointments();
        }
      },
    );
  }

  Widget _buildAppointmentCard(dynamic a) {
    final status = a['status'] ?? 'SCHEDULED';
    final billingStatus = a['billing_status'] ?? 'PENDING';
    final isVisited = status == 'VISITED';
    final isDraftSent = billingStatus == 'DRAFT_SENT' || billingStatus == 'BILLED';

    Color statusColor = Colors.orange;
    if (status == 'VISITED') statusColor = Colors.green;
    if (status == 'CANCELLED') statusColor = Colors.red;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    (a['patient_name'] ?? 'P').toString().substring(0, 1).toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['patient_name'] ?? 'Patient',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Phone: ${a['patient_phone'] ?? '-'}  •  Age: ${a['patient_age'] ?? '-'}  •  ${a['patient_gender'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${a['appointment_time'] ?? ''}  (${a['appointment_date'] ?? ''})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Icon(Icons.person_pin, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Dr. ${a['doctor_name'] ?? 'General'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (a['source'] == 'ONLINE_WEB')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: const Text('Online Booking', style: TextStyle(fontSize: 10, color: Colors.purple)),
                  ),
              ],
            ),
            if (a['reason_for_visit'] != null && a['reason_for_visit'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: ${a['reason_for_visit']}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: Text(isVisited ? 'View / Edit Prescription' : 'Doctor Consultation'),
                  onPressed: () => _openConsultationDialog(a),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.point_of_sale, size: 16),
                  label: Text(isDraftSent ? 'Billing Sent ✓' : 'Send to Billing Draft'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDraftSent ? Colors.green.shade700 : null,
                  ),
                  onPressed: () => _sendToBilling(a),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clinic Operational Analytics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _analyticsCard('Total Appointments', '${_analytics['total_appointments'] ?? 0}', Icons.people, Colors.blue),
              _analyticsCard('Patients Visited', '${_analytics['visited_count'] ?? 0}', Icons.check_circle_outline, Colors.green),
              _analyticsCard('Attendance Rate', '${_analytics['attendance_rate_percent'] ?? 0}%', Icons.percent, Colors.teal),
              _analyticsCard('Scheduled Ahead', '${_analytics['scheduled_count'] ?? 0}', Icons.schedule, Colors.orange),
              _analyticsCard('Cancelled / No Show', '${_analytics['cancelled_count'] ?? 0}', Icons.cancel_outlined, Colors.red),
              _analyticsCard('Drafts Billed', '${_analytics['draft_sent_count'] ?? 0}', Icons.receipt_long, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _analyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _DoctorPrescriptionDialog extends StatefulWidget {
  final dynamic appointment;
  final VoidCallback onSaved;
  final VoidCallback onSendBilling;

  const _DoctorPrescriptionDialog({
    required this.appointment,
    required this.onSaved,
    required this.onSendBilling,
  });

  @override
  State<_DoctorPrescriptionDialog> createState() => _DoctorPrescriptionDialogState();
}

class _DoctorPrescriptionDialogState extends State<_DoctorPrescriptionDialog> {
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _doctorCtrl = TextEditingController();
  List<Map<String, dynamic>> _prescribedMedicines = [];
  List<dynamic> _availableMedicines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.appointment['prescription_notes'] ?? '';
    _doctorCtrl.text = widget.appointment['doctor_name'] ?? 'Dr. Smith';

    final meds = widget.appointment['prescribed_medicines'];
    if (meds is List) {
      _prescribedMedicines = meds.map((m) => Map<String, dynamic>.from(m)).toList();
    }

    _loadAvailableMedicines();
  }

  Future<void> _loadAvailableMedicines() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicMedicines);
      if (res != null && res['success'] == true) {
        setState(() {
          _availableMedicines = res['data'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _savePrescription() async {
    setState(() => _saving = true);
    try {
      final res = await ApiClient.post(
        ApiEndpoints.clinicAppointmentPrescription(widget.appointment['id']),
        {
          'prescription_notes': _notesCtrl.text.trim(),
          'doctor_name': _doctorCtrl.text.trim(),
          'prescribed_medicines': _prescribedMedicines,
        },
      );

      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription saved successfully!')),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save prescription: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addMedicine() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _MedicineSelectorSheet(
          availableMedicines: _availableMedicines,
          onSelected: (med) {
            setState(() {
              _prescribedMedicines.add(med);
            });
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      title: Row(
        children: [
          const Icon(Icons.assignment_outlined, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Doctor Consultation: ${widget.appointment['patient_name']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _doctorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Attending Doctor Name',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Clinical Notes, Symptoms & Diagnosis',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Prescribed Medicines (In-Stock Lookup)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _addMedicine,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Medicine'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_prescribedMedicines.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text('No medicines prescribed yet.', style: TextStyle(color: Colors.grey.shade600)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _prescribedMedicines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, idx) {
                    final m = _prescribedMedicines[idx];
                    return Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['item_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Code: ${m['item_code'] ?? '-'}  •  Stock: ${m['current_stock'] ?? 0}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Dosage: ${m['dosage'] ?? '1-0-1'}', style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Qty: ${m['qty'] ?? 1}  @ \$${m['rate'] ?? 0}', style: const TextStyle(fontSize: 12)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              onPressed: () {
                                setState(() => _prescribedMedicines.removeAt(idx));
                              },
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
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _savePrescription,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Prescription'),
        ),
      ],
    );
  }
}

class _MedicineSelectorSheet extends StatefulWidget {
  final List<dynamic> availableMedicines;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _MedicineSelectorSheet({
    required this.availableMedicines,
    required this.onSelected,
  });

  @override
  State<_MedicineSelectorSheet> createState() => _MedicineSelectorSheetState();
}

class _MedicineSelectorSheetState extends State<_MedicineSelectorSheet> {
  String _filter = '';
  dynamic _selectedItem;
  final TextEditingController _dosageCtrl = TextEditingController(text: '1-0-1');
  final TextEditingController _frequencyCtrl = TextEditingController(text: 'After Meals');
  final TextEditingController _durationCtrl = TextEditingController(text: '5 Days');
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    final filtered = widget.availableMedicines.where((m) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      final name = (m['item_name'] ?? '').toString().toLowerCase();
      final code = (m['item_code'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    return Container(
      height: 600,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Medicine from Pharmacy Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search medicine name or code...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() => _filter = val),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                final isSelected = _selectedItem == item;
                final inStock = (item['current_stock'] ?? 0) > 0;

                return ListTile(
                  dense: true,
                  selected: isSelected,
                  title: Text(item['item_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Code: ${item['item_code']}  •  Rate: \$${item['retail_sale_price']}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: inStock ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Stock: ${item['current_stock']}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: inStock ? Colors.green.shade800 : Colors.red),
                    ),
                  ),
                  onTap: () => setState(() => _selectedItem = item),
                );
              },
            ),
          ),
          if (_selectedItem != null) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dosageCtrl,
                    decoration: const InputDecoration(labelText: 'Dosage (e.g. 1-0-1)', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _frequencyCtrl,
                    decoration: const InputDecoration(labelText: 'Frequency', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    decoration: const InputDecoration(labelText: 'Duration', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSelected({
                    'item_id': _selectedItem['id'],
                    'item_code': _selectedItem['item_code'],
                    'item_name': _selectedItem['item_name'],
                    'brand': _selectedItem['brand'],
                    'unit': _selectedItem['unit'],
                    'rate': _selectedItem['retail_sale_price'] ?? _selectedItem['purchase_rate'] ?? 0,
                    'tax_percent': _selectedItem['tax_percent'] ?? 0,
                    'current_stock': _selectedItem['current_stock'],
                    'dosage': _dosageCtrl.text.trim(),
                    'frequency': _frequencyCtrl.text.trim(),
                    'duration': _durationCtrl.text.trim(),
                    'qty': double.tryParse(_qtyCtrl.text.trim()) ?? 1,
                  });
                },
                child: const Text('Add to Prescription'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NewAppointmentDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const _NewAppointmentDialog({required this.onCreated});

  @override
  State<_NewAppointmentDialog> createState() => _NewAppointmentDialogState();
}

class _NewAppointmentDialogState extends State<_NewAppointmentDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController(text: 'General Doctor');
  final _deptCtrl = TextEditingController(text: 'General');
  final _reasonCtrl = TextEditingController();

  DateTime _appDate = DateTime.now();
  TimeOfDay _appTime = TimeOfDay.now();
  String _gender = 'MALE';
  bool _saving = false;

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient name and phone number are required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final timeStr = '${_appTime.hour.toString().padLeft(2, '0')}:${_appTime.minute.toString().padLeft(2, '0')}';
      final res = await ApiClient.post(
        ApiEndpoints.clinicAppointments,
        {
          'patient_name': _nameCtrl.text.trim(),
          'patient_phone': _phoneCtrl.text.trim(),
          'patient_email': _emailCtrl.text.trim(),
          'patient_age': int.tryParse(_ageCtrl.text.trim()),
          'patient_gender': _gender,
          'appointment_date': DateFormat('yyyy-MM-dd').format(_appDate),
          'appointment_time': timeStr,
          'doctor_name': _doctorCtrl.text.trim(),
          'department': _deptCtrl.text.trim(),
          'reason_for_visit': _reasonCtrl.text.trim(),
        },
      );

      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully!')),
        );
        widget.onCreated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Failed to book appointment')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking appointment: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Book Patient Appointment'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Patient Full Name *', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number *', isDense: true),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Gender', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'MALE', child: Text('Male')),
                        DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (val) => setState(() => _gender = val ?? 'MALE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(DateFormat('dd-MMM-yyyy').format(_appDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _appDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _appDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 14),
                      label: Text(_appTime.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _appTime,
                        );
                        if (picked != null) setState(() => _appTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _doctorCtrl,
                decoration: const InputDecoration(labelText: 'Doctor Name', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for Visit', isDense: true),
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
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirm Booking'),
        ),
      ],
    );
  }
}

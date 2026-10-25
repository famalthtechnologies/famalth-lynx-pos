import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';
import '../inventory/salescreen.dart';
import 'clinic_prescription_pdf.dart';
import 'clinic_accept_pay_dialog.dart';
import 'clinic_doctor_management_dialog.dart';
import 'clinic_opd_report_pdf.dart';
import '../modify/sales_reprint_modify_screen.dart';
import '../../core/auth/token_storage.dart';
import '../reports/cash_ledger_screen.dart';

class ClinicDashboardScreen extends StatefulWidget {
  final int initialIndex;
  const ClinicDashboardScreen({super.key, this.initialIndex = 0});

  @override
  State<ClinicDashboardScreen> createState() => _ClinicDashboardScreenState();
}

class _ClinicDashboardScreenState extends State<ClinicDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = false;
  List<dynamic> _appointments = [];
  Map<String, dynamic> _analytics = {};

  String _userRole = '';
  String _loggedInDoctorName = '';
  int? _loggedInDoctorId;

  // Multi-status filters for Reception OPD Desk
  String _statusFilter = 'ALL';
  String _selectedDoctorFilter = 'ALL';
  String _attendanceFilter = 'ALL'; // ALL, UNATTENDED, ATTENDED
  String _feeStatusFilter = 'ALL'; // ALL, PAID, UNPAID
  String _billingStatusFilter = 'ALL'; // ALL, UNBILLED, BILLED

  // Doctor Consultation Desk filter
  String _doctorAttendanceFilter = 'ALL'; // ALL, UNATTENDED, ATTENDED

  // Pharmacy Dispensing Desk filter
  String _pharmacyBillingFilter = 'ALL'; // ALL, UNBILLED, BILLED

  List<dynamic> _clinicDoctors = [];
  final TextEditingController _searchCtrl = TextEditingController();
  // Therapy & Service Subscriptions state
  List<dynamic> _subscriptions = [];
  bool _isLoadingSubscriptions = false;
  String _subscriptionFilter = 'ALL';
  final TextEditingController _subSearchCtrl = TextEditingController();
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _datePresetLabel = 'Today';
  DateTime get _selectedDate => _fromDate;
  int _upcomingScheduledCount = 0;
  String? _nextUpcomingDate;

  // Date range for Store-Analysis style Clinic Analytics
  DateTime _analyticsFromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _analyticsToDate = DateTime.now();
  String _analyticsRangeLabel = 'Last 30 Days';

  // Clinic Operating Status (Today Open / Closed)
  bool _isClinicClosedToday = false;
  String _clinicClosedReason = '';
  bool _isLoadingOperatingStatus = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this, initialIndex: widget.initialIndex.clamp(0, 4));
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging && mounted) setState(() {});
    });
    _checkUserRole();
    _fetchClinicDoctors();
    _fetchAppointments();
    _fetchAnalytics();
    _fetchSubscriptions();
    _fetchOperatingStatus();
  }

  Future<void> _fetchOperatingStatus() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicOperatingStatus);
      if (res != null && res['success'] == true && res['data'] != null && mounted) {
        setState(() {
          _isClinicClosedToday = res['data']['clinic_closed_today'] == true;
          _clinicClosedReason = res['data']['clinic_closed_reason'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching clinic operating status: $e');
    }
  }

  Future<void> _openToggleClinicClosedDialog() async {
    final willClose = !_isClinicClosedToday;
    final reasonCtrl = TextEditingController(text: willClose ? 'Clinic closed for administrative reasons' : '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              willClose ? Icons.do_not_disturb_on_rounded : Icons.check_circle_rounded,
              color: willClose ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
            const SizedBox(width: 8),
            Text(willClose ? 'Mark Clinic Closed Today?' : 'Mark Clinic Open Today?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              willClose
                  ? 'If you mark the clinic closed today, online public appointment bookings for today will be strictly BLOCKED.'
                  : 'If you mark the clinic open, online public appointment bookings will be accepted for today.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            if (willClose) ...[
              const SizedBox(height: 16),
              const Text('Reason (Shown to patients attempting to book online):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Doctor on leave / Holiday / Maintenance',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: willClose ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willClose ? 'Yes, Mark Closed' : 'Yes, Mark Open'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.post(ApiEndpoints.clinicToggleClosedToday, {
          'is_closed': willClose,
          'reason': reasonCtrl.text.trim(),
        });
        if (res != null && res['success'] == true && mounted) {
          setState(() {
            _isClinicClosedToday = willClose;
            _clinicClosedReason = reasonCtrl.text.trim();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? (willClose ? 'Clinic marked closed today.' : 'Clinic marked open today.')),
              backgroundColor: willClose ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update operating status: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _checkUserRole() async {
    try {
      final user = await TokenStorage.getUser();
      if (user != null && mounted) {
        final role = (user['role'] ?? '').toString().toUpperCase();
        final name = (user['name'] ?? user['full_name'] ?? user['username'] ?? '').toString();
        final id = user['id'] != null ? int.tryParse('${user['id']}') : null;
        setState(() {
          _userRole = role;
          _loggedInDoctorName = name;
          _loggedInDoctorId = id;
        });

        // Auto-navigate to respective department panel based on role!
        if (role == 'DOCTOR') {
          _tabCtrl.animateTo(1); // Doctor Desk
          if (name.isNotEmpty) {
            setState(() {
              _selectedDoctorFilter = name;
            });
            _fetchAppointments();
          }
        } else if (role == 'PHARMACIST') {
          _tabCtrl.animateTo(2); // Pharmacy Desk
        } else if (role == 'RECEPTIONIST') {
          _tabCtrl.animateTo(0); // Reception Desk
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchClinicDoctors() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicDoctors);
      if (res != null && res['success'] == true && mounted) {
        final docs = res['data'] is List ? (res['data'] as List) : [];
        setState(() {
          _clinicDoctors = docs;
          // If only 1 doctor in the clinic, auto-open & select that doctor directly!
          if (docs.length == 1) {
            _selectedDoctorFilter = (docs.first['full_name'] ?? 'Doctor').toString();
          }
        });
      }
    } catch (_) {}
  }

  void _openDoctorManagementDialog() {
    showDialog(
      context: context,
      builder: (_) => ClinicDoctorManagementDialog(
        onDoctorsChanged: () {
          _fetchClinicDoctors();
          _fetchAppointments();
          _fetchAnalytics();
        },
      ),
    );
  }

  void _openAcceptAndPayDialog(dynamic appointment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicAcceptPayDialog(
        appointment: Map<String, dynamic>.from(appointment),
        doctors: _clinicDoctors,
        onAccepted: () {
          _fetchAppointments();
          _fetchAnalytics();
        },
      ),
    );
  }

  Widget _buildPaymentBadge(dynamic a) {
    final payStatus = (a['payment_status'] ?? 'UNPAID').toString().toUpperCase();
    final payMode = (a['payment_mode'] ?? '').toString().toUpperCase();
    final fee = double.tryParse('${a['consultation_fee'] ?? 0}') ?? 0.0;
    final isPack = a['is_package_session'] == true || payStatus == 'PACKAGE_INCLUDED' || payMode == 'PACKAGE_SUBSCRIPTION';

    if (isPack) {
      final sess = a['session_number'] ?? 1;
      final total = a['total_package_sessions'] ?? 6;
      final hasExtraFee = fee > 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF5FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD8B4FE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.spa_rounded, size: 12, color: Color(0xFF7C3AED)),
            const SizedBox(width: 4),
            Text(
              hasExtraFee
                  ? 'Package (#$sess/$total) • Fee: ${CurrencyService.symbol}${fee.toStringAsFixed(2)} ($payMode)'
                  : 'Package Covered (#$sess/$total) • ${CurrencyService.symbol}0.00',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8)),
            ),
          ],
        ),
      );
    }

    final status = (a['status'] ?? 'SCHEDULED').toString().toUpperCase();

    if (status == 'CANCELLED') {
      final refundAmt = double.tryParse('${a['refund_amount'] ?? 0}') ?? 0.0;
      final isRefunded = payStatus == 'REFUNDED' || refundAmt > 0;
      if (isRefunded) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF99F6E4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.replay_rounded, size: 12, color: Color(0xFF0D9488)),
              const SizedBox(width: 4),
              Text(
                'Refunded ${CurrencyService.format(refundAmt > 0 ? refundAmt : fee)} (${a['refund_mode'] ?? payMode})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Text('Cancelled (No Due)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
      );
    }

    if (payStatus == 'PAID') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
            const SizedBox(width: 4),
            Text('Paid ${CurrencyService.symbol}${fee.toStringAsFixed(2)} ($payMode)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
          ],
        ),
      );
    }

    if (payStatus == 'PAY_LATER' && !isPack) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, size: 12, color: Color(0xFFD97706)),
            const SizedBox(width: 4),
            Text('Credit Due: ${CurrencyService.symbol}${fee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Fee: ${CurrencyService.symbol}$fee', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
    );
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{
        'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
      };
      if (_statusFilter != 'ALL') {
        queryParams['status'] = _statusFilter;
      }
      if (_selectedDoctorFilter != 'ALL') {
        queryParams['doctor_name'] = _selectedDoctorFilter;
      }
      if (_attendanceFilter != 'ALL') {
        queryParams['attendance'] = _attendanceFilter;
      }
      if (_feeStatusFilter != 'ALL') {
        queryParams['fee_status'] = _feeStatusFilter;
      }
      if (_billingStatusFilter != 'ALL') {
        queryParams['billing_status'] = _billingStatusFilter;
      }
      if (_searchCtrl.text.trim().isNotEmpty) {
        queryParams['search'] = _searchCtrl.text.trim();
      }

      final res = await ApiClient.get(
        ApiEndpoints.clinicAppointments,
        queryParams: queryParams,
      );

      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _appointments = res['data'] ?? [];
          _upcomingScheduledCount = int.tryParse('${res['upcoming_scheduled_count']}') ?? 0;
          _nextUpcomingDate = res['next_upcoming_date'] != null ? '${res['next_upcoming_date']}' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load appointments: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAnalytics() async {
    try {
      final queryParams = <String, dynamic>{
        'from_date': DateFormat('yyyy-MM-dd').format(_analyticsFromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_analyticsToDate),
      };
      final res = await ApiClient.get(
        ApiEndpoints.clinicAnalytics,
        queryParams: queryParams,
      );
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _analytics = Map<String, dynamic>.from(res['data'] ?? {});
        });
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(
    dynamic appointmentId,
    String newStatus, {
    String? cancellationReason,
    bool refundFee = true,
    double? refundAmount,
    String? refundMode,
  }) async {
    try {
      final payload = <String, dynamic>{'status': newStatus};
      if (cancellationReason != null && cancellationReason.isNotEmpty) {
        payload['cancellation_reason'] = cancellationReason;
      }
      if (newStatus == 'CANCELLED') {
        payload['refund_fee'] = refundFee;
        if (refundAmount != null) payload['refund_amount'] = refundAmount;
        if (refundMode != null) payload['refund_mode'] = refundMode;
      }
      final res = await ApiClient.patch(
        ApiEndpoints.clinicAppointmentStatus(appointmentId),
        payload,
      );
      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Appointment updated successfully'),
            backgroundColor: newStatus == 'CANCELLED' ? const Color(0xFFDC2626) : const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchAppointments();
        _fetchAnalytics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openCancelAppointmentDialog(Map<String, dynamic> a) async {
    final status = (a['status'] ?? 'SCHEDULED').toString().toUpperCase();
    if (status == 'CANCELLED') return;

    final fee = double.tryParse('${a['consultation_fee'] ?? 0}') ?? 0.0;
    final paidAmt = double.tryParse('${a['paid_amount'] ?? 0}') ?? 0.0;
    final payStatus = (a['payment_status'] ?? 'UNPAID').toString().toUpperCase();
    final isPaid = payStatus == 'PAID' || paidAmt > 0;
    final effectiveCollected = paidAmt > 0 ? paidAmt : (isPaid ? fee : 0.0);
    final isPayLater = payStatus == 'PAY_LATER';

    final patientName = a['patient_name'] ?? 'Patient';
    final token = a['token_number'] ?? a['id'];

    String selectedPreset = 'Patient requested cancellation';
    final customReasonCtrl = TextEditingController();
    bool refundFee = isPaid && effectiveCollected > 0;
    String refundMode = (a['payment_mode'] ?? 'CASH').toString().toUpperCase();
    if (refundMode == 'PACKAGE' || refundMode == 'PACKAGE_SUBSCRIPTION') refundMode = 'CASH';

    final presetReasons = [
      'Patient requested cancellation',
      'Patient did not show up (No-Show)',
      'Doctor unavailable / Emergency',
      'Rescheduled to another date',
      'Duplicate booking error',
      'Other reason',
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isOther = selectedPreset == 'Other reason';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cancel Appointment Visit',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Token #$token • $patientName',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fee Status & Refund/Credit info banner
                      if (isPaid && effectiveCollected > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Fee Paid: ${CurrencyService.format(effectiveCollected)} (${a['payment_mode'] ?? 'CASH'})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF065F46)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(
                                  'Refund ${CurrencyService.format(effectiveCollected)} to patient',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                                subtitle: const Text(
                                  'Debits universal cash ledger & voids invoice from revenue',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                                ),
                                value: refundFee,
                                onChanged: (val) => setDlgState(() => refundFee = val ?? true),
                              ),
                              if (refundFee) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('Refund Via: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    DropdownButton<String>(
                                      value: refundMode,
                                      isDense: true,
                                      underline: const SizedBox(),
                                      items: const [
                                        DropdownMenuItem(value: 'CASH', child: Text('Cash', style: TextStyle(fontSize: 12))),
                                        DropdownMenuItem(value: 'UPI', child: Text('UPI / QR', style: TextStyle(fontSize: 12))),
                                        DropdownMenuItem(value: 'CARD', child: Text('Card', style: TextStyle(fontSize: 12))),
                                        DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer', style: TextStyle(fontSize: 12))),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setDlgState(() => refundMode = v);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (isPayLater && fee > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.money_off_csred_rounded, size: 18, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Credit Fee: ${CurrencyService.format(fee)} (Pay Later)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'This unpaid fee will be voided and will NOT be added to Customer Credit / Dues.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Cancellation Reason Label
                      const Text(
                        'Reason for Cancellation *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),

                      // Presets
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: presetReasons.map((p) {
                          final isSel = selectedPreset == p;
                          return ChoiceChip(
                            label: Text(p, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                            selected: isSel,
                            selectedColor: const Color(0xFFDC2626).withValues(alpha: 0.15),
                            side: BorderSide(color: isSel ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1)),
                            onSelected: (val) {
                              if (val) setDlgState(() => selectedPreset = p);
                            },
                          );
                        }).toList(),
                      ),

                      if (isOther || selectedPreset.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: customReasonCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: isOther ? 'Enter Reason Description *' : 'Additional Notes (Optional)',
                            hintText: 'e.g. Patient called to cancel due to travel',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Keep Appointment', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Confirm Cancellation'),
                  onPressed: () {
                    final fullReason = isOther
                        ? customReasonCtrl.text.trim()
                        : (customReasonCtrl.text.trim().isNotEmpty
                            ? '$selectedPreset: ${customReasonCtrl.text.trim()}'
                            : selectedPreset);

                    if (fullReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select or enter a cancellation reason.'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    _updateStatus(
                      a['id'],
                      'CANCELLED',
                      cancellationReason: fullReason,
                      refundFee: refundFee,
                      refundAmount: effectiveCollected,
                      refundMode: refundMode,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendToBilling(dynamic appointment) async {
    try {
      final pName = (appointment['patient_name'] ?? '').toString().trim();
      final pPhone = (appointment['patient_phone'] ?? '').toString().trim();

      // Extract preloaded medicine items directly into cart format
      final List<Map<String, dynamic>> preloaded = [];
      final rawMeds = appointment['prescribed_medicines'];
      if (rawMeds is List) {
        for (final m in rawMeds) {
          if (m is Map) {
            preloaded.add({
              'item_id': m['item_id'] ?? m['id'],
              'item_code': m['item_code'] ?? '',
              'item_name': m['item_name'] ?? m['medicine_name'] ?? '',
              'qty': double.tryParse('${m['qty'] ?? 1}') ?? 1.0,
              'rate': double.tryParse('${m['rate'] ?? m['price'] ?? 0}') ?? 0.0,
            });
          }
        }
      }

      // Mark appointment billing status on backend
      await ApiClient.post(
        ApiEndpoints.clinicAppointmentSendToBilling(appointment['id']),
        {},
      );

      if (mounted) {
        _fetchAppointments();
        _fetchAnalytics();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            content: Text(
              preloaded.isNotEmpty
                  ? '${preloaded.length} prescribed items added to cart for $pName!'
                  : 'Customer $pName loaded into POS Cart!',
            ),
          ),
        );

        // Direct navigate to SaleScreen with prefilled customer, doctor reference and appointment id
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SaleScreen(
              preloadedCustomerName: pName,
              preloadedCustomerPhone: pPhone,
              preloadedDoctorName: (appointment['doctor_name'] ?? '').toString(),
              preloadedAppointmentId: int.tryParse('${appointment['id']}'),
              preloadedItems: preloaded.isNotEmpty ? preloaded : null,
            ),
          ),
        ).then((_) {
          _fetchAppointments();
          _fetchAnalytics();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load into POS cart: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openReprintScreen(dynamic appointment) {
    final saleId = int.tryParse('${appointment['billing_sale_id']}');
    final saleNo = (appointment['billing_sale_no'] ?? '').toString().trim();
    final phone = (appointment['patient_phone'] ?? '').toString().trim();
    DateTime? apptDate;
    try {
      apptDate = DateTime.parse(appointment['appointment_date'].toString());
    } catch (_) {}

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesReprintModifyScreen(
          initialSaleId: saleId != null && saleId > 0 ? saleId : null,
          initialSaleNo: saleNo.isNotEmpty ? saleNo : null,
          initialSearch: saleNo.isNotEmpty ? saleNo : (phone.isNotEmpty ? phone : null),
          initialDate: apptDate,
        ),
      ),
    ).then((_) {
      _fetchAppointments();
      _fetchAnalytics();
    });
  }

  String _formatDoctorTitle(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Doctor';
    final clean = trimmed.replaceAll(RegExp(r'^(dr\.?\s*)+', caseSensitive: false), '').trim();
    return 'Dr. $clean';
  }

  bool _canDoctorEditAppointment(dynamic a) {
    final role = _userRole.trim().toUpperCase();
    if (role == 'ADMIN' ||
        role == 'SUPERADMIN' ||
        role == 'OWNER' ||
        role == 'CLINIC_ADMIN' ||
        role == 'MANAGER' ||
        role == 'DOCTOR_ADMIN') {
      return true;
    }

    String cleanDoc(String s) => s.toLowerCase().replaceAll(RegExp(r'^(dr\.?\s*)+', caseSensitive: false), '').trim();
    final apptDocName = cleanDoc((a['attended_by_doctor_name'] ?? a['doctor_name'] ?? '').toString());
    final myDocName = cleanDoc(_loggedInDoctorName);
    final selectedDesk = cleanDoc(_selectedDoctorFilter);

    if (myDocName.isNotEmpty && (apptDocName.contains(myDocName) || myDocName.contains(apptDocName))) {
      return true;
    }
    if (selectedDesk.isNotEmpty && selectedDesk != 'all' && (apptDocName.contains(selectedDesk) || selectedDesk.contains(apptDocName))) {
      return true;
    }

    final status = (a['status'] ?? '').toString().toUpperCase();
    final isVisited = status == 'VISITED' || status == 'COMPLETED';
    final hasRx = a['attended_by_doctor_name'] != null || 
                  (a['prescription_notes'] != null && a['prescription_notes'].toString().isNotEmpty) ||
                  (a['prescribed_medicines'] is List && (a['prescribed_medicines'] as List).isNotEmpty);
    if (!isVisited && !hasRx && (role == 'DOCTOR' || role.contains('DOCTOR') || selectedDesk.isNotEmpty)) {
      return true;
    }

    return false;
  }

  void _openConsultationDialog(dynamic appointment) {
    String effectiveDoctorName = _loggedInDoctorName;
    int? effectiveDoctorId = _loggedInDoctorId;

    if (_selectedDoctorFilter != 'ALL' && _selectedDoctorFilter.isNotEmpty) {
      effectiveDoctorName = _selectedDoctorFilter;
      final matched = _clinicDoctors.firstWhere(
        (d) {
          final fn = (d['full_name'] ?? '').toString().trim().toLowerCase();
          final sel = _selectedDoctorFilter.trim().toLowerCase();
          final cleanFn = fn.replaceAll(RegExp(r'^(dr\.?\s*)+', caseSensitive: false), '').trim();
          final cleanSel = sel.replaceAll(RegExp(r'^(dr\.?\s*)+', caseSensitive: false), '').trim();
          return cleanFn == cleanSel || fn == sel;
        },
        orElse: () => {},
      );
      if (matched.isNotEmpty && matched['id'] != null) {
        effectiveDoctorId = int.tryParse('${matched['id']}') ?? effectiveDoctorId;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DoctorPrescriptionDialog(
        appointment: appointment,
        userRole: _userRole,
        loggedInDoctorName: effectiveDoctorName,
        loggedInDoctorId: effectiveDoctorId,
        selectedDeskDoctor: _selectedDoctorFilter,
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
        doctors: _clinicDoctors,
        onCreated: () {
          _fetchAppointments();
          _fetchAnalytics();
        },
      ),
    );
  }

  void _printPrescription(dynamic a) {
    final property = Provider.of<PropertyInfoController>(context, listen: false).propertyInfo;
    ClinicPrescriptionPdf.printOrDownloadPrescription(
      context: context,
      appointment: Map<String, dynamic>.from(a),
      property: property,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0284C7), size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinic & Doctor Consultation',
                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'OPD Patient Queue, Medical Records & In-Stock Rx Dispensing',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Clinic Operating Status Toggle (Open / Closed Today)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: _isClinicClosedToday ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
              foregroundColor: _isClinicClosedToday ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              side: BorderSide(
                color: _isClinicClosedToday ? const Color(0xFFF87171) : const Color(0xFF86EFAC),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(
              _isClinicClosedToday ? Icons.do_not_disturb_on_rounded : Icons.check_circle_rounded,
              size: 16,
              color: _isClinicClosedToday ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
            label: Text(
              _isClinicClosedToday ? 'Clinic Closed Today' : 'Clinic Open Today',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: _openToggleClinicClosedDialog,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF0284C7)),
            label: const Text('Doctors & Profiles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _openDoctorManagementDialog,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh Appointments',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
            onPressed: () {
              _fetchAppointments();
              _fetchAnalytics();
            },
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _openNewAppointmentDialog,
          ),
          const SizedBox(width: 14),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              labelColor: const Color(0xFF0284C7),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0284C7),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_ind_rounded, size: 16),
                      const SizedBox(width: 8),
                      const Text('RECEPTION DESK (OPD)'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_appointments.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _userRole == 'DOCTOR' && _loggedInDoctorName.isNotEmpty
                            ? 'DR. ${_loggedInDoctorName.toUpperCase()} CONSULTATION'
                            : 'DOCTOR CONSULTATION',
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.medication_rounded, size: 16),
                      const SizedBox(width: 8),
                      const Text('PHARMACY & DISPENSING'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_appointments.where((a) => (a['prescribed_medicines'] is List && (a['prescribed_medicines'] as List).isNotEmpty)).length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.card_membership_rounded, size: 16),
                      const SizedBox(width: 8),
                      const Text('THERAPY & PACKAGES'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_subscriptions.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    children: [
                      Icon(Icons.analytics_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('STORE & CLINIC ANALYTICS'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildAppointmentsTab(),
          _buildDoctorDeskTab(),
          _buildPharmacyDeskTab(),
          _buildSubscriptionsTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: APPOINTMENTS & OPD QUEUE
  // ==========================================
  Widget _buildAppointmentsTab() {
    return Column(
      children: [
        _buildStatsBar(),
        _buildFilterBar(),
        _buildUpcomingAppointmentsBanner(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
              : _appointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Icon(Icons.event_available_rounded, size: 54, color: Colors.blueGrey.shade300),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No appointments found for this date & filter.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Book a new patient appointment or choose a different date filter.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _openNewAppointmentDialog,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Book New Appointment'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _appointments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) => _buildAppointmentCard(_appointments[idx]),
                    ),
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointmentsBanner() {
    if (_upcomingScheduledCount <= 0) return const SizedBox.shrink();
    String formattedNextDate = _nextUpcomingDate ?? 'Tomorrow';
    try {
      if (_nextUpcomingDate != null) {
        formattedNextDate = DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(_nextUpcomingDate!));
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: Color(0xFF1D4ED8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                children: [
                  TextSpan(
                    text: '$_upcomingScheduledCount Upcoming Online Booking${_upcomingScheduledCount > 1 ? 's' : ''} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '(Next appointment on $formattedNextDate)'),
                ],
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 14),
            label: const Text('View Tomorrow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              final now = DateTime.now();
              final tom = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
              setState(() {
                _fromDate = tom;
                _toDate = tom;
                _datePresetLabel = 'Tomorrow';
              });
              _fetchAppointments();
            },
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1D4ED8),
              side: const BorderSide(color: Color(0xFF93C5FD)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.date_range_rounded, size: 14),
            label: const Text('Next 7 Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              setState(() {
                _fromDate = today;
                _toDate = today.add(const Duration(days: 7));
                _datePresetLabel = 'Next 7 Days';
              });
              _fetchAppointments();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final total = _appointments.length;
    final visited = _appointments.where((a) => a['status'] == 'VISITED').length;
    final scheduled = _appointments.where((a) => a['status'] == 'SCHEDULED' || a['status'] == 'CONFIRMED').length;
    final billed = _appointments.where((a) => a['billing_status'] == 'DRAFT_SENT' || a['billing_status'] == 'BILLED').length;
    final cancelled = _appointments.where((a) => a['status'] == 'CANCELLED' || a['status'] == 'NO_SHOW').length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _kpiChip('Total Queue', '$total', Icons.groups_rounded, const Color(0xFF0284C7)),
            const SizedBox(width: 10),
            _kpiChip('Consulted / Visited', '$visited', Icons.check_circle_rounded, const Color(0xFF059669)),
            const SizedBox(width: 10),
            _kpiChip('Waiting / Scheduled', '$scheduled', Icons.schedule_rounded, const Color(0xFFD97706)),
            const SizedBox(width: 10),
            _kpiChip('Pharmacy Billed', '$billed', Icons.receipt_long_rounded, const Color(0xFF7C3AED)),
            const SizedBox(width: 10),
            _kpiChip('Cancelled / No-Show', '$cancelled', Icons.cancel_rounded, const Color(0xFFDC2626)),
          ],
        ),
      ),
    );
  }

  Widget _kpiChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Intelligent Date Range Selector
              PopupMenuButton<String>(
                tooltip: 'Select Date Range Presets',
                onSelected: (preset) async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  if (preset == 'TODAY') {
                    setState(() {
                      _fromDate = today;
                      _toDate = today;
                      _datePresetLabel = 'Today';
                    });
                    _fetchAppointments();
                  } else if (preset == 'TOMORROW') {
                    final tom = today.add(const Duration(days: 1));
                    setState(() {
                      _fromDate = tom;
                      _toDate = tom;
                      _datePresetLabel = 'Tomorrow';
                    });
                    _fetchAppointments();
                  } else if (preset == 'NEXT_7_DAYS') {
                    setState(() {
                      _fromDate = today;
                      _toDate = today.add(const Duration(days: 7));
                      _datePresetLabel = 'Next 7 Days';
                    });
                    _fetchAppointments();
                  } else if (preset == 'ALL_UPCOMING') {
                    setState(() {
                      _fromDate = today;
                      _toDate = today.add(const Duration(days: 60));
                      _datePresetLabel = 'All Upcoming';
                    });
                    _fetchAppointments();
                  } else if (preset == 'YESTERDAY') {
                    final yest = today.subtract(const Duration(days: 1));
                    setState(() {
                      _fromDate = yest;
                      _toDate = yest;
                      _datePresetLabel = 'Yesterday';
                    });
                    _fetchAppointments();
                  } else if (preset == 'THIS_WEEK') {
                    setState(() {
                      _fromDate = today.subtract(Duration(days: today.weekday - 1));
                      _toDate = today;
                      _datePresetLabel = 'This Week';
                    });
                    _fetchAppointments();
                  } else if (preset == 'THIS_MONTH') {
                    setState(() {
                      _fromDate = DateTime(now.year, now.month, 1);
                      _toDate = today;
                      _datePresetLabel = 'This Month';
                    });
                    _fetchAppointments();
                  } else if (preset == 'ALL_DATES') {
                    setState(() {
                      _fromDate = DateTime(2020, 1, 1);
                      _toDate = DateTime(2035, 12, 31);
                      _datePresetLabel = 'All Dates';
                    });
                    _fetchAppointments();
                  } else if (preset == 'CUSTOM') {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
                      firstDate: DateTime(2022),
                      lastDate: DateTime(2035),
                      helpText: 'Select Custom OPD Date Range',
                    );
                    if (picked != null) {
                      setState(() {
                        _fromDate = picked.start;
                        _toDate = picked.end;
                        _datePresetLabel = 'Custom';
                      });
                      _fetchAppointments();
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'TODAY', child: Text('Today (Single Day - Default)')),
                  PopupMenuItem(value: 'TOMORROW', child: Text('Tomorrow (${DateFormat('EEE, dd MMM').format(DateTime.now().add(const Duration(days: 1)))})')),
                  const PopupMenuItem(value: 'NEXT_7_DAYS', child: Text('Next 7 Days (Upcoming)')),
                  const PopupMenuItem(value: 'ALL_UPCOMING', child: Text('All Upcoming Appointments')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'YESTERDAY', child: Text('Yesterday')),
                  const PopupMenuItem(value: 'THIS_WEEK', child: Text('This Week (Last 7 Days)')),
                  const PopupMenuItem(value: 'THIS_MONTH', child: Text('This Month')),
                  const PopupMenuItem(value: 'ALL_DATES', child: Text('All Dates (No Date Filter)')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'CUSTOM', child: Row(children: [Icon(Icons.date_range, size: 16), SizedBox(width: 8), Text('Custom Date Range...')])),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Text(
                        _fromDate.year == _toDate.year && _fromDate.month == _toDate.month && _fromDate.day == _toDate.day
                            ? '${_datePresetLabel != 'Custom' ? '$_datePresetLabel: ' : ''}${DateFormat('dd MMM yyyy').format(_fromDate)}'
                            : '${_datePresetLabel != 'Custom' ? '$_datePresetLabel: ' : ''}${DateFormat('dd MMM').format(_fromDate)} - ${DateFormat('dd MMM yyyy').format(_toDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Doctor Filter Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _clinicDoctors.any((d) => (d['full_name'] ?? '').toString() == _selectedDoctorFilter) || _selectedDoctorFilter == 'ALL'
                        ? _selectedDoctorFilter
                        : 'ALL',
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    items: [
                      const DropdownMenuItem(
                        value: 'ALL',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF0284C7)),
                            SizedBox(width: 6),
                            Text('All Doctors'),
                          ],
                        ),
                      ),
                      ..._clinicDoctors.map((doc) {
                        final dName = (doc['full_name'] ?? 'Doctor').toString();
                        final spec = (doc['speciality'] ?? '').toString();
                        return DropdownMenuItem(
                          value: dName,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFF0284C7)),
                              const SizedBox(width: 6),
                              Text(
                                spec.isNotEmpty ? 'Dr. $dName ($spec)' : 'Dr. $dName',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDoctorFilter = val);
                        _fetchAppointments();
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Search Input Box
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    hintText: 'Search patient name, phone, doctor, or token...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _fetchAppointments(),
                ),
              ),

              const SizedBox(width: 8),

              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7).withOpacity(0.12),
                  foregroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _fetchAppointments,
                child: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),

              // Print OPD Report Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print OPD Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _printOpdReport,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Multi-status Filter Chips Row for Reception Desk
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Attendance:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(width: 6),
                _attendanceChip('ALL', 'All Queue'),
                const SizedBox(width: 4),
                _attendanceChip('UNATTENDED', 'Waiting in Queue'),
                const SizedBox(width: 4),
                _attendanceChip('ATTENDED', 'Attended (Visited)'),

                const SizedBox(width: 14),
                const Text('Fee Status:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(width: 6),
                _feeChip('ALL', 'All Fees'),
                const SizedBox(width: 4),
                _feeChip('PAID', 'Fee Paid'),
                const SizedBox(width: 4),
                _feeChip('UNPAID', 'Fee Unpaid / Pay Later'),

                const SizedBox(width: 14),
                const Text('Dispensing:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(width: 6),
                _billingChip('ALL', 'All Dispensing'),
                const SizedBox(width: 4),
                _billingChip('UNBILLED', 'Unbilled (Pending)'),
                const SizedBox(width: 4),
                _billingChip('BILLED', 'Billed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceChip(String key, String label) {
    final sel = _attendanceFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
        color: sel ? Colors.white : const Color(0xFF334155),
      ),
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: sel ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
      onSelected: (val) {
        if (val) {
          setState(() => _attendanceFilter = key);
          _fetchAppointments();
        }
      },
    );
  }

  Widget _feeChip(String key, String label) {
    final sel = _feeStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
        color: sel ? Colors.white : const Color(0xFF334155),
      ),
      selectedColor: const Color(0xFF059669),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: sel ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
      onSelected: (val) {
        if (val) {
          setState(() => _feeStatusFilter = key);
          _fetchAppointments();
        }
      },
    );
  }

  Widget _billingChip(String key, String label) {
    final sel = _billingStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
        color: sel ? Colors.white : const Color(0xFF334155),
      ),
      selectedColor: const Color(0xFF7C3AED),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: sel ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
      onSelected: (val) {
        if (val) {
          setState(() => _billingStatusFilter = key);
          _fetchAppointments();
        }
      },
    );
  }


  Widget _buildAppointmentCard(dynamic a) {
    final status = (a['status'] ?? 'SCHEDULED').toString().toUpperCase();
    final billingStatus = (a['billing_status'] ?? 'PENDING').toString().toUpperCase();
    final saleId = int.tryParse('${a['billing_sale_id']}');
    final saleNo = (a['billing_sale_no'] ?? '').toString().trim();
    final isBilled = billingStatus == 'BILLED' || (saleId != null && saleId > 0) || saleNo.isNotEmpty;
    final isVisited = status == 'VISITED';
    final isDraftSent = billingStatus == 'DRAFT_SENT';
    final hasPrescription = (a['prescribed_medicines'] is List && (a['prescribed_medicines'] as List).isNotEmpty) ||
        (a['prescription_notes'] != null && a['prescription_notes'].toString().isNotEmpty);

    Color statusColor = const Color(0xFFD97706);
    if (status == 'VISITED') statusColor = const Color(0xFF059669);
    if (status == 'CANCELLED' || status == 'NO_SHOW') statusColor = const Color(0xFFDC2626);

    final rawMeds = a['prescribed_medicines'];
    final medCount = rawMeds is List ? rawMeds.length : 0;

    final isPackageVisit = a['is_package_session'] == true ||
        a['payment_mode'] == 'PACKAGE_SUBSCRIPTION' ||
        a['payment_status'] == 'PACKAGE_INCLUDED';
    final hasActiveSub = a['active_subscription'] != null &&
        (int.tryParse('${a['active_subscription']['remaining_sessions']}') ?? 0) > 0;
    final payStatus = (a['payment_status'] ?? 'UNPAID').toString().toUpperCase();
    final fee = double.tryParse('${a['consultation_fee'] ?? 0}') ?? 0.0;
    final isFeePaid = payStatus == 'PAID' || (payStatus == 'PACKAGE_INCLUDED' && fee == 0.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF0284C7).withOpacity(0.1),
                  child: Text(
                    (a['patient_name'] ?? 'P').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0284C7)),
                  ),
                ),
                const SizedBox(width: 14),

                // Patient Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            a['patient_name'] ?? 'Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: status == 'CANCELLED'
                                  ? const Color(0xFFFEF2F2)
                                  : (isVisited ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB)),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: status == 'CANCELLED'
                                    ? const Color(0xFFFCA5A5)
                                    : (isVisited ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A)),
                              ),
                            ),
                            child: Text(
                              status == 'CANCELLED'
                                  ? 'CANCELLED'
                                  : (isVisited ? 'ATTENDED / VISITED' : 'WAITING IN QUEUE'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: status == 'CANCELLED'
                                    ? const Color(0xFFB91C1C)
                                    : (isVisited ? const Color(0xFF047857) : const Color(0xFFB45309)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPaymentBadge(a),
                          if (a['is_repeat_patient'] == true || (a['total_prior_visits'] != null && (int.tryParse('${a['total_prior_visits']}') ?? 0) > 0)) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFD8B4FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.repeat_rounded, size: 12, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'REPEAT PATIENT (${a['total_prior_visits'] ?? 1} Prior)',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (isPackageVisit && a['active_subscription'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded, size: 13, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${a['active_subscription']['package_name']}: ${a['active_subscription']['services_consumed']}/${a['active_subscription']['total_sessions']} Consumed (${a['active_subscription']['remaining_sessions']} Left)',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'Phone: ${a['patient_phone'] ?? '-'}  •  Age: ${a['patient_age'] ?? '-'}  •  ${(a['patient_gender'] ?? '-').toString().toUpperCase()}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (a['customer_pending_credit'] != null && (double.tryParse('${a['customer_pending_credit']}') ?? 0) > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, size: 11, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Prior Credit: ${CurrencyService.format(double.parse('${a['customer_pending_credit']}'))}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF0284C7)),
                                const SizedBox(width: 4),
                                Text(
                                  'Assigned: Dr. ${a['doctor_name'] ?? 'General'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                                if (isVisited && a['attended_by_doctor_name'] != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '• Attended by: Dr. ${a['attended_by_doctor_name']}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_loggedInDoctorName.isNotEmpty && (a['doctor_name'] ?? '').toString().toLowerCase().contains(_loggedInDoctorName.toLowerCase())) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Text('⭐ My Patient', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Meta Details: Time, Doctor, Reason
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '${a['appointment_time'] ?? ''}  (${a['appointment_date'] ?? ''})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(width: 18),
                const Icon(Icons.medical_services_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Dr. ${a['doctor_name'] ?? 'General Physician'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const Spacer(),
                if (medCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$medCount Medicines Prescribed',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ),
              ],
            ),

            if (a['reason_for_visit'] != null && a['reason_for_visit'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason for Visit: ${a['reason_for_visit']}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status == 'CANCELLED') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cancellation Reason: ${a['cancellation_reason'] ?? 'Cancelled by Clinic'}' +
                            (a['refund_amount'] != null && (double.tryParse('${a['refund_amount']}') ?? 0) > 0
                                ? '  •  Refunded: ${CurrencyService.format(double.parse('${a['refund_amount']}'))} via ${a['refund_mode'] ?? 'CASH'}'
                                : ''),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status != 'CANCELLED') ...[
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                // 1. Therapy / Service Package session admission (Available ONLY when this appointment is booked as a package session)
                if (isPackageVisit && hasActiveSub && status != 'CANCELLED' && !isVisited) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.spa_rounded, size: 16),
                    label: Text(
                      'Admit Therapy Session (#${(int.tryParse('${a['active_subscription']['services_consumed']}') ?? 0) + 1})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _openConsumePackageDialog(a, a['active_subscription']),
                  ),
                  const SizedBox(width: 8),
                ],

                // 2. Reception Accept & Fee Collection (for newly scheduled appointments)
                if (status == 'SCHEDULED') ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.verified_user_rounded, size: 16),
                    label: const Text('Accept & Collect Fee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _openAcceptAndPayDialog(a),
                  ),
                  const SizedBox(width: 8),
                ],

                // 3. Fee Collection for standard consultations, repeat patients or pay-later visits where fee is pending
                if (status != 'SCHEDULED' && status != 'CANCELLED' && !isFeePaid) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: Text(
                      payStatus == 'PAY_LATER'
                          ? 'Settle Credit (${CurrencyService.symbol}${fee.toStringAsFixed(2)})'
                          : (fee > 0 ? 'Collect Fee (${CurrencyService.symbol}${fee.toStringAsFixed(2)})' : 'Collect Fee'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _openAcceptAndPayDialog(a),
                  ),
                  const SizedBox(width: 8),
                ],

                // Quick status change if scheduled
                if (!isVisited && status != 'CANCELLED')
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text('Cancel Visit', style: TextStyle(fontSize: 12)),
                    onPressed: () => _openCancelAppointmentDialog(a),
                  ),

                const Spacer(),

                // Generate / Print PDF Prescription
                if (hasPrescription) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print PDF Rx', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _printPrescription(a),
                  ),
                  const SizedBox(width: 8),
                ],

                // Doctor Consultation / View Rx
                Builder(
                  builder: (context) {
                    final isPrescribingDoctor = _canDoctorEditAppointment(a);

                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(isPrescribingDoctor ? Icons.edit_note_rounded : Icons.visibility_rounded, size: 18),
                      label: Text(
                        isVisited
                            ? (isPrescribingDoctor ? 'View / Edit Prescription' : 'View Prescription')
                            : (isPrescribingDoctor ? 'Doctor Consultation' : 'View Prescription'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () => _openConsultationDialog(a),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // If already bill made then show reprint bill on press get selected bill which made in reprint section
                if (isBilled) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4338CA), // Professional Indigo
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: Text(
                      saleNo.isNotEmpty ? 'Reprint Bill ($saleNo)' : 'Reprint Bill',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _openReprintScreen(a),
                  ),
                ] else ...[
                  // Send to Billing Draft
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDraftSent ? const Color(0xFF059669) : const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(isDraftSent ? Icons.check_circle_rounded : Icons.point_of_sale_rounded, size: 16),
                    label: Text(
                      isDraftSent ? 'Open in POS Cart ✓' : 'Add to POS Cart',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _sendToBilling(a),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  // ==========================================
  // TAB: DOCTOR CONSULTATION DESK
  // ==========================================
  Widget _buildDoctorDeskTab() {
    final isDoctorUser = _userRole == 'DOCTOR' && _loggedInDoctorName.isNotEmpty;
    final doctorQueue = _appointments.where((a) {
      final status = (a['status'] ?? '').toString().toUpperCase();
      // Cancelled visits are never sent or shown to doctor
      if (status == 'CANCELLED') return false;

      if (_selectedDoctorFilter != 'ALL') {
        final dName = (a['doctor_name'] ?? '').toString().toLowerCase();
        if (!dName.contains(_selectedDoctorFilter.toLowerCase())) return false;
      }
      if (_doctorAttendanceFilter == 'ATTENDED') {
        return status == 'VISITED' || status == 'COMPLETED';
      } else if (_doctorAttendanceFilter == 'UNATTENDED') {
        return status == 'SCHEDULED' || status == 'CONFIRMED';
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    child: const Icon(Icons.medical_services_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDoctorFilter != 'ALL'
                              ? '${_formatDoctorTitle(_selectedDoctorFilter)} Consultation Desk'
                              : 'All Doctors Consultation Desk',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Daily Token Order • ${doctorQueue.length} Patients in Doctor Queue for ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  // Doctor Filter Dropdown
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _clinicDoctors.any((d) => (d['full_name'] ?? '').toString() == _selectedDoctorFilter) || _selectedDoctorFilter == 'ALL'
                            ? _selectedDoctorFilter
                            : 'ALL',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0284C7)),
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('👨‍⚕️ All Doctors')),
                          ..._clinicDoctors.map((d) {
                            final docName = (d['full_name'] ?? 'Doctor').toString();
                            return DropdownMenuItem(
                              value: docName,
                              child: Text(_formatDoctorTitle(docName)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDoctorFilter = val);
                        },
                      ),
                    ),
                  ),

                  if (isDoctorUser || _loggedInDoctorName.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedDoctorFilter == _loggedInDoctorName,
                      avatar: const Icon(Icons.person_pin_rounded, size: 14),
                      label: const Text('My Patients Only', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selectedColor: const Color(0xFF059669),
                      backgroundColor: const Color(0xFFECFDF5),
                      labelStyle: TextStyle(
                        color: _selectedDoctorFilter == _loggedInDoctorName ? Colors.white : const Color(0xFF065F46),
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedDoctorFilter = val ? _loggedInDoctorName : 'ALL';
                        });
                      },
                    ),
                  ],

                  const SizedBox(width: 12),

                  Wrap(
                    spacing: 6,
                    children: [
                      _docFilterChip('ALL', 'All Patients (${doctorQueue.length})'),
                      _docFilterChip('UNATTENDED', 'Waiting in Queue'),
                      _docFilterChip('ATTENDED', 'Attended / Visited'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
              : doctorQueue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_rounded, size: 54, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 12),
                          const Text('No patients in doctor queue for this filter.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155))),
                          const SizedBox(height: 4),
                          const Text('Patients admitted by reception will appear here with sequential daily tokens.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: doctorQueue.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) => _buildDoctorPatientCard(doctorQueue[idx]),
                    ),
        ),
      ],
    );
  }

  Widget _docFilterChip(String key, String label) {
    final sel = _doctorAttendanceFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
        color: sel ? Colors.white : const Color(0xFF334155),
      ),
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: sel ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
      onSelected: (val) {
        if (val) setState(() => _doctorAttendanceFilter = key);
      },
    );
  }

  Widget _buildDoctorPatientCard(dynamic a) {
    final status = (a['status'] ?? 'SCHEDULED').toString().toUpperCase();
    final isVisited = status == 'VISITED';
    final tokenNo = a['token_number'] ?? a['id'] ?? '-';
    final hasPrescription = (a['prescribed_medicines'] is List && (a['prescribed_medicines'] as List).isNotEmpty) ||
        (a['prescription_notes'] != null && a['prescription_notes'].toString().isNotEmpty);
    final medCount = a['prescribed_medicines'] is List ? (a['prescribed_medicines'] as List).length : 0;
    final isPackageVisit = a['is_package_session'] == true ||
        a['payment_mode'] == 'PACKAGE_SUBSCRIPTION' ||
        a['payment_status'] == 'PACKAGE_INCLUDED';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
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
                  radius: 24,
                  backgroundColor: isVisited ? const Color(0xFFECFDF5) : const Color(0xFF0284C7).withValues(alpha: 0.1),
                  child: Text(
                    '#$tokenNo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isVisited ? const Color(0xFF059669) : const Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            a['patient_name'] ?? 'Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: status == 'CANCELLED'
                                  ? const Color(0xFFFEF2F2)
                                  : (isVisited ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB)),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: status == 'CANCELLED'
                                    ? const Color(0xFFFCA5A5)
                                    : (isVisited ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A)),
                              ),
                            ),
                            child: Text(
                              status == 'CANCELLED'
                                  ? 'CANCELLED'
                                  : (isVisited ? 'ATTENDED / VISITED' : 'WAITING IN QUEUE'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: status == 'CANCELLED'
                                    ? const Color(0xFFB91C1C)
                                    : (isVisited ? const Color(0xFF047857) : const Color(0xFFB45309)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPaymentBadge(a),
                          if (isPackageVisit && a['active_subscription'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded, size: 13, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${a['active_subscription']['package_name']}: ${a['active_subscription']['services_consumed']}/${a['active_subscription']['total_sessions']} Consumed (${a['active_subscription']['remaining_sessions']} Left)',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Phone: ${a['patient_phone'] ?? '-'}  •  Age: ${a['patient_age'] ?? '-'}  •  ${(a['patient_gender'] ?? '-').toString().toUpperCase()}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (a['reason_for_visit'] != null && a['reason_for_visit'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Chief Complaint: ${a['reason_for_visit']}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status == 'CANCELLED') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cancellation Reason: ${a['cancellation_reason'] ?? 'Cancelled by Clinic'}' +
                            (a['refund_amount'] != null && (double.tryParse('${a['refund_amount']}') ?? 0) > 0
                                ? '  •  Refunded: ${CurrencyService.format(double.parse('${a['refund_amount']}'))} via ${a['refund_mode'] ?? 'CASH'}'
                                : ''),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status != 'CANCELLED') ...[
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isVisited)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFECFDF5),
                        foregroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text('Mark Consulted / Attended', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _updateStatus(a['id'], 'VISITED'),
                    ),
                  const SizedBox(width: 8),
                  if (hasPrescription) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print PDF Rx', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _printPrescription(a),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Builder(
                    builder: (context) {
                      final isPrescribingDoctor = _canDoctorEditAppointment(a);

                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(isPrescribingDoctor ? Icons.edit_note_rounded : Icons.visibility_rounded, size: 18),
                        label: Text(
                          isVisited
                              ? (isPrescribingDoctor ? 'View / Edit Prescription ($medCount Meds)' : 'View Prescription ($medCount Meds)')
                              : 'Consult & Prescribe Rx',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () => _openConsultationDialog(a),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB: PHARMACY DISPENSING DESK
  // ==========================================
  Widget _buildPharmacyDeskTab() {
    final pharmacyQueue = _appointments.where((a) {
      if ((a['status'] ?? '').toString().toUpperCase() == 'CANCELLED') return false;
      final hasRx = (a['prescribed_medicines'] is List && (a['prescribed_medicines'] as List).isNotEmpty) ||
          (a['prescription_notes'] != null && a['prescription_notes'].toString().isNotEmpty);
      if (!hasRx) return false;

      final bStatus = (a['billing_status'] ?? 'PENDING').toString().toUpperCase();
      final saleId = int.tryParse('${a['billing_sale_id']}');
      final saleNo = (a['billing_sale_no'] ?? '').toString().trim();
      final isBilled = bStatus == 'BILLED' || (saleId != null && saleId > 0) || saleNo.isNotEmpty;

      if (_pharmacyBillingFilter == 'UNBILLED') return !isBilled;
      if (_pharmacyBillingFilter == 'BILLED') return isBilled;
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF059669).withValues(alpha: 0.1),
                child: const Icon(Icons.medication_rounded, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pharmacy & Medical Dispensing Desk',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${pharmacyQueue.length} Prescriptions • Real-time stock check, 1-tap POS cart dispense & reprint bill',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  _pharmacyFilterChip('ALL', 'All Prescriptions'),
                  _pharmacyFilterChip('UNBILLED', 'Pending Dispense (Unbilled)'),
                  _pharmacyFilterChip('BILLED', 'Dispensed & Billed'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
              : pharmacyQueue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication_liquid_rounded, size: 54, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 12),
                          const Text('No prescriptions found for this dispensing filter.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155))),
                          const SizedBox(height: 4),
                          const Text('Medicines prescribed by doctors will immediately show here for dispensing.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: pharmacyQueue.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) => _buildPharmacyCard(pharmacyQueue[idx]),
                    ),
        ),
      ],
    );
  }

  Widget _pharmacyFilterChip(String key, String label) {
    final sel = _pharmacyBillingFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
        color: sel ? Colors.white : const Color(0xFF334155),
      ),
      selectedColor: const Color(0xFF059669),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: sel ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
      onSelected: (val) {
        if (val) setState(() => _pharmacyBillingFilter = key);
      },
    );
  }

  Widget _buildPharmacyCard(dynamic a) {
    final billingStatus = (a['billing_status'] ?? 'PENDING').toString().toUpperCase();
    final saleId = int.tryParse('${a['billing_sale_id']}');
    final saleNo = (a['billing_sale_no'] ?? '').toString().trim();
    final isBilled = billingStatus == 'BILLED' || (saleId != null && saleId > 0) || saleNo.isNotEmpty;
    final isDraftSent = billingStatus == 'DRAFT_SENT';
    final tokenNo = a['token_number'] ?? a['id'] ?? '-';
    final rawMeds = a['prescribed_medicines'] as List? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF059669).withValues(alpha: 0.1),
                  child: Text(
                    '#$tokenNo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            a['patient_name'] ?? 'Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Text('•  Phone: ${a['patient_phone'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      Text('Prescribed by Dr. ${a['doctor_name'] ?? 'Consultant'}', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBilled ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isBilled ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    isBilled ? 'BILLED & DISPENSED' : 'PENDING DISPENSE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isBilled ? const Color(0xFF047857) : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Prescribed items list
            const Text('Prescribed Medicines:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            ...rawMeds.map((med) {
              final mName = med['medicine_name'] ?? med['item_name'] ?? 'Medicine';
              final qty = med['qty'] ?? 1;
              final dosage = med['dosage'] ?? '';
              final timing = med['timing'] ?? '';
              final duration = med['duration'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medication_rounded, size: 16, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$mName  x $qty' + (dosage.isNotEmpty ? '  ($dosage • $timing • $duration)' : ''),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('In Stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Print Rx', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _printPrescription(a),
                ),
                const SizedBox(width: 8),
                if (isBilled)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4338CA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: Text(
                      saleNo.isNotEmpty ? 'Reprint Bill ($saleNo)' : 'Reprint Bill',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _openReprintScreen(a),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(isDraftSent ? Icons.check_circle_rounded : Icons.point_of_sale_rounded, size: 16),
                    label: Text(
                      isDraftSent ? 'Open in POS Cart ✓' : 'Dispense & Bill at POS',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

  // ==========================================
  // TAB 2: STORE & CLINIC ANALYTICS (Store Analysis Style)
  // ==========================================
  Widget _buildAnalyticsTab() {
    final inr = CurrencyService.currencyFormat;
    final totalAppts = _analytics['total_appointments'] ?? 0;
    final visitedCount = _analytics['visited_count'] ?? 0;
    final attendanceRate = _analytics['attendance_rate_percent'] ?? 0;
    final draftSent = _analytics['draft_sent_count'] ?? 0;
    final billingRate = _analytics['billing_conversion_percent'] ?? 0;
    final uniquePatients = _analytics['unique_patients_count'] ?? 0;
    final totalFees = _analytics['total_consultation_fees'] ?? 0;

    final dailyTrends = (_analytics['daily_trends'] as List?) ?? [];
    final doctorWorkload = (_analytics['doctor_workload'] as List?) ?? [];
    final topMedicines = (_analytics['top_medicines'] as List?) ?? [];
    final demographics = _analytics['gender_demographics'] as Map? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Header: Date Range Selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_rounded, color: Color(0xFF0284C7), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinic Operational Intelligence & Performance Analytics',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Real-time metrics, appointment completion trends, pharmacy dispensing rates & doctor performance.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // Range Selector Pills
                _rangePill('Last 7 Days', 7),
                const SizedBox(width: 6),
                _rangePill('Last 30 Days', 30),
                const SizedBox(width: 6),
                _rangePill('Last 90 Days', 90),
                const SizedBox(width: 12),

                // Link to universal financial ledger
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF38BDF8)),
                  label: const Text('Universal Cash Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CashLedgerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 1. TOP METRIC KPI CARDS (Executive Grade with Gradient Badges)
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 900;
              final crossCount = isWide ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                childAspectRatio: isWide ? 2.3 : 2.0,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _metricCard(
                    title: 'Total Appointments',
                    value: '$totalAppts',
                    subtitle: '$uniquePatients unique patients registered',
                    icon: Icons.groups_rounded,
                    accentColor: const Color(0xFF0284C7),
                  ),
                  _metricCard(
                    title: 'Patients Consulted',
                    value: '$visitedCount',
                    subtitle: '$attendanceRate% attendance rate',
                    icon: Icons.verified_user_rounded,
                    accentColor: const Color(0xFF059669),
                  ),
                  _metricCard(
                    title: 'Pharmacy Billing Conversion',
                    value: '$draftSent Rx',
                    subtitle: '$billingRate% converted to sales',
                    icon: Icons.point_of_sale_rounded,
                    accentColor: const Color(0xFF7C3AED),
                  ),
                  _metricCard(
                    title: 'Consultation Fees',
                    value: inr.format(totalFees),
                    subtitle: 'Direct OPD consultation collection',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: const Color(0xFFD97706),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // 2. CHART SECTION: APPOINTMENT & VISITATION TIMELINE
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Consultation & Patient Volume Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Daily appointment bookings vs. actual visited consultations', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Live Analytics Timeline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (dailyTrends.isEmpty)
                  Container(
                    height: 240,
                    alignment: Alignment.center,
                    child: Text('No daily trend data available for the selected period.', style: TextStyle(color: Colors.grey.shade500)),
                  )
                else
                  SizedBox(
                    height: 260,
                    child: SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        majorGridLines: MajorGridLines(width: 0),
                        labelStyle: TextStyle(fontSize: 10),
                      ),
                      primaryYAxis: const NumericAxis(
                        majorGridLines: MajorGridLines(dashArray: [4, 4], color: Color(0xFFE2E8F0)),
                        axisLine: AxisLine(width: 0),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      legend: const Legend(isVisible: true, position: LegendPosition.top),
                      series: <CartesianSeries>[
                        ColumnSeries<dynamic, String>(
                          name: 'Booked Appointments',
                          dataSource: dailyTrends,
                          xValueMapper: (dynamic d, _) => d['date'].toString().substring(5),
                          yValueMapper: (dynamic d, _) => d['appointments'] ?? 0,
                          color: const Color(0xFF38BDF8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        ColumnSeries<dynamic, String>(
                          name: 'Visited / Consulted',
                          dataSource: dailyTrends,
                          xValueMapper: (dynamic d, _) => d['date'].toString().substring(5),
                          yValueMapper: (dynamic d, _) => d['visited'] ?? 0,
                          color: const Color(0xFF059669),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        LineSeries<dynamic, String>(
                          name: 'Pharmacy Drafts Billed',
                          dataSource: dailyTrends,
                          xValueMapper: (dynamic d, _) => d['date'].toString().substring(5),
                          yValueMapper: (dynamic d, _) => d['billed'] ?? 0,
                          color: const Color(0xFF7C3AED),
                          width: 3,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. TWO COLUMN BREAKDOWN: TOP PRESCRIBED MEDICINES & DOCTOR WORKLOAD
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Prescribed Medicines
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.medication_liquid_rounded, color: Color(0xFF7C3AED), size: 20),
                          SizedBox(width: 8),
                          Text('Top Prescribed Medications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Most frequently dispensed pharmaceutical items from inventory', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const Divider(height: 20),

                      if (topMedicines.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text('No medications prescribed yet in this period.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: topMedicines.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final m = topMedicines[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                              ),
                              title: Text(m['item_name'] ?? 'Medicine', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Code: ${m['item_code'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${m['times_prescribed']} times', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                  Text('${m['total_qty']} total units', style: const TextStyle(fontSize: 10, color: Color(0xFF059669))),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Doctor Performance & Workload
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_rounded, color: Color(0xFF0284C7), size: 20),
                          SizedBox(width: 8),
                          Text('Doctor Consultation Workload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Total patients booked and consulted by attending clinician', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const Divider(height: 20),

                      if (doctorWorkload.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text('No doctor workload recorded yet.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: doctorWorkload.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final doc = doctorWorkload[i];
                            final total = doc['count'] ?? 0;
                            final vis = doc['visited'] ?? 0;
                            final rate = total > 0 ? ((vis / total) * 100).toStringAsFixed(0) : '0';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF0284C7).withOpacity(0.1),
                                child: const Icon(Icons.person, size: 16, color: Color(0xFF0284C7)),
                              ),
                              title: Text(doc['doctor'] ?? 'Doctor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('$total Booked  •  $vis Consulted', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('$rate% Visited', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. CLINICIAN FINANCIAL REVENUE & PHARMACY RX REFERRALS TABLE
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 20),
                        SizedBox(width: 8),
                        Text('Clinician Financial Performance & Pharmacy Rx Referrals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 14),
                      label: const Text('Manage Doctor Profiles', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _openDoctorManagementDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Breakdown of consultation fees collected by mode, attended patients, and attributed pharmacy sales', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const Divider(height: 20),

                if (_clinicDoctors.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Text('No clinicians registered yet. Click "Manage Doctor Profiles" to configure your clinic team.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                      dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                      horizontalMargin: 12,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Clinician')),
                        DataColumn(label: Text('Speciality & Reg No')),
                        DataColumn(label: Text('Patients Attended')),
                        DataColumn(label: Text('Fees Collected')),
                        DataColumn(label: Text('Payment Modes Breakdown')),
                        DataColumn(label: Text('Pharmacy Rx Sales')),
                      ],
                      rows: _clinicDoctors.map((doc) {
                        final dName = (doc['full_name'] ?? 'Doctor').toString();
                        final displayName = dName.startsWith('Dr.') || dName.startsWith('Dr ') ? dName : 'Dr. $dName';
                        final spec = (doc['speciality'] ?? 'General').toString();
                        final regNo = (doc['registration_no'] ?? '').toString();
                        final totalAppts = doc['total_appointments'] ?? doc['total_patients'] ?? 0;
                        final visitedAppts = doc['visited_appointments'] ?? doc['visited_patients'] ?? 0;
                        final fees = ((doc['total_fees_collected'] ?? 0) as num).toDouble();
                        final feesByMode = (doc['fees_by_mode'] as Map?) ?? {};
                        final rxSales = ((doc['medicine_sales_referred'] ?? doc['referred_medicine_sales'] ?? 0) as num).toDouble();

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: const Color(0xFF0284C7).withOpacity(0.1),
                                    child: const Icon(Icons.person, size: 14, color: Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(spec, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                                  if (regNo.isNotEmpty)
                                    Text('Reg: $regNo', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            DataCell(
                              Text('$visitedAppts attended / $totalAppts total', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            DataCell(
                              Text('${CurrencyService.symbol}${fees.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((feesByMode['CASH'] ?? 0) > 0)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Cash: ${CurrencyService.symbol}${feesByMode['CASH']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                    ),
                                  if ((feesByMode['UPI'] ?? 0) > 0)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                                      child: Text('UPI: ${CurrencyService.symbol}${feesByMode['UPI']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                                    ),
                                  if ((feesByMode['CARD'] ?? 0) > 0)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Card: ${CurrencyService.symbol}${feesByMode['CARD']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8))),
                                    ),
                                  if ((feesByMode['PAY_LATER'] ?? 0) > 0)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Pay Later: ${CurrencyService.symbol}${feesByMode['PAY_LATER']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                    ),
                                  if ((feesByMode['PACKAGE'] ?? 0) > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFDF2F8), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Package (${feesByMode['PACKAGE']} sessions)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: rxSales > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: rxSales > 0 ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  '${CurrencyService.symbol}${rxSales.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: rxSales > 0 ? const Color(0xFF166534) : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangePill(String label, int days) {
    final sel = _analyticsRangeLabel == label;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        setState(() {
          _analyticsRangeLabel = label;
          _analyticsToDate = DateTime.now();
          _analyticsFromDate = DateTime.now().subtract(Duration(days: days));
        });
        _fetchAnalytics();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: sel ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : const Color(0xFF334155)),
        ),
      ),
    );
  }


  // ==========================================
  // TAB 3: THERAPY & SERVICE SUBSCRIPTIONS
  // ==========================================
  Future<void> _fetchSubscriptions() async {
    setState(() => _isLoadingSubscriptions = true);
    try {
      final queryParams = <String, dynamic>{};
      if (_subscriptionFilter != 'ALL') {
        queryParams['status'] = _subscriptionFilter;
      }
      if (_subSearchCtrl.text.trim().isNotEmpty) {
        queryParams['search'] = _subSearchCtrl.text.trim();
      }
      final res = await ApiClient.get(
        ApiEndpoints.clinicSubscriptions,
        queryParams: queryParams,
      );
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _subscriptions = res['data'] ?? [];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingSubscriptions = false);
    }
  }

  Future<void> _printOpdReport() async {
    final propertyCtrl = Provider.of<PropertyInfoController>(context, listen: false);
    await ClinicOpdReportPdf.printReport(
      context: context,
      appointments: _appointments,
      fromDate: _fromDate,
      toDate: _toDate,
      doctorFilter: _selectedDoctorFilter,
      property: propertyCtrl.propertyInfo,
    );
  }

  void _openConsumePackageDialog(dynamic appt, dynamic sub) {
    final subId = sub['id'];
    final apptId = appt['id'];
    final patientName = (appt['patient_name'] ?? 'Patient').toString();
    final packageName = (sub['package_name'] ?? 'Therapy Package').toString();
    final consumed = int.tryParse('${sub['services_consumed']}') ?? 0;
    final total = int.tryParse('${sub['total_sessions']}') ?? 6;
    final nextSession = consumed + 1;

    String feeOption = 'FREE';
    final feeCtrl = TextEditingController(text: '0.00');
    String selectedMode = 'CASH';

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFAF5FF),
                child: Icon(Icons.spa_rounded, color: Color(0xFF7C3AED), size: 20),
              ),
              SizedBox(width: 10),
              Text('Admit Therapy Package Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD8B4FE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF7C3AED), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Patient: $patientName\nService: $packageName (Session #$nextSession of $total)\nStatus: Admitting to Doctor queue (Doctor will attend patient)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF581C87)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Billing & Consultation Fee Action:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 8),

                // Case 2: Free / Covered by Package (Default)
                RadioListTile<String>(
                  value: 'FREE',
                  groupValue: feeOption,
                  title: const Text('Covered by Package (Free • €0.00 Co-pay Fee)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Admit session to doctor queue. Rate is debited from customer advance in Universal Cash Ledger.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  activeColor: const Color(0xFF7C3AED),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDState(() => feeOption = v ?? 'FREE'),
                ),

                // Case 1: Charge Consultation / Co-pay Fee
                RadioListTile<String>(
                  value: 'CHARGE',
                  groupValue: feeOption,
                  title: const Text('Charge Consultation / Co-pay Fee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Admit session AND collects co-pay fee into Universal Financial Ledger.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  activeColor: const Color(0xFF7C3AED),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDState(() => feeOption = v ?? 'CHARGE'),
                ),

                if (feeOption == 'CHARGE') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: feeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Fee Amount to Charge (${CurrencyService.symbol})',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedMode,
                    decoration: InputDecoration(
                      labelText: 'Payment Mode',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                      DropdownMenuItem(value: 'CARD', child: Text('Debit / Credit Card')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
                    ],
                    onChanged: (m) {
                      if (m != null) setDState(() => selectedMode = m);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dCtx);
                final double finalFee = feeOption == 'CHARGE' ? (double.tryParse(feeCtrl.text.trim()) ?? 0.0) : 0.0;
                _consumeSubscriptionSessionWithFee(
                  subId: subId,
                  appointmentId: apptId,
                  fee: finalFee,
                  paymentMode: feeOption == 'CHARGE' ? selectedMode : 'PACKAGE_SUBSCRIPTION',
                );
              },
              child: const Text('CONFIRM & ADMIT SESSION TO QUEUE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _consumeSubscriptionSessionWithFee({
    required dynamic subId,
    required dynamic appointmentId,
    required double fee,
    required String paymentMode,
  }) async {
    try {
      final res = await ApiClient.post(
        ApiEndpoints.clinicSubscriptionConsume(subId),
        {
          if (appointmentId != null) 'appointment_id': appointmentId,
          'fee': fee,
          'payment_mode': paymentMode,
          'notes': fee > 0
              ? 'Package session consumed with fee: ${CurrencyService.symbol}$fee via $paymentMode'
              : 'Package session consumed (Covered • 0.00)',
        },
      );
      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(res['message'] ?? 'Therapy session successfully consumed!'),
          ),
        );
        _fetchAppointments();
        _fetchSubscriptions();
        _fetchAnalytics();
      } else if (res != null && res['message'] != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(res['message'])),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _consumeSubscriptionSession(dynamic subId, dynamic appointmentId) async {
    try {
      final res = await ApiClient.post(
        ApiEndpoints.clinicSubscriptionConsume(subId),
        {
          if (appointmentId != null) 'appointment_id': appointmentId,
          'notes': 'Session consumed via Clinic OPD Queue',
        },
      );
      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(res['message'] ?? 'Therapy session successfully consumed!'),
          ),
        );
        _fetchAppointments();
        _fetchSubscriptions();
        _fetchAnalytics();
      } else if (res != null && res['message'] != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(res['message'])),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildSubscriptionsTab() {
    final inr = CurrencyService.currencyFormat;
    final totalActive = _subscriptions.where((s) => (s['status'] ?? '').toString().toUpperCase() == 'ACTIVE').length;
    final totalSessions = _subscriptions.fold<int>(0, (sum, s) => sum + (int.tryParse('${s['total_package_sessions']}') ?? 0));
    final consumedSessions = _subscriptions.fold<int>(0, (sum, s) => sum + (int.tryParse('${s['services_consumed']}') ?? 0));
    final remainingSessions = totalSessions - consumedSessions;
    final totalRev = _subscriptions.fold<double>(0.0, (sum, s) => sum + (double.tryParse('${s['total_payment_amount']}') ?? 0.0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_membership_rounded, color: Color(0xFF7C3AED), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Therapy Packages & Service Subscriptions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Manage monthly therapy packages (e.g. 6 paid + free bonus sessions), track session consumption & view ledger.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Therapy Subscription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _openCreateSubscriptionDialog(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Top KPI Cards
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 900;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                childAspectRatio: isWide ? 2.3 : 2.0,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _metricCard(
                    title: 'Active Packages',
                    value: '$totalActive',
                    subtitle: '${_subscriptions.length} total customer packages',
                    icon: Icons.assignment_turned_in_rounded,
                    accentColor: const Color(0xFF7C3AED),
                  ),
                  _metricCard(
                    title: 'Sessions Consumed',
                    value: '$consumedSessions / $totalSessions',
                    subtitle: 'Total therapy sessions fulfilled',
                    icon: Icons.check_circle_rounded,
                    accentColor: const Color(0xFF059669),
                  ),
                  _metricCard(
                    title: 'Sessions Remaining',
                    value: '$remainingSessions',
                    subtitle: 'Prepaid pending sessions',
                    icon: Icons.hourglass_top_rounded,
                    accentColor: const Color(0xFF0284C7),
                  ),
                  _metricCard(
                    title: 'Subscription Revenue',
                    value: inr.format(totalRev),
                    subtitle: 'Linked to universal finance ledger',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: const Color(0xFFD97706),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Filters & Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by patient name, phone, or therapy package...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                  onSubmitted: (_) => _fetchSubscriptions(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _fetchSubscriptions,
                child: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [
                  _subFilterChip('ALL', 'All'),
                  _subFilterChip('ACTIVE', 'Active'),
                  _subFilterChip('EXHAUSTED', 'Exhausted'),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Subscriptions List
          if (_isLoadingSubscriptions)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF7C3AED))))
          else if (_subscriptions.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.card_membership_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No therapy subscriptions found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    const Text('Create a monthly therapy package for recurring treatments and customer sessions.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create First Subscription'),
                      onPressed: () => _openCreateSubscriptionDialog(),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _subscriptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) => _buildSubscriptionCard(_subscriptions[idx]),
            ),
        ],
      ),
    );
  }

  Widget _subFilterChip(String key, String label) {
    final isSelected = _subscriptionFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
      selected: isSelected,
      selectedColor: const Color(0xFF7C3AED),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? Colors.transparent : const Color(0xFFCBD5E1)),
      onSelected: (val) {
        if (val) {
          setState(() => _subscriptionFilter = key);
          _fetchSubscriptions();
        }
      },
    );
  }

  Widget _buildSubscriptionCard(dynamic s) {
    final inr = CurrencyService.currencyFormat;
    final totalSessions = int.tryParse('${s['total_package_sessions']}') ?? 6;
    final consumed = int.tryParse('${s['services_consumed']}') ?? 0;
    final remaining = (totalSessions - consumed).clamp(0, totalSessions);
    final progress = totalSessions > 0 ? (consumed / totalSessions).clamp(0.0, 1.0) : 0.0;
    final status = (s['status'] ?? 'ACTIVE').toString().toUpperCase();
    final isExhausted = remaining <= 0 || status == 'EXHAUSTED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                child: const Icon(Icons.spa_rounded, color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s['customer_name'] ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Package #${s['id'] ?? '-'}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isExhausted ? Colors.grey.withValues(alpha: 0.1) : const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isExhausted ? Colors.grey.shade300 : const Color(0xFF059669).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            isExhausted ? 'EXHAUSTED' : 'ACTIVE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isExhausted ? Colors.grey.shade700 : const Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Phone: ${s['customer_phone'] ?? '-'}  •  Service: ${s['item_name'] ?? 'Therapy'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    inr.format(double.tryParse('${s['total_payment_amount']}') ?? 0.0),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${s['per_service_price'] != null ? inr.format(double.tryParse('${s['per_service_price']}') ?? 0) : ''}/session',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(isExhausted ? Colors.grey : const Color(0xFF7C3AED)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$consumed of $totalSessions Consumed ($remaining Left)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isExhausted ? Colors.grey : const Color(0xFF7C3AED)),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Bottom Actions
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'Valid: ${s['start_date'] ?? ''} to ${s['end_date'] ?? ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF0284C7)),
                label: const Text('View Ledger & Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () => _openSubscriptionLedgerDialog(s),
              ),
              if (!isExhausted) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                  label: Text('Deduct Session (#${consumed + 1})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: () => _consumeSubscriptionSession(s['id'], null),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // DIALOG: View Subscription Financial Ledger & Consumption History
  void _openSubscriptionLedgerDialog(dynamic sub) {
    showDialog(
      context: context,
      builder: (_) => _SubscriptionLedgerDialog(subscription: sub),
    );
  }

  // DIALOG: Create New Therapy Subscription
  void _openCreateSubscriptionDialog({String? initialCustomerName, String? initialCustomerPhone}) {
    showDialog(
      context: context,
      builder: (_) => _CreateSubscriptionDialog(
        initialName: initialCustomerName,
        initialPhone: initialCustomerPhone,
        onCreated: () {
          _fetchSubscriptions();
          _fetchAppointments();
          _fetchAnalytics();
        },
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

// ==========================================
// DOCTOR PRESCRIPTION & CONSULTATION DIALOG
// With:
// 1. Scan / Upload Prescription & Auto-Fill
// 2. Medicine lookup from item_master with live stock badges
// 3. Print / Export PDF Prescription
// ==========================================
class _DoctorPrescriptionDialog extends StatefulWidget {
  final dynamic appointment;
  final VoidCallback onSaved;
  final VoidCallback onSendBilling;
  final String userRole;
  final String loggedInDoctorName;
  final int? loggedInDoctorId;
  final String? selectedDeskDoctor;

  const _DoctorPrescriptionDialog({
    required this.appointment,
    required this.onSaved,
    required this.onSendBilling,
    this.userRole = '',
    this.loggedInDoctorName = '',
    this.loggedInDoctorId,
    this.selectedDeskDoctor,
  });

  @override
  State<_DoctorPrescriptionDialog> createState() => _DoctorPrescriptionDialogState();
}

class _DoctorPrescriptionDialogState extends State<_DoctorPrescriptionDialog> {
  static String _formatDoctorName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Dr. Specialist';
    final clean = trimmed.replaceAll(RegExp(r'^(dr\.?\s*)+', caseSensitive: false), '').trim();
    return 'Dr. $clean';
  }

  bool get _canEdit {
    final role = widget.userRole.trim().toUpperCase();

    // 1. Full admin / owner / clinic manager override
    if (role == 'ADMIN' ||
        role == 'SUPERADMIN' ||
        role == 'OWNER' ||
        role == 'CLINIC_ADMIN' ||
        role == 'MANAGER' ||
        role == 'DOCTOR_ADMIN') {
      return true;
    }

    String clean(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'^(dr\.?\s*)+', caseSensitive: false), '').trim();

    final apptDocName = clean((widget.appointment['attended_by_doctor_name'] ??
            widget.appointment['doctor_name'] ??
            '')
        .toString());
    final myName = clean(widget.loggedInDoctorName);
    final deskName = clean(widget.selectedDeskDoctor ?? '');

    // 2. Matching doctor ID
    final apptDocId = widget.appointment['doctor_id'];
    if (widget.loggedInDoctorId != null &&
        apptDocId != null &&
        widget.loggedInDoctorId == apptDocId) {
      return true;
    }

    // 3. Matching logged-in doctor name or selected consultation desk doctor name
    if (myName.isNotEmpty && (apptDocName.contains(myName) || myName.contains(apptDocName))) {
      return true;
    }
    if (deskName.isNotEmpty &&
        deskName != 'all' &&
        (apptDocName.contains(deskName) || deskName.contains(apptDocName))) {
      return true;
    }

    // 4. If new consultation / patient waiting in queue and no prescription exists yet
    final status = (widget.appointment['status'] ?? '').toString().toUpperCase();
    final isVisited = status == 'VISITED' || status == 'COMPLETED';
    final hasPrescription = widget.appointment['attended_by_doctor_name'] != null ||
        (widget.appointment['prescription_notes'] != null &&
            widget.appointment['prescription_notes'].toString().isNotEmpty) ||
        (widget.appointment['prescribed_medicines'] is List &&
            (widget.appointment['prescribed_medicines'] as List).isNotEmpty);

    if (!isVisited && !hasPrescription) {
      final isDoctor = role == 'DOCTOR' || role.contains('DOCTOR');
      if (isDoctor || deskName.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _doctorCtrl = TextEditingController();
  final TextEditingController _diagnosisCtrl = TextEditingController();
  final TextEditingController _dietAdviceCtrl = TextEditingController();

  // Clinical Vitals Controllers
  final TextEditingController _bpCtrl = TextEditingController();
  final TextEditingController _pulseCtrl = TextEditingController();
  final TextEditingController _tempCtrl = TextEditingController();
  final TextEditingController _sugarCtrl = TextEditingController();
  final TextEditingController _spo2Ctrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();

  // Custom Test Inputs
  final TextEditingController _customTestNameCtrl = TextEditingController();
  final TextEditingController _customTestValueCtrl = TextEditingController();
  final TextEditingController _customTestUnitCtrl = TextEditingController();

  List<Map<String, dynamic>> _prescribedMedicines = [];
  List<dynamic> _availableMedicines = [];
  List<Map<String, dynamic>> _labTests = [];
  List<String> _patientAllergies = [];
  List<Map<String, dynamic>> _standardTestsMaster = [];
  List<Map<String, dynamic>> _customTestsMaster = [];
  List<dynamic> _pastConsultations = [];

  bool _saving = false;
  bool _loadingHistory = false;
  bool _isRepeatPatient = false;

  // Prescription scan / upload state
  PlatformFile? _uploadedFile;
  bool _isAutoFilling = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.appointment['prescription_notes'] ?? '';
    final initialDoc = (widget.appointment['attended_by_doctor_name'] ?? 
                        widget.appointment['doctor_name'] ?? 
                        (widget.selectedDeskDoctor != null && widget.selectedDeskDoctor != 'ALL' ? widget.selectedDeskDoctor : null) ?? 
                        widget.loggedInDoctorName).toString();
    _doctorCtrl.text = _formatDoctorName(initialDoc);
    _diagnosisCtrl.text = widget.appointment['diagnosis'] ?? widget.appointment['reason_for_visit'] ?? '';

    // Unpack existing vital signs if available
    final rawVitals = widget.appointment['vital_signs'];
    if (rawVitals is Map) {
      _bpCtrl.text = (rawVitals['blood_pressure'] ?? rawVitals['bp'] ?? '').toString();
      _pulseCtrl.text = (rawVitals['pulse'] ?? rawVitals['pulse_rate'] ?? '').toString();
      _tempCtrl.text = (rawVitals['temperature'] ?? rawVitals['temp'] ?? '').toString();
      _sugarCtrl.text = (rawVitals['sugar_level'] ?? rawVitals['sugar'] ?? '').toString();
      _spo2Ctrl.text = (rawVitals['spo2'] ?? '').toString();
      _weightCtrl.text = (rawVitals['weight'] ?? '').toString();
      _dietAdviceCtrl.text = (rawVitals['diet_advice'] ?? '').toString();

      if (rawVitals['allergies'] is List) {
        _patientAllergies = (rawVitals['allergies'] as List).map((e) => e.toString()).toList();
      } else if (rawVitals['allergies'] != null && rawVitals['allergies'].toString().isNotEmpty) {
        _patientAllergies = [rawVitals['allergies'].toString()];
      }

      final tests = rawVitals['lab_tests'] ?? rawVitals['tests'];
      if (tests is List) {
        _labTests = tests.map((t) => Map<String, dynamic>.from(t)).toList();
      }
    }

    final meds = widget.appointment['prescribed_medicines'];
    if (meds is List) {
      _prescribedMedicines = meds.map((m) => Map<String, dynamic>.from(m)).toList();
    }

    _loadAvailableMedicines();
    _loadClinicalTestsMaster();
    _fetchPatientHistory();
  }

  Future<void> _loadAvailableMedicines() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicMedicines);
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _availableMedicines = res['data'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadClinicalTestsMaster() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicTestsMaster);
      if (res != null && res['success'] == true && mounted) {
        final d = res['data'];
        setState(() {
          if (d != null) {
            _standardTestsMaster = (d['standard_tests'] as List? ?? []).map((t) => Map<String, dynamic>.from(t)).toList();
            _customTestsMaster = (d['custom_tests'] as List? ?? []).map((t) => Map<String, dynamic>.from(t)).toList();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPatientHistory() async {
    final phone = (widget.appointment['patient_phone'] ?? '').toString().trim();
    if (phone.isEmpty) return;

    setState(() => _loadingHistory = true);
    try {
      final res = await ApiClient.get('${ApiEndpoints.clinicPatientHistory}?phone=$phone');
      if (res != null && res['success'] == true && mounted) {
        final List allHistory = res['data'] ?? [];
        // Filter out current appointment so only prior visits show
        final currentId = widget.appointment['id'];
        final prior = allHistory.where((h) => h['id'] != currentId).toList();
        setState(() {
          _pastConsultations = prior;
          _isRepeatPatient = prior.isNotEmpty || widget.appointment['is_repeat_patient'] == true;

          // Auto fill allergies from previous records if current is empty
          if (_patientAllergies.isEmpty && prior.isNotEmpty) {
            for (final p in prior) {
              final v = p['vital_signs'];
              if (v is Map && v['allergies'] is List) {
                final al = (v['allergies'] as List).map((e) => e.toString()).toList();
                if (al.isNotEmpty) {
                  _patientAllergies = al;
                  break;
                }
              }
            }
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _repeatPreviousRx(dynamic pastAppt) {
    final rawMeds = pastAppt['prescribed_medicines'];
    if (rawMeds is List && rawMeds.isNotEmpty) {
      setState(() {
        _prescribedMedicines = rawMeds.map((m) => Map<String, dynamic>.from(m)).toList();
        if (_notesCtrl.text.isEmpty && pastAppt['prescription_notes'] != null) {
          _notesCtrl.text = pastAppt['prescription_notes'].toString();
        }
        final pastVitals = pastAppt['vital_signs'];
        if (pastVitals is Map) {
          if (_dietAdviceCtrl.text.isEmpty && pastVitals['diet_advice'] != null) {
            _dietAdviceCtrl.text = pastVitals['diet_advice'].toString();
          }
          if (_patientAllergies.isEmpty && pastVitals['allergies'] is List) {
            _patientAllergies = (pastVitals['allergies'] as List).map((e) => e.toString()).toList();
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${rawMeds.length} medications and advice from visit on ${pastAppt['appointment_date']}!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No prescribed medicines found in this previous record.'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _pickPrescriptionFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _uploadedFile = result.files.first;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription file selected: ${_uploadedFile!.name}'),
            backgroundColor: const Color(0xFF0284C7),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _autoFillFromScannedPrescription() async {
    if (_uploadedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload or scan a prescription document first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isAutoFilling = true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        if (_notesCtrl.text.isEmpty) {
          _notesCtrl.text = 'Scanned paper prescription document attached: ${_uploadedFile!.name}';
        }
        _isAutoFilling = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document "${_uploadedFile!.name}" attached to Rx! You can now review vitals and medicines.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _savePrescription() async {
    setState(() => _saving = true);
    try {
      final vitalSigns = {
        'blood_pressure': _bpCtrl.text.trim(),
        'pulse': _pulseCtrl.text.trim(),
        'temperature': _tempCtrl.text.trim(),
        'sugar_level': _sugarCtrl.text.trim(),
        'spo2': _spo2Ctrl.text.trim(),
        'weight': _weightCtrl.text.trim(),
        'allergies': _patientAllergies,
        'diet_advice': _dietAdviceCtrl.text.trim(),
        'lab_tests': _labTests,
        'custom_tests': _labTests.where((t) => t['is_custom'] == true).toList(),
        'attended_by_doctor_name': _doctorCtrl.text.trim(),
      };

      final res = await ApiClient.post(
        ApiEndpoints.clinicAppointmentPrescription(widget.appointment['id']),
        {
          'prescription_notes': _notesCtrl.text.trim(),
          'diagnosis': _diagnosisCtrl.text.trim(),
          'doctor_name': _doctorCtrl.text.trim(),
          'attended_by_doctor_name': _doctorCtrl.text.trim(),
          'prescribed_medicines': _prescribedMedicines,
          'prescription_file_url': _uploadedFile != null ? _uploadedFile!.name : null,
          'vital_signs': vitalSigns,
        },
      );

      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription & clinical observations saved successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save prescription: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addMedicine() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

  void _openAddLabTestDialog() {
    String selectedTestName = _standardTestsMaster.isNotEmpty
        ? (_standardTestsMaster.first['test_name'] ?? 'Blood Test (CBC)')
        : 'Blood Test (CBC)';
    final readingCtrl = TextEditingController();
    final unitCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final allAvailableTests = [
            ..._standardTestsMaster.map((t) => (t['test_name'] ?? '').toString()),
            ..._customTestsMaster.map((t) => (t['test_name'] ?? '').toString()),
          ].where((t) => t.isNotEmpty).toSet().toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.biotech_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text('Add Diagnostic / Lab Test', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Test from Master:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: allAvailableTests.contains(selectedTestName) ? selectedTestName : (allAvailableTests.isNotEmpty ? allAvailableTests.first : null),
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: allAvailableTests.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setDState(() => selectedTestName = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: readingCtrl,
                    decoration: InputDecoration(
                      labelText: 'Doctor Finding / Reading / Result',
                      hintText: 'e.g. 110 mg/dL, Hb 14.2, Normal, Clear...',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitCtrl,
                    decoration: InputDecoration(
                      labelText: 'Unit / Reference Range (Optional)',
                      hintText: 'e.g. mg/dL, 70-100, /cu.mm',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: () {
                  if (selectedTestName.isNotEmpty) {
                    setState(() {
                      _labTests.add({
                        'test_name': selectedTestName,
                        'value': readingCtrl.text.trim(),
                        'unit': unitCtrl.text.trim(),
                        'is_custom': false,
                      });
                    });
                    Navigator.pop(dCtx);
                  }
                },
                child: const Text('Add Test'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddCustomTestDialog() {
    _customTestNameCtrl.clear();
    _customTestValueCtrl.clear();
    _customTestUnitCtrl.clear();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('Add Custom Test to Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customTestNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Custom Test Name *',
                  hintText: 'e.g. Serum Creatinine, D-Dimer, KFT, LFT...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _customTestValueCtrl,
                decoration: InputDecoration(
                  labelText: 'Observed Reading / Result',
                  hintText: 'e.g. 0.9 mg/dL, Normal, Elevated...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _customTestUnitCtrl,
                decoration: InputDecoration(
                  labelText: 'Default Unit / Normal Range (Optional)',
                  hintText: 'e.g. 0.7-1.3 mg/dL',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
            onPressed: () async {
              final testName = _customTestNameCtrl.text.trim();
              if (testName.isEmpty) return;

              // Save to master via backend
              try {
                await ApiClient.post(ApiEndpoints.clinicTestsMaster, {
                  'test_name': testName,
                  'category': 'CUSTOM',
                  'default_unit': _customTestUnitCtrl.text.trim(),
                });
              } catch (_) {}

              setState(() {
                _labTests.add({
                  'test_name': testName,
                  'value': _customTestValueCtrl.text.trim(),
                  'unit': _customTestUnitCtrl.text.trim(),
                  'is_custom': true,
                });
                _customTestsMaster.add({'test_name': testName, 'category': 'CUSTOM'});
              });

              Navigator.pop(dCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Custom test "$testName" added to prescription and saved in Master!'),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            },
            child: const Text('Save & Add to Rx'),
          ),
        ],
      ),
    );
  }

  void _openAddAllergyDialog() {
    final allergyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Add Patient Allergy / Contraindication', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: allergyCtrl,
                decoration: InputDecoration(
                  labelText: 'Allergy / Drug Name',
                  hintText: 'e.g. Penicillin, Sulfa, Paracetamol, Dust, NSAIDs...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['Penicillin', 'Sulfa Drugs', 'Aspirin', 'Paracetamol', 'Dust / Pollen', 'Latex'].map((s) {
                  return ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      allergyCtrl.text = s;
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final a = allergyCtrl.text.trim();
              if (a.isNotEmpty && !_patientAllergies.contains(a)) {
                setState(() => _patientAllergies.add(a));
                Navigator.pop(dCtx);
              }
            },
            child: const Text('Add Allergy'),
          ),
        ],
      ),
    );
  }

  void _showPastHistoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Past Consultations: ${widget.appointment['patient_name']} (${_pastConsultations.length} Visits)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 680,
          height: 480,
          child: _pastConsultations.isEmpty
              ? const Center(
                  child: Text('No previous visited consultations on file for this patient.', style: TextStyle(color: Color(0xFF64748B))),
                )
              : ListView.separated(
                  itemCount: _pastConsultations.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (c, idx) {
                    final h = _pastConsultations[idx];
                    final date = h['appointment_date'] ?? '-';
                    final doc = h['doctor_name'] ?? 'Doctor';
                    final diag = h['diagnosis'] ?? h['prescription_notes'] ?? 'General Checkup';
                    final meds = h['prescribed_medicines'] as List? ?? [];
                    final vitals = h['vital_signs'] is Map ? (h['vital_signs'] as Map) : {};

                    return Container(
                      padding: const EdgeInsets.all(12),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Visit Date: $date', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                              ),
                              const SizedBox(width: 8),
                              Text('Consultant: Dr. $doc', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                              const Spacer(),
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEDE9FE),
                                  foregroundColor: const Color(0xFF7C3AED),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: const Text('Repeat This Rx', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _repeatPreviousRx(h);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Diagnosis: $diag', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          if (vitals.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Vitals: BP: ${vitals['blood_pressure'] ?? '-'} • Pulse: ${vitals['pulse'] ?? '-'} • Temp: ${vitals['temperature'] ?? '-'} • Sugar: ${vitals['sugar_level'] ?? '-'}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                          if (meds.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            const Text('Medicines Prescribed:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: meds.map((m) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    '${m['item_name']} (${m['dosage'] ?? '1-0-1'}, ${m['duration'] ?? '5 Days'})',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E293B)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _printPrescription() {
    final property = Provider.of<PropertyInfoController>(context, listen: false).propertyInfo;
    final tempAppt = Map<String, dynamic>.from(widget.appointment);
    tempAppt['doctor_name'] = _doctorCtrl.text.trim();
    tempAppt['attended_by_doctor_name'] = _doctorCtrl.text.trim();
    tempAppt['diagnosis'] = _diagnosisCtrl.text.trim();
    tempAppt['prescription_notes'] = _notesCtrl.text.trim();
    tempAppt['prescribed_medicines'] = _prescribedMedicines;
    tempAppt['vital_signs'] = {
      'blood_pressure': _bpCtrl.text.trim(),
      'pulse': _pulseCtrl.text.trim(),
      'temperature': _tempCtrl.text.trim(),
      'sugar_level': _sugarCtrl.text.trim(),
      'spo2': _spo2Ctrl.text.trim(),
      'weight': _weightCtrl.text.trim(),
      'allergies': _patientAllergies,
      'diet_advice': _dietAdviceCtrl.text.trim(),
      'lab_tests': _labTests,
      'attended_by_doctor_name': _doctorCtrl.text.trim(),
    };

    ClinicPrescriptionPdf.printOrDownloadPrescription(
      context: context,
      appointment: tempAppt,
      property: property,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 880,
        height: 690,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DIALOG HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_rounded, color: Color(0xFF0284C7), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Doctor Consultation & Rx: ${widget.appointment['patient_name']}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          if (_isRepeatPatient) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFD8B4FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.repeat_rounded, size: 12, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'REPEAT PATIENT (${_pastConsultations.length} Prior Visits)',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Phone: ${widget.appointment['patient_phone'] ?? '-'}  •  Age: ${widget.appointment['patient_age'] ?? '-'}  •  Token #${widget.appointment['id']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                if (_pastConsultations.isNotEmpty) ...[
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFAF5FF),
                      foregroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.history_edu_rounded, size: 16),
                    label: Text('Past Rx (${_pastConsultations.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: _showPastHistoryDialog,
                  ),
                  if (_pastConsultations.isNotEmpty && _canEdit) ...[
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Refill Last Rx', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _repeatPreviousRx(_pastConsultations.first),
                    ),
                  ],
                  const SizedBox(width: 6),
                ],

                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const Divider(height: 16),

            if (!_canEdit) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-Only View: Prescription authored by ${_formatDoctorName((widget.appointment['attended_by_doctor_name'] ?? widget.appointment['doctor_name'] ?? 'Consultant').toString())}. Only the prescribing doctor can edit this prescription. You can view all details and print the PDF Rx.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ALLERGIES ALERT BANNER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _patientAllergies.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _patientAllergies.isNotEmpty ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    _patientAllergies.isNotEmpty ? Icons.warning_rounded : Icons.shield_outlined,
                    color: _patientAllergies.isNotEmpty ? Colors.red : const Color(0xFF64748B),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Known Allergies: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _patientAllergies.isNotEmpty ? Colors.red.shade900 : const Color(0xFF475569),
                    ),
                  ),
                  Expanded(
                    child: _patientAllergies.isEmpty
                        ? const Text('None recorded', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic))
                        : Wrap(
                            spacing: 6,
                            children: _patientAllergies.map((a) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(a, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                                    if (_canEdit) ...[
                                      const SizedBox(width: 2),
                                      InkWell(
                                        onTap: () => setState(() => _patientAllergies.remove(a)),
                                        child: Icon(Icons.close, size: 12, color: Colors.red.shade900),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  if (_canEdit)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add Allergy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _openAddAllergyDialog,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // FORM BODY
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: DOCTOR & DIAGNOSIS
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _doctorCtrl,
                            readOnly: !_canEdit,
                            decoration: InputDecoration(
                              labelText: 'Attending Doctor Name',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: TextField(
                            controller: _diagnosisCtrl,
                            readOnly: !_canEdit,
                            decoration: InputDecoration(
                              labelText: 'Clinical Diagnosis & Symptoms',
                              hintText: 'e.g. Acute Pharyngitis, Viral Fever, Gastritis...',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // VITALS & MEASUREMENTS CARD
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.monitor_heart_rounded, size: 16, color: Color(0xFF0284C7)),
                              SizedBox(width: 6),
                              Text('Patient Vital Signs & Physical Readings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _bpCtrl,
                                  readOnly: !_canEdit,
                                  decoration: InputDecoration(
                                    labelText: 'Blood Pressure',
                                    hintText: '120/80',
                                    suffixText: 'mmHg',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _pulseCtrl,
                                  readOnly: !_canEdit,
                                  decoration: InputDecoration(
                                    labelText: 'Pulse Rate',
                                    hintText: '72',
                                    suffixText: 'bpm',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _tempCtrl,
                                  readOnly: !_canEdit,
                                  decoration: InputDecoration(
                                    labelText: 'Temperature',
                                    hintText: '98.6',
                                    suffixText: '°F',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _sugarCtrl,
                                  readOnly: !_canEdit,
                                  decoration: InputDecoration(
                                    labelText: 'Blood Sugar',
                                    hintText: '110',
                                    suffixText: 'mg/dL',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _weightCtrl,
                                  readOnly: !_canEdit,
                                  decoration: InputDecoration(
                                    labelText: 'Weight',
                                    hintText: '65',
                                    suffixText: 'kg',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _spo2Ctrl,
                                  readOnly: !_canEdit,
                                  decoration: InputDecoration(
                                    labelText: 'SpO2',
                                    hintText: '98',
                                    suffixText: '%',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // CLINICAL LAB INVESTIGATIONS & TESTS
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.biotech_rounded, size: 18, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 6),
                              const Text(
                                'Diagnostic Lab Investigations & Tests (Blood, Urine, Sugar, X-Ray, USG)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                              const Spacer(),
                              if (_canEdit) ...[
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0284C7),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.playlist_add_rounded, size: 16),
                                  label: const Text('Add Test', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: _openAddLabTestDialog,
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFAF5FF),
                                    foregroundColor: const Color(0xFF7C3AED),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                  label: const Text('+ Custom Test', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: _openAddCustomTestDialog,
                                ),
                              ],
                            ],
                          ),

                          if (_labTests.isEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 8),
                                  Text(
                                    'No diagnostic tests or imaging ordered yet. Click "Add Test" or "+ Custom Test" to record readings.',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _labTests.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (ctx, idx) {
                                final t = _labTests[idx];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: t['is_custom'] == true ? const Color(0xFFFAF5FF) : const Color(0xFFF0F9FF),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: t['is_custom'] == true ? const Color(0xFFD8B4FE) : const Color(0xFFBAE6FD)),
                                        ),
                                        child: Text(
                                          t['is_custom'] == true ? 'CUSTOM' : 'LAB',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: t['is_custom'] == true ? const Color(0xFF7C3AED) : const Color(0xFF0284C7)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          t['test_name'] ?? 'Test',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 5,
                                        child: Text(
                                          'Reading / Result: ${t['value'] != null && t['value'].toString().isNotEmpty ? t['value'] : 'Pending / Advised'}',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      if (t['unit'] != null && t['unit'].toString().isNotEmpty) ...[
                                        Text('(${t['unit']})', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        const SizedBox(width: 8),
                                      ],
                                      if (_canEdit)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                          onPressed: () => setState(() => _labTests.removeAt(idx)),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_canEdit) ...[
                      const SizedBox(height: 12),

                      // SCAN OR UPLOAD PRESCRIPTION BANNER
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _uploadedFile != null ? Icons.check_circle_rounded : Icons.document_scanner_rounded,
                              color: _uploadedFile != null ? const Color(0xFF059669) : const Color(0xFF0284C7),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _uploadedFile != null
                                        ? 'Scanned File: ${_uploadedFile!.name} (${(_uploadedFile!.size / 1024).toStringAsFixed(1)} KB)'
                                        : 'Scan or Upload Patient Prescription Document',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _uploadedFile != null
                                        ? 'Document attached. Click "Auto-Fill Rx" to extract medicines into the prescription.'
                                        : 'Attach paper prescription photograph or PDF to auto-fill notes and pharmaceutical inventory.',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: Text(_uploadedFile != null ? 'Replace' : 'Scan / Upload', style: const TextStyle(fontSize: 12)),
                              onPressed: _pickPrescriptionFile,
                            ),
                            if (_uploadedFile != null) ...[
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: _isAutoFilling
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.auto_fix_high_rounded, size: 16),
                                label: const Text('Auto-Fill Rx', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: _isAutoFilling ? null : _autoFillFromScannedPrescription,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // PRESCRIBED MEDICINES HEADER
                    Row(
                      children: [
                        const Text(
                          'Prescribed Medicines (In-Stock Pharmacy Inventory)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const Spacer(),
                        if (_canEdit)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _addMedicine,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Medicine from Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (_prescribedMedicines.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.medication_rounded, size: 36, color: Color(0xFF94A3B8)),
                            SizedBox(height: 8),
                            Text(
                              'No medications prescribed yet.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Click "Add Medicine from Stock" or upload a scanned prescription to populate.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _prescribedMedicines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, idx) {
                          final m = _prescribedMedicines[idx];
                          final stock = m['current_stock'] ?? 0;
                          final inStock = stock > 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['item_name'] ?? 'Medicine',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text('Code: ${m['item_code'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: inStock ? const Color(0xFF059669).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              inStock ? 'Stock: $stock' : 'Out of Stock',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: inStock ? const Color(0xFF059669) : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Dosage', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      Text(m['dosage'] ?? '1-0-1', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Frequency', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      Text(m['frequency'] ?? 'After Food', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Duration & Qty', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      Text('${m['duration'] ?? '5 Days'} (${m['qty'] ?? 1} units)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                if (_canEdit)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                    onPressed: () {
                                      setState(() => _prescribedMedicines.removeAt(idx));
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 14),

                    // DIET & LIFESTYLE ADVICE
                    TextField(
                      controller: _dietAdviceCtrl,
                      readOnly: !_canEdit,
                      decoration: InputDecoration(
                        labelText: 'Dietary & Lifestyle Recommendations',
                        hintText: 'e.g. Low sodium intake, drink 2-3L water daily, avoid oily/fried foods, regular light exercise...',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // NOTES & PRECAUTIONS
                    TextField(
                      controller: _notesCtrl,
                      readOnly: !_canEdit,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Physician Notes, Advice & Special Precautions',
                        hintText: 'e.g. Complete antibiotic course, drink plenty of fluids, report if fever recurs...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 20),

            // DIALOG FOOTER ACTIONS
            Row(
              children: [
                // Print PDF Prescription
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Print / Preview Rx PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _printPrescription,
                ),

                const Spacer(),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_canEdit ? 'Cancel' : 'Close', style: const TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 8),

                if (_canEdit)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saving ? null : _savePrescription,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Prescription', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print Rx (Read-Only)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _printPrescription,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// MEDICINE SELECTOR BOTTOM SHEET
// Features: Live item_master search, live stock balance badges,
// dosage builder (1-0-1 etc.), frequency, and duration auto-qty calculation.
// ==========================================
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

  String _selectedDosage = '1-0-1';
  String _selectedFrequency = 'After Meals';
  String _selectedDuration = '5 Days';
  int _calculatedQty = 10;

  final TextEditingController _customDosageCtrl = TextEditingController(text: '1-0-1');
  final TextEditingController _qtyCtrl = TextEditingController(text: '10');

  final List<String> _commonDosages = ['1-0-1', '1-0-0', '0-0-1', '1-1-1', '0-1-0', 'SOS'];
  final List<String> _commonFrequencies = ['After Meals', 'Before Meals', 'With Warm Water', 'At Bedtime', 'Empty Stomach'];
  final List<String> _commonDurations = ['3 Days', '5 Days', '7 Days', '10 Days', '15 Days', '30 Days'];

  @override
  void initState() {
    super.initState();
    _recalcQty();
  }

  void _recalcQty() {
    int timesPerDay = 2;
    if (_selectedDosage == '1-0-1') timesPerDay = 2;
    else if (_selectedDosage == '1-0-0' || _selectedDosage == '0-0-1' || _selectedDosage == '0-1-0') timesPerDay = 1;
    else if (_selectedDosage == '1-1-1') timesPerDay = 3;
    else if (_selectedDosage == 'SOS') timesPerDay = 1;

    final days = int.tryParse(_selectedDuration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5;
    setState(() {
      _calculatedQty = timesPerDay * days;
      _qtyCtrl.text = '$_calculatedQty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.availableMedicines.where((m) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      final name = (m['item_name'] ?? '').toString().toLowerCase();
      final code = (m['item_code'] ?? '').toString().toLowerCase();
      final brand = (m['brand'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || brand.contains(q);
    }).toList();

    return Container(
      height: 620,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF0284C7), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Medicine from Pharmacy Inventory', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Real-time stock balance & batch rates from itemmaster', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),

          const SizedBox(height: 10),

          // Search Box
          TextField(
            decoration: InputDecoration(
              hintText: 'Search medicine by generic name, brand or item code...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() => _filter = val),
          ),

          const SizedBox(height: 10),

          // Medicine List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No medicines matched "$_filter".',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      final isSelected = _selectedItem == item;
                      final stock = item['current_stock'] ?? 0;
                      final inStock = stock > 0;

                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF0284C7).withOpacity(0.08),
                        onTap: () {
                          setState(() => _selectedItem = item);
                        },
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['item_name'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: inStock ? const Color(0xFF059669).withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                inStock ? '● In Stock: $stock ${item['unit'] ?? 'PCS'}' : '✖ Out of Stock',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: inStock ? const Color(0xFF059669) : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Code: ${item['item_code']}  •  Brand: ${item['brand'] ?? 'General'}  •  Rate: \$${item['retail_sale_price'] ?? item['purchase_rate'] ?? 0}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      );
                    },
                  ),
          ),

          if (_selectedItem != null) ...[
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: ${_selectedItem['item_name']} (${_selectedItem['item_code']})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 8),

                  // Dosage selector chips
                  Row(
                    children: [
                      const Text('Dosage: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ..._commonDosages.map((d) {
                        final sel = _selectedDosage == d;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedDosage = d);
                              _recalcQty();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFF0284C7) : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: sel ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
                              ),
                              child: Text(d, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.black87)),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Duration selector chips & Qty
                  Row(
                    children: [
                      const Text('Duration: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ..._commonDurations.map((dur) {
                        final sel = _selectedDuration == dur;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedDuration = dur);
                              _recalcQty();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFF059669) : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: sel ? const Color(0xFF059669) : const Color(0xFFCBD5E1)),
                              ),
                              child: Text(dur, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.black87)),
                            ),
                          ),
                        );
                      }),
                      const Spacer(),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total Qty',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Add to Prescription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: _selectedItem == null
                  ? null
                  : () {
                      final qty = int.tryParse(_qtyCtrl.text.trim()) ?? _calculatedQty;
                      widget.onSelected({
                        'item_id': _selectedItem['id'],
                        'item_code': _selectedItem['item_code'],
                        'item_name': _selectedItem['item_name'],
                        'brand': _selectedItem['brand'],
                        'unit': _selectedItem['unit'] ?? 'PCS',
                        'dosage': _selectedDosage,
                        'frequency': _selectedFrequency,
                        'duration': _selectedDuration,
                        'qty': qty,
                        'rate': _selectedItem['retail_sale_price'] ?? _selectedItem['purchase_rate'] ?? 0,
                        'tax_percent': _selectedItem['tax_percent'] ?? 0,
                        'current_stock': _selectedItem['current_stock'] ?? 0,
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// NEW APPOINTMENT DIALOG
// ==========================================
class _NewAppointmentDialog extends StatefulWidget {
  final List<dynamic> doctors;
  final VoidCallback onCreated;
  const _NewAppointmentDialog({required this.doctors, required this.onCreated});

  @override
  State<_NewAppointmentDialog> createState() => _NewAppointmentDialogState();
}

class _NewAppointmentDialogState extends State<_NewAppointmentDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '0.00');

  // Therapy Package state
  final _packageNameCtrl = TextEditingController(text: 'Therapy Care Plan');
  final _sessionNumCtrl = TextEditingController(text: '1');
  final _totalSessionsCtrl = TextEditingController(text: '6');

  String _gender = 'MALE';
  String _doctorName = '';
  int? _doctorId;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;

  String _paymentOption = 'PAY_LATER'; // 'PAY_LATER', 'PAID_NOW', 'PACKAGE'
  String _paymentMode = 'CASH';
  List<Map<String, dynamic>> _masterPaymentMethods = [];
  bool _loadingPaymentMethods = false;

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
    if (doc == null) return true;
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

  @override
  void initState() {
    super.initState();
    if (widget.doctors.isNotEmpty) {
      final doc = widget.doctors.first;
      _doctorName = (doc['full_name'] ?? 'Doctor').toString();
      _doctorId = doc['id'];
      _feeCtrl.text = (((doc['consultation_fee'] ?? 0.0) as num).toDouble()).toStringAsFixed(2);
      _date = _findNextAvailableDate(DateTime.now(), doc);
    } else {
      _doctorName = 'Consultant Physician';
    }
    _loadMasterPaymentMethods();
  }

  Future<void> _loadMasterPaymentMethods() async {
    setState(() => _loadingPaymentMethods = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.paymentMethods);
      if (res != null && res['data'] is List && mounted) {
        final list = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() {
          _masterPaymentMethods = list;
          if (_masterPaymentMethods.isNotEmpty) {
            _paymentMode = (_masterPaymentMethods.first['name'] ?? 'CASH').toString().toUpperCase();
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingPaymentMethods = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _reasonCtrl.dispose();
    _feeCtrl.dispose();
    _packageNameCtrl.dispose();
    _sessionNumCtrl.dispose();
    _totalSessionsCtrl.dispose();
    super.dispose();
  }

  void _onDoctorSelected(String? name) {
    if (name == null) return;
    setState(() {
      _doctorName = name;
      final doc = widget.doctors.firstWhere(
        (d) => (d['full_name'] ?? '').toString() == name,
        orElse: () => null,
      );
      if (doc != null) {
        _doctorId = doc['id'];
        _feeCtrl.text = (((doc['consultation_fee'] ?? 0.0) as num).toDouble()).toStringAsFixed(2);
        if (!_isDoctorAvailableOn(_date, doc)) {
          _date = _findNextAvailableDate(DateTime.now(), doc);
        }
      }
    });
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter patient name and phone number.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final timeStr = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      final fee = double.tryParse(_feeCtrl.text.trim()) ?? 0.0;

      String payStatus = 'UNPAID';
      String? payMode;
      double paidAmt = 0.0;
      bool isPack = false;
      String? packName;
      int? sessNum;
      int? totSess;

      if (_paymentOption == 'PAY_LATER') {
        payStatus = 'PAY_LATER';
        payMode = 'PAY_LATER';
      } else if (_paymentOption == 'PAID_NOW') {
        payStatus = 'PAID';
        payMode = _paymentMode;
        paidAmt = fee;
      } else if (_paymentOption == 'PACKAGE') {
        payStatus = 'PACKAGE_INCLUDED';
        isPack = true;
        packName = _packageNameCtrl.text.trim().isNotEmpty ? _packageNameCtrl.text.trim() : 'Therapy Care Plan';
        sessNum = int.tryParse(_sessionNumCtrl.text.trim()) ?? 1;
        totSess = int.tryParse(_totalSessionsCtrl.text.trim()) ?? 6;
      }

      final res = await ApiClient.post(
        ApiEndpoints.clinicAppointments,
        {
          'patient_name': _nameCtrl.text.trim(),
          'patient_phone': _phoneCtrl.text.trim(),
          'patient_age': int.tryParse(_ageCtrl.text.trim()),
          'patient_gender': _gender,
          'appointment_date': DateFormat('yyyy-MM-dd').format(_date),
          'appointment_time': timeStr,
          'doctor_name': _doctorName,
          'doctor_id': _doctorId,
          'consultation_fee': fee,
          'reason_for_visit': _reasonCtrl.text.trim(),
          'payment_status': payStatus,
          'payment_mode': payMode,
          'paid_amount': paidAmt,
          'package_name': packName,
          'session_number': sessNum,
          'total_package_sessions': totSess,
          'is_package_session': isPack,
        },
      );

      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment scheduled successfully!'), backgroundColor: Color(0xFF059669)),
        );
        widget.onCreated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7)),
          SizedBox(width: 8),
          Text('Book OPD Patient Appointment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Selection
              if (widget.doctors.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: widget.doctors.any((d) => (d['full_name'] ?? '').toString() == _doctorName)
                      ? _doctorName
                      : (widget.doctors.first['full_name'] ?? '').toString(),
                  decoration: InputDecoration(
                    labelText: 'Attending Clinician / Doctor *',
                    isDense: true,
                    prefixIcon: const Icon(Icons.medical_services_outlined, size: 18, color: Color(0xFF0284C7)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: widget.doctors.map<DropdownMenuItem<String>>((doc) {
                    final dName = (doc['full_name'] ?? 'Doctor').toString();
                    final spec = (doc['speciality'] ?? '').toString();
                    final fee = ((doc['consultation_fee'] ?? 0) as num).toDouble();
                    return DropdownMenuItem<String>(
                      value: dName,
                      child: Text(
                        'Dr. $dName (${spec.isNotEmpty ? spec : 'General'} - ${CurrencyService.symbol}$fee)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: _onDoctorSelected,
                ),
                const SizedBox(height: 10),
              ],

              // Patient Info
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Patient Full Name *',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MALE', child: Text('Male')),
                        DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _gender = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Date & Time Picker
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(DateFormat('dd MMM yyyy').format(_date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final currentDoc = widget.doctors.firstWhere(
                          (d) => (d['full_name'] ?? '').toString() == _doctorName || d['id'] == _doctorId,
                          orElse: () => null,
                        );
                        final now = DateTime.now();
                        final firstDate = DateTime(now.year, now.month, now.day);
                        final lastDate = firstDate.add(const Duration(days: 90));

                        DateTime initial = _date;
                        if (initial.isBefore(firstDate) || (currentDoc != null && !_isDoctorAvailableOn(initial, currentDoc))) {
                          initial = _findNextAvailableDate(firstDate, currentDoc);
                        }
                        if (initial.isAfter(lastDate)) initial = lastDate;

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: firstDate,
                          lastDate: lastDate,
                          selectableDayPredicate: (DateTime day) {
                            if (currentDoc == null) return true;
                            return _isDoctorAvailableOn(day, currentDoc);
                          },
                          helpText: 'Select Available OPD Date',
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text(_time.format(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                    ),
                  ),
                ],
              ),
              // Doctor Available Days & Working Schedule Check
              Builder(
                builder: (ctx) {
                  final selDoc = widget.doctors.firstWhere(
                    (d) => (d['full_name'] ?? '').toString() == _doctorName,
                    orElse: () => null,
                  );
                  final availableDaysRaw = (selDoc?['available_days'] ?? selDoc?['public_display_options']?['available_days'] ?? 'Mon,Tue,Wed,Thu,Fri,Sat').toString();
                  final availableList = availableDaysRaw.split(',').map((x) => x.trim().toUpperCase()).where((x) => x.isNotEmpty).toList();
                  final selDayEee = DateFormat('EEE').format(_date).toUpperCase();
                  final isDayAvailable = availableList.isEmpty || availableList.contains(selDayEee);

                  final startTime = (selDoc?['public_display_options']?['start_time'] ?? '09:00 AM').toString();
                  final endTime = (selDoc?['public_display_options']?['end_time'] ?? '06:00 PM').toString();

                  if (!isDayAvailable) {
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dr. ' + _doctorName + ' is not scheduled on ' + DateFormat('EEEE').format(_date) + ' (Available: ' + availableDaysRaw + ' | ' + startTime + ' - ' + endTime + ')',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Doctor Hours: ' + availableDaysRaw + ' (' + startTime + ' - ' + endTime + ')',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Fee & Payment Option Selection
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        const Text('Consultation Fee & Payment Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                        const Spacer(),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _feeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Fee (${CurrencyService.symbol})',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Pay Later'),
                          selected: _paymentOption == 'PAY_LATER',
                          onSelected: (val) => setState(() => _paymentOption = 'PAY_LATER'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Paid Now'),
                          selected: _paymentOption == 'PAID_NOW',
                          onSelected: (val) => setState(() => _paymentOption = 'PAID_NOW'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Therapy Package'),
                          selected: _paymentOption == 'PACKAGE',
                          onSelected: (val) => setState(() => _paymentOption = 'PACKAGE'),
                        ),
                      ],
                    ),

                    if (_paymentOption == 'PAID_NOW') ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Universal Mode: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: (_masterPaymentMethods.isNotEmpty
                                    ? _masterPaymentMethods.map((m) => (m['name'] ?? 'CASH').toString().toUpperCase()).toList()
                                    : ['CASH', 'CARD', 'UPI', 'BANK_TRANSFER']).map((m) {
                                  final sel = _paymentMode.toUpperCase() == m.toUpperCase();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(m, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                                      selected: sel,
                                      selectedColor: const Color(0xFF0284C7).withOpacity(0.2),
                                      onSelected: (v) => setState(() => _paymentMode = m),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
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

              const SizedBox(height: 10),
              TextField(
                controller: _reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason for Visit / Symptoms',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Booking'),
        ),
      ],
    );
  }
}

// ==========================================
// THERAPY & SUBSCRIPTION FINANCIAL LEDGER DIALOG
// ==========================================
class _SubscriptionLedgerDialog extends StatefulWidget {
  final dynamic subscription;

  const _SubscriptionLedgerDialog({required this.subscription});

  @override
  State<_SubscriptionLedgerDialog> createState() => _SubscriptionLedgerDialogState();
}

class _SubscriptionLedgerDialogState extends State<_SubscriptionLedgerDialog> {
  bool _isLoading = true;
  Map<String, dynamic>? _ledgerData;

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get(
        ApiEndpoints.clinicSubscriptionLedger(widget.subscription['id']),
      );
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _ledgerData = Map<String, dynamic>.from(res['data'] ?? {});
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _consumeQuickSession() async {
    try {
      final res = await ApiClient.post(
        ApiEndpoints.clinicSubscriptionConsume(widget.subscription['id']),
        {'notes': 'Session deducted from Ledger Statement'},
      );
      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(res['message'] ?? 'Session consumed successfully!'),
          ),
        );
        _fetchLedger();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inr = CurrencyService.currencyFormat;
    final sub = _ledgerData?['subscription'] ?? widget.subscription;
    final totalSessions = int.tryParse('${_ledgerData?['total_package_sessions'] ?? sub['total_package_sessions']}') ?? 6;
    final consumed = int.tryParse('${_ledgerData?['services_consumed'] ?? sub['services_consumed']}') ?? 0;
    final remaining = (totalSessions - consumed).clamp(0, totalSessions);
    final totalCollected = double.tryParse('${_ledgerData?['total_collected'] ?? sub['total_payment_amount']}') ?? 0.0;
    final remainingVal = double.tryParse('${_ledgerData?['remaining_value']}') ?? 0.0;
    final ledgerEntries = (_ledgerData?['ledger'] as List?) ?? [];

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF7C3AED), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sub['customer_name'] ?? 'Customer',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'Package #${sub['id']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phone: ${sub['customer_phone'] ?? '-'}  •  Package: ${sub['item_name'] ?? 'Therapy'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Summary Metric Badges
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _ledgerMetric('Total Collected', inr.format(totalCollected), const Color(0xFF059669)),
                  _verticalDivider(),
                  _ledgerMetric('Package Sessions', '$totalSessions Total', const Color(0xFF0F172A)),
                  _verticalDivider(),
                  _ledgerMetric('Consumed Sessions', '$consumed Done', const Color(0xFFD97706)),
                  _verticalDivider(),
                  _ledgerMetric('Remaining Sessions', '$remaining Left', const Color(0xFF7C3AED)),
                  _verticalDivider(),
                  _ledgerMetric('Remaining Value', inr.format(remainingVal), const Color(0xFF0284C7)),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'FINANCIAL LEDGER & TRANSACTION HISTORY',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            // Ledger Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                  : ledgerEntries.isEmpty
                      ? const Center(child: Text('No transactions recorded yet.', style: TextStyle(color: Colors.grey)))
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ListView.separated(
                              itemCount: ledgerEntries.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (ctx, idx) {
                                final row = ledgerEntries[idx];
                                final isCredit = row['type'] == 'CREDIT';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
                                  child: Row(
                                    children: [
                                      // Date
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          (row['date'] ?? '').toString().substring(0, 10),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Type chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isCredit ? const Color(0xFF059669).withValues(alpha: 0.1) : const Color(0xFFD97706).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          row['type'] ?? '',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isCredit ? const Color(0xFF059669) : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Description
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              row['description'] ?? '',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            ),
                                            Text(
                                              'Ref: ${row['reference'] ?? '-'}',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Amount
                                      Text(
                                        '${isCredit ? '+' : '-'}${inr.format(double.tryParse('${row['amount']}') ?? 0.0)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      // Balance
                                      SizedBox(
                                        width: 120,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Bal: ${inr.format(double.tryParse('${row['balance_amount']}') ?? 0.0)}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            ),
                                            Text(
                                              '${row['remaining_sessions'] ?? 0} sessions left',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),

            const SizedBox(height: 16),

            // Footer Actions
            Row(
              children: [
                if (remaining > 0)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text('Deduct Next Session (#${consumed + 1})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _consumeQuickSession,
                  ),
                const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ledgerMetric(String title, String val, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE2E8F0),
    );
  }
}

// ==========================================
// CREATE NEW THERAPY SUBSCRIPTION DIALOG
// ==========================================
class _CreateSubscriptionDialog extends StatefulWidget {
  final String? initialName;
  final String? initialPhone;
  final VoidCallback onCreated;

  const _CreateSubscriptionDialog({
    this.initialName,
    this.initialPhone,
    required this.onCreated,
  });

  @override
  State<_CreateSubscriptionDialog> createState() => _CreateSubscriptionDialogState();
}

class _CreateSubscriptionDialogState extends State<_CreateSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _emailCtrl = TextEditingController();
  final _sessionsCtrl = TextEditingController(text: '6');
  final _bonusCtrl = TextEditingController(text: '1');
  final _totalFeeCtrl = TextEditingController(text: '3000');

  String _paymentMode = 'CASH';
  List<dynamic> _availableItems = [];
  dynamic _selectedItem;
  bool _isLoadingItems = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _masterPaymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
    _loadItems();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoadingPaymentMethods = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.paymentMethods);
      if (res != null && res['data'] is List && mounted) {
        final list = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() {
          _masterPaymentMethods = list;
          if (_masterPaymentMethods.isNotEmpty && !_masterPaymentMethods.any((m) => (m['name'] ?? '').toString().toUpperCase() == _paymentMode)) {
            _paymentMode = (_masterPaymentMethods.first['name'] ?? 'CASH').toString().toUpperCase();
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingPaymentMethods = false);
    }
  }

  Future<void> _loadItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicMedicines);
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _availableItems = res['data'] ?? [];
          if (_availableItems.isNotEmpty) {
            _selectedItem = _availableItems.first;
            _recalculateFee();
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  void _recalculateFee() {
    if (_selectedItem != null) {
      final rate = double.tryParse('${_selectedItem['retail_sale_price'] ?? _selectedItem['rate'] ?? 500}') ?? 500.0;
      final sessions = int.tryParse(_sessionsCtrl.text) ?? 6;
      _totalFeeCtrl.text = (rate * sessions).toStringAsFixed(2);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final body = {
        'customer_name': _nameCtrl.text.trim(),
        'customer_phone': _phoneCtrl.text.trim(),
        'customer_email': _emailCtrl.text.trim(),
        'item_id': _selectedItem?['id'] ?? 0,
        'item_name': _selectedItem?['item_name'] ?? 'Therapy Package',
        'monthly_sessions': int.tryParse(_sessionsCtrl.text) ?? 6,
        'bonus_sessions': int.tryParse(_bonusCtrl.text) ?? 0,
        'total_fee': double.tryParse(_totalFeeCtrl.text) ?? 0.0,
        'payment_mode': _paymentMode,
      };

      final res = await ApiClient.post(ApiEndpoints.clinicSubscriptions, body);
      if (res != null && res['success'] == true && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF059669),
            content: Text('Therapy Package Subscription created and recorded in Finance Ledger!'),
          ),
        );
        widget.onCreated();
      } else if (res != null && res['message'] != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(res['message'])),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error creating subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.card_membership_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Therapy / Service Subscription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Subscribe patient for recurring sessions, track consumption & credit advance.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Customer Details
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Patient Name *', prefixIcon: Icon(Icons.person_outline, size: 18), isDense: true, border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone_outlined, size: 18), isDense: true, border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Service Item Selection from Item Master
              _isLoadingItems
                  ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Color(0xFF7C3AED))))
                  : DropdownButtonFormField<dynamic>(
                      value: _selectedItem,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Service / Therapy from Item Master *',
                        prefixIcon: Icon(Icons.medical_services_outlined, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _availableItems.map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item['item_name']} (Stock: ${item['current_stock'] ?? 0}) - Rate: ₹${item['retail_sale_price'] ?? item['rate'] ?? 0}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedItem = val;
                          _recalculateFee();
                        });
                      },
                    ),

              const SizedBox(height: 12),

              // Monthly Sessions and Bonus
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sessionsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Monthly Sessions Needed', helperText: 'e.g. 6 sessions/month', isDense: true, border: OutlineInputBorder()),
                      onChanged: (_) => _recalculateFee(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _bonusCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Free Bonus Sessions', helperText: 'e.g. 1 bonus = 7 total', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Total Package Fee & Payment Mode
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalFeeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Total Package Fee (₹)', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Payment Mode', isDense: true, border: OutlineInputBorder()),
                      items: [
                        ..._masterPaymentMethods.map((m) {
                          final code = (m['name'] ?? 'CASH').toString().toUpperCase();
                          final label = (m['name'] ?? 'Cash').toString();
                          return DropdownMenuItem(value: code, child: Text(label, overflow: TextOverflow.ellipsis));
                        }),
                        if (_masterPaymentMethods.isEmpty) ...const [
                          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                          DropdownMenuItem(value: 'CARD', child: Text('Credit / Debit Card')),
                          DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                        ],
                        const DropdownMenuItem(value: 'PAY_LATER', child: Text('Pay Later (Customer Credit)', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _paymentMode = v);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Create & Record Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

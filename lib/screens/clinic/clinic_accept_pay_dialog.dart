import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

class ClinicAcceptPayDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onAccepted;
  final List<dynamic>? doctors;

  const ClinicAcceptPayDialog({
    super.key,
    required this.appointment,
    required this.onAccepted,
    this.doctors,
  });

  @override
  State<ClinicAcceptPayDialog> createState() => _ClinicAcceptPayDialogState();
}

class _ClinicAcceptPayDialogState extends State<ClinicAcceptPayDialog> {
  String _paymentOption = 'PAID_NOW'; // 'PAID_NOW', 'PAY_LATER', 'PACKAGE', 'ALREADY_PAID'
  String _paymentMode = 'CASH'; // Dynamically synced with universal methods
  late TextEditingController _amountCtrl;

  // Universal Payment Methods
  List<Map<String, dynamic>> _masterPaymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  // Doctor assignment
  List<dynamic> _doctors = [];
  String? _selectedDoctorName;
  int? _selectedDoctorId;
  bool _isLoadingDoctors = false;

  // Package sessions
  final _packageNameCtrl = TextEditingController(text: 'Therapy & Rehabilitation (6 Sessions)');
  int _sessionNumber = 1;
  int _totalSessions = 6;

  // Customer Credit / Ledger tracking
  double _customerPendingCredit = 0.0;
  List<dynamic> _unpaidBills = [];
  bool _isLoadingCredit = false;
  bool _settlePriorCreditWithToday = false;

  bool _isSubmitting = false;
  bool get _isPrepaid => (widget.appointment['payment_status'] ?? '').toString().toUpperCase() == 'PAID';

  void _syncFeeWithDoctor(dynamic doc) {
    if (doc != null && doc['consultation_fee'] != null) {
      final docFee = double.tryParse('${doc['consultation_fee']}') ?? 0.0;
      if (docFee > 0) {
        _amountCtrl.text = NumberFormat('#,##0.00').format(docFee);
      }
    }
  }

  dynamic _findMatchedDoctor(List<dynamic> list, String? name, int? id) {
    if (list.isEmpty) return null;
    if (id != null) {
      final byId = list.firstWhere((d) => d['id'] == id, orElse: () => null);
      if (byId != null) return byId;
    }
    if (name != null && name.trim().isNotEmpty) {
      final clean = name.replaceAll(RegExp(r'^Dr\.?\s+', caseSensitive: false), '').trim().toLowerCase();
      final byName = list.firstWhere((d) {
        final dName = (d['full_name'] ?? d['username'] ?? '').toString().replaceAll(RegExp(r'^Dr\.?\s+', caseSensitive: false), '').trim().toLowerCase();
        return dName == clean;
      }, orElse: () => null);
      if (byName != null) return byName;
    }
    return list.first;
  }

  @override
  void initState() {
    super.initState();
    final fee = NumberFormat('#,##0.00').format(
      widget.appointment['consultation_fee'] is num
          ? (widget.appointment['consultation_fee'] as num).toDouble()
          : (double.tryParse('${widget.appointment['consultation_fee']}') ?? 50.0),
    );
    _amountCtrl = TextEditingController(text: fee);

    _selectedDoctorName = widget.appointment['doctor_name'];
    _selectedDoctorId = widget.appointment['doctor_id'] != null
        ? int.tryParse('${widget.appointment['doctor_id']}')
        : null;

    final isPackageSession = widget.appointment['is_package_session'] == true ||
        (widget.appointment['payment_status'] ?? '').toString().toUpperCase() == 'PACKAGE_INCLUDED' ||
        (widget.appointment['payment_mode'] ?? '').toString().toUpperCase() == 'PACKAGE_SUBSCRIPTION';

    if (_isPrepaid) {
      _paymentOption = 'ALREADY_PAID';
    } else if (isPackageSession) {
      _paymentOption = 'PACKAGE';
    } else {
      _paymentOption = 'PAID_NOW'; // Default is always Pay Now (Direct)
    }

    if (widget.appointment['active_subscription'] != null) {
      final sub = widget.appointment['active_subscription'];
      _packageNameCtrl.text = (sub['package_name'] ?? 'Therapy Package').toString();
      _sessionNumber = (int.tryParse('${sub['services_consumed']}') ?? 0) + 1;
      _totalSessions = int.tryParse('${sub['total_sessions']}') ?? 6;
    } else if (widget.appointment['package_name'] != null) {
      _packageNameCtrl.text = widget.appointment['package_name'];
      _sessionNumber = (widget.appointment['session_number'] ?? 0) + 1;
      _totalSessions = widget.appointment['total_package_sessions'] ?? 6;
    }

    if (widget.doctors != null && widget.doctors!.isNotEmpty) {
      _doctors = List.from(widget.doctors!);
      final matched = _findMatchedDoctor(_doctors, _selectedDoctorName, _selectedDoctorId);
      if (matched != null) {
        _selectedDoctorName = (matched['full_name'] ?? matched['username'] ?? _selectedDoctorName).toString();
        _selectedDoctorId = matched['id'] != null ? int.tryParse('${matched['id']}') : _selectedDoctorId;
        _syncFeeWithDoctor(matched);
      }
    } else {
      _fetchDoctors();
    }

    _loadMasterPaymentMethods();
    _fetchCustomerCredit();
  }

  Future<void> _fetchCustomerCredit() async {
    final phone = (widget.appointment['patient_phone'] ?? '').toString().trim();
    final name = (widget.appointment['patient_name'] ?? '').toString().trim();
    if (phone.isEmpty && name.isEmpty) return;

    setState(() => _isLoadingCredit = true);
    try {
      final res = await ApiClient.get(
        ApiEndpoints.clinicPatientCredit,
        queryParams: {'phone': phone, 'name': name},
      );
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _customerPendingCredit = double.tryParse('${res['total_credit_due']}') ?? 0.0;
          _unpaidBills = res['unpaid_bills'] is List ? (res['unpaid_bills'] as List) : [];
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoadingCredit = false);
    }
  }

  Future<void> _loadMasterPaymentMethods() async {
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
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoadingPaymentMethods = false);
    }
  }

  Future<void> _fetchDoctors() async {
    setState(() => _isLoadingDoctors = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.clinicDoctors);
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _doctors = res['data'] is List ? (res['data'] as List) : [];
          final matched = _findMatchedDoctor(_doctors, _selectedDoctorName, _selectedDoctorId);
          if (matched != null) {
            _selectedDoctorName = (matched['full_name'] ?? matched['username'] ?? _selectedDoctorName).toString();
            _selectedDoctorId = matched['id'] != null ? int.tryParse('${matched['id']}') : _selectedDoctorId;
            _syncFeeWithDoctor(matched);
          }
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoadingDoctors = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _packageNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final apptId = widget.appointment['id'];
      final feeAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

      final payload = <String, dynamic>{
        'payment_status': _isPrepaid
            ? 'PAID'
            : (_paymentOption == 'PACKAGE'
                ? 'PACKAGE_INCLUDED'
                : (_paymentOption == 'PAID_NOW' ? 'PAID' : 'PAY_LATER')),
        'payment_mode': _isPrepaid
            ? (widget.appointment['payment_mode'] ?? 'PREPAID')
            : (_paymentOption == 'PACKAGE'
                ? 'PACKAGE'
                : (_paymentOption == 'PAID_NOW' ? _paymentMode : 'PAY_AT_CLINIC')),
        'paid_amount': _isPrepaid
            ? (double.tryParse('${widget.appointment['paid_amount']}') ?? feeAmount)
            : (_paymentOption == 'PACKAGE' ? 0.0 : (_paymentOption == 'PAID_NOW' ? feeAmount : 0.0)),
        'settle_prior_credit': _paymentOption == 'PAID_NOW' && _settlePriorCreditWithToday,
      };

      if (_selectedDoctorName != null && _selectedDoctorName!.isNotEmpty) {
        payload['doctor_name'] = _selectedDoctorName;
        if (_selectedDoctorId != null) payload['doctor_id'] = _selectedDoctorId;
      }

      if (_paymentOption == 'PACKAGE') {
        payload['package_name'] = _packageNameCtrl.text.trim();
        payload['session_number'] = _sessionNumber;
        payload['total_package_sessions'] = _totalSessions;
        payload['is_package_session'] = _sessionNumber <= _totalSessions;
      }

      final res = await ApiClient.post(
        ApiEndpoints.clinicAppointmentAcceptAndPay(apptId),
        payload,
      );

      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message'] ?? 'Appointment accepted successfully!')),
              ],
            ),
          ),
        );
        widget.onAccepted();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept appointment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientName = widget.appointment['patient_name'] ?? 'Patient';
    final tokenNo = widget.appointment['token_number'] ?? widget.appointment['id'] ?? '-';
    final isPackageSessionFree = _sessionNumber <= _totalSessions;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0284C7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.appointment['status'] == 'VISITED'
                            ? 'Reception Fee Collection & Details'
                            : 'Reception Acceptance & Admission',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Daily Token #$tokenNo',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Patient: $patientName  •  Phone: ${widget.appointment['patient_phone'] ?? '-'}',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
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
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Assignment Section
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
                    const Row(
                      children: [
                        Icon(Icons.medical_services_rounded, size: 16, color: Color(0xFF0284C7)),
                        SizedBox(width: 6),
                        Text('Assigned Attending Doctor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isLoadingDoctors
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String>(
                            value: _doctors.any((d) => (d['full_name'] ?? '').toString() == _selectedDoctorName)
                                ? _selectedDoctorName
                                : (_doctors.isNotEmpty ? (_doctors.first['full_name'] ?? '').toString() : null),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: _doctors.map<DropdownMenuItem<String>>((doc) {
                              final name = (doc['full_name'] ?? 'Doctor').toString();
                              final spec = (doc['speciality'] ?? '').toString();
                              final docFee = doc['consultation_fee'] != null ? '${CurrencyService.symbol}${doc['consultation_fee']}' : '';
                              return DropdownMenuItem(
                                value: name,
                                child: Text(
                                  spec.isNotEmpty ? 'Dr. $name ($spec) - $docFee' : 'Dr. $name - $docFee',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final matched = _findMatchedDoctor(_doctors, val, null);
                                setState(() {
                                  _selectedDoctorName = val;
                                  _selectedDoctorId = matched != null ? int.tryParse('${matched['id']}') : null;
                                  if (matched != null) {
                                    _syncFeeWithDoctor(matched);
                                  }
                                });
                              }
                            },
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // If already prepaid online
              if (_isPrepaid) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Prepaid Online / Advance Paid',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Consultation fee of ${CurrencyService.symbol}${widget.appointment['paid_amount'] ?? widget.appointment['consultation_fee'] ?? '0.00'} has been successfully paid via ${widget.appointment['payment_mode'] ?? 'Online Gateway'} and logged to Universal Cash Ledger.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (_customerPendingCredit > 0) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Customer Credit Alert: Prior Dues Pending',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Credit Due: ${CurrencyService.format(_customerPendingCredit)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This patient has ${_unpaidBills.length} unpaid bill(s)/visit(s) totaling ${CurrencyService.format(_customerPendingCredit)} in outstanding customer credit.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                ],

                // Payment Option Selection Tabs
                const Text('Select Payment & Consultation Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 10),

                Row(
                  children: [
                    _modeCard(
                      title: 'Pay Now (Direct)',
                      subtitle: 'Universal Payment Modes',
                      icon: Icons.payments_rounded,
                      selected: _paymentOption == 'PAID_NOW',
                      color: const Color(0xFF059669),
                      onTap: () => setState(() => _paymentOption = 'PAID_NOW'),
                    ),
                    const SizedBox(width: 8),
                    _modeCard(
                      title: 'Pay Later',
                      subtitle: 'Add to Customer Credit',
                      icon: Icons.schedule_rounded,
                      selected: _paymentOption == 'PAY_LATER',
                      color: const Color(0xFFD97706),
                      onTap: () => setState(() => _paymentOption = 'PAY_LATER'),
                    ),
                    const SizedBox(width: 8),
                    _modeCard(
                      title: 'Service Package',
                      subtitle: 'Therapy Sessions Pack',
                      icon: Icons.card_giftcard_rounded,
                      selected: _paymentOption == 'PACKAGE',
                      color: const Color(0xFF7C3AED),
                      onTap: () => setState(() => _paymentOption = 'PACKAGE'),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Option 1: Pay Now Controls
                if (_paymentOption == 'PAID_NOW') ...[
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
                            Expanded(
                              child: TextField(
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Consultation Fee Collected (${CurrencyService.symbol})',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixText: '${CurrencyService.symbol} ',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_customerPendingCredit > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _settlePriorCreditWithToday ? const Color(0xFFEFF6FF) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _settlePriorCreditWithToday ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1)),
                            ),
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: _settlePriorCreditWithToday,
                              activeColor: const Color(0xFF2563EB),
                              title: Text(
                                'Bulk Pay / Also Settle Prior Credit (${CurrencyService.format(_customerPendingCredit)})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                              ),
                              subtitle: Text(
                                _settlePriorCreditWithToday
                                    ? 'Clears today\'s fee + past outstanding credit dues in Universal Cash Ledger & Customer Ledger.'
                                    : 'Check to collect today\'s fee and settle all past credit dues together.',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                              ),
                              onChanged: (val) {
                                final isCheck = val ?? false;
                                setState(() {
                                  _settlePriorCreditWithToday = isCheck;
                                  final baseFee = double.tryParse('${widget.appointment['consultation_fee'] ?? 0}') ?? 450.0;
                                  if (isCheck) {
                                    _amountCtrl.text = (baseFee + _customerPendingCredit).toStringAsFixed(2);
                                  } else {
                                    _amountCtrl.text = baseFee.toStringAsFixed(2);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text('Universal Payment Method (Recorded in Cash Ledger):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                        const SizedBox(height: 6),
                        _isLoadingPaymentMethods
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: (_masterPaymentMethods.isNotEmpty
                                    ? _masterPaymentMethods.map((m) {
                                        final code = (m['name'] ?? 'CASH').toString().toUpperCase();
                                        final label = (m['name'] ?? 'Cash').toString();
                                        return _payChip(code, label, _getPaymentIcon(code));
                                      }).toList()
                                    : [
                                        _payChip('CASH', 'Cash', Icons.money_rounded),
                                        _payChip('CARD', 'Debit / Credit Card', Icons.credit_card_rounded),
                                        _payChip('UPI', 'UPI / QR Code', Icons.qr_code_2_rounded),
                                        _payChip('BANK_TRANSFER', 'Bank Transfer', Icons.account_balance_rounded),
                                      ]),
                              ),
                      ],
                    ),
                  ),
                ],

                // Option 2: Pay Later Controls
                if (_paymentOption == 'PAY_LATER') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Appointment Accepted on Customer Credit (Pay Later)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Fee (${CurrencyService.symbol}${_amountCtrl.text}) will be recorded in Customer Credit & Universal Cash Ledger.',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Prior Pending Credit Due:', style: TextStyle(fontSize: 12, color: Color(0xFF78350F))),
                            Text(CurrencyService.format(_customerPendingCredit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Today\'s Consultation Fee (Added to Due):', style: TextStyle(fontSize: 12, color: Color(0xFF78350F))),
                            Text('+ ${CurrencyService.symbol}${_amountCtrl.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('New Total Customer Credit Due:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E))),
                            Text(
                              CurrencyService.format(_customerPendingCredit + (double.tryParse(_amountCtrl.text.trim()) ?? 0.0)),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Option 3: Service Package / Therapy Subscription Controls
                if (_paymentOption == 'PACKAGE') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.spa_rounded, color: Color(0xFF7C3AED), size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Therapy Package / Subscription Session',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF581C87)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPackageSessionFree ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPackageSessionFree ? 'FREE (Covered)' : 'PAID OVERAGE',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _packageNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Package / Therapy Name',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _sessionNumber,
                                decoration: InputDecoration(
                                  labelText: 'Current Session #',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: List.generate(12, (i) => i + 1).map((num) {
                                  return DropdownMenuItem(value: num, child: Text('Session $num'));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _sessionNumber = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _totalSessions,
                                decoration: InputDecoration(
                                  labelText: 'Total Free Sessions',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: [3, 5, 6, 10, 12].map((num) {
                                  return DropdownMenuItem(value: num, child: Text('$num Sessions'));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _totalSessions = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPackageSessionFree
                              ? '✓ Session $_sessionNumber of $_totalSessions is covered under the patient package. Fee is €0.00.'
                              : '⚠️ Session $_sessionNumber exceeds package quota ($_totalSessions free sessions). This visit will be billed standard.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPackageSessionFree ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded, size: 18),
          label: Text(
            _isSubmitting
                ? 'Processing...'
                : (_isPrepaid
                    ? (widget.appointment['status'] == 'VISITED' ? 'Update & Confirm (Token #$tokenNo)' : 'Confirm & Admit to Queue (Token #$tokenNo)')
                    : (_paymentOption == 'PAID_NOW'
                        ? (widget.appointment['status'] == 'VISITED'
                            ? 'Collect ${CurrencyService.symbol}${_amountCtrl.text} & Update Receipt'
                            : 'Collect ${CurrencyService.symbol}${_amountCtrl.text} & Admit (Token #$tokenNo)')
                        : (_paymentOption == 'PACKAGE'
                            ? 'Confirm Package Session (Token #$tokenNo)'
                            : (widget.appointment['status'] == 'VISITED'
                                ? 'Update Credit Dues'
                                : 'Accept on Credit (Pay Later) (Token #$tokenNo)')))),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Widget _modeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : const Color(0xFF64748B), size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? color : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    final m = method.toUpperCase();
    if (m.contains('UPI') || m.contains('QR') || m.contains('SCAN')) return Icons.qr_code_2_rounded;
    if (m.contains('CARD') || m.contains('DEBIT') || m.contains('CREDIT')) return Icons.credit_card_rounded;
    if (m.contains('BANK') || m.contains('TRANSFER') || m.contains('NEFT') || m.contains('RTGS')) return Icons.account_balance_rounded;
    if (m.contains('CHEQUE') || m.contains('CHECK')) return Icons.receipt_long_rounded;
    if (m.contains('WALLET')) return Icons.account_balance_wallet_rounded;
    return Icons.money_rounded;
  }

  Widget _payChip(String code, String label, IconData icon) {
    final sel = _paymentMode == code;
    return ChoiceChip(
      selected: sel,
      avatar: Icon(icon, size: 16, color: sel ? Colors.white : const Color(0xFF059669)),
      label: Text(label),
      selectedColor: const Color(0xFF059669),
      labelStyle: TextStyle(
        color: sel ? Colors.white : const Color(0xFF0F172A),
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      onSelected: (val) {
        if (val) setState(() => _paymentMode = code);
      },
    );
  }
}

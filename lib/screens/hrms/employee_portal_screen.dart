import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';
// import currency service

class EmployeePortalScreen extends StatefulWidget {
  const EmployeePortalScreen({Key? key}) : super(key: key);

  @override
  State<EmployeePortalScreen> createState() => _EmployeePortalScreenState();
}

class _EmployeePortalScreenState extends State<EmployeePortalScreen> {
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;
  String? _employeeToken;

  // Login Form Controllers
  final TextEditingController _loginIdCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  // Employee Data
  Map<String, dynamic>? _employeeData;
  Map<String, dynamic>? _officeData;
  Map<String, dynamic>? _shiftData;
  Map<String, dynamic>? _todayAttendance;
  List<dynamic> _leaveBalances = [];
  List<dynamic> _myLeaves = [];
  Map<String, dynamic> _stats = {};
  List<dynamic> _recentPunches = [];
  List<dynamic> _loans = [];
  List<dynamic> _salaryRevisions = [];
  List<dynamic> _salarySlips = [];
  Map<String, dynamic>? _payStructure;
  String? _boundDeviceId;
  String? _boundDeviceInfo;
  int _selectedNavIndex = 0;

  // GPS Location State
  Position? _currentPosition;
  double? _distanceFromOffice;
  bool _isFetchingGps = false;
  String? _gpsError;

  // Punch Action State
  bool _isPunching = false;

  static const Color primaryNavy = Color(0xFF1E293B);
  static const Color accentIndigo = Color(0xFF4F46E5);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color bgGrey = Color(0xFFF8FAFC);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  @override
  void dispose() {
    _loginIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSavedLogin() async {
    setState(() => _isCheckingAuth = true);
    try {
      final token = await TokenStorage.read();
      if (token != null && token.isNotEmpty) {
        // Attempt to fetch profile with existing session or portal token
        final res = await ApiClient.get(ApiEndpoints.hrmsEmployeeProfile, silent: true);
        if (res != null && res['success'] == true && res['employee'] != null) {
          if (mounted) {
            setState(() {
              _isLoggedIn = true;
              _employeeData = res['employee'];
              _officeData = res['office'] ?? res['employee']?['office'];
              _shiftData = res['shift'] ?? res['employee']?['shift'];
              _todayAttendance = res['today_attendance'] ?? res['today_punch'];
              _leaveBalances = res['leave_balances'] ?? [];
              _myLeaves = res['my_leaves'] ?? [];
              _stats = res['stats'] ?? res['month_stats'] ?? {};
              _recentPunches = res['recent_punches'] ?? [];
              _loans = res['loans'] ?? [];
              _salaryRevisions = res['salary_revisions'] ?? [];
              _salarySlips = res['salary_slips'] ?? [];
              _payStructure = res['pay_structure'];
              _boundDeviceId = res['bound_device_id'] ?? res['employee']?['bound_device_id'];
              _boundDeviceInfo = res['bound_device_info'] ?? res['employee']?['bound_device_info'];
              _isCheckingAuth = false;
            });
            _refreshCurrentGps();
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isCheckingAuth = false);
    }
  }

  Future<void> _doLogin() async {
    final loginId = _loginIdCtrl.text.trim();
    final pwd = _passwordCtrl.text.trim();
    if (loginId.isEmpty || pwd.isEmpty) {
      _showToast('Please enter Employee Code/Email and Password', isError: true);
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      final res = await ApiClient.post(ApiEndpoints.hrmsEmployeeLogin, {
        'login': loginId,
        'username': loginId,
        'email': loginId,
        'employee_code': loginId,
        'password': pwd,
      });

      setState(() => _isLoggingIn = false);

      if (res != null && res['success'] == true && res['token'] != null) {
        // Save the portal token
        _employeeToken = res['token'];
        await TokenStorage.save(_employeeToken!);

        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _employeeData = res['employee'];
            _officeData = res['office'] ?? res['employee']?['office'];
            _shiftData = res['shift'] ?? res['employee']?['shift'];
          });
          _loadProfileData();
          _refreshCurrentGps();
        }
      } else {
        final msg = res?['message'] ?? 'Invalid login credentials';
        _showToast(msg.toString(), isError: true);
      }
    } catch (e) {
      setState(() => _isLoggingIn = false);
      _showToast('Login failed: $e', isError: true);
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.hrmsEmployeeProfile, silent: true);
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _employeeData = res['employee'] ?? _employeeData;
          _officeData = res['office'] ?? res['employee']?['office'] ?? _officeData;
          _shiftData = res['shift'] ?? res['employee']?['shift'] ?? _shiftData;
          _todayAttendance = res['today_attendance'] ?? res['today_punch'];
          _leaveBalances = res['leave_balances'] ?? [];
          _myLeaves = res['my_leaves'] ?? [];
          _stats = res['stats'] ?? res['month_stats'] ?? {};
          _recentPunches = res['recent_punches'] ?? [];
          _loans = res['loans'] ?? [];
          _salaryRevisions = res['salary_revisions'] ?? [];
          _salarySlips = res['salary_slips'] ?? [];
          _payStructure = res['pay_structure'];
          _boundDeviceId = res['bound_device_id'] ?? res['employee']?['bound_device_id'];
          _boundDeviceInfo = res['bound_device_info'] ?? res['employee']?['bound_device_info'];
        });
        _calculateDistance();
      }
    } catch (_) {}
  }

  Future<void> _refreshCurrentGps() async {
    if (!mounted) return;
    setState(() {
      _isFetchingGps = true;
      _gpsError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _gpsError = 'Location services disabled. Please enable GPS on your device.';
          _isFetchingGps = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _gpsError = 'Location permission denied. Cannot verify attendance geotag.';
            _isFetchingGps = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsError = 'Location permissions permanently denied in App Settings.';
          _isFetchingGps = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _isFetchingGps = false;
        });
        _calculateDistance();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsError = 'Failed to acquire GPS: $e';
          _isFetchingGps = false;
        });
      }
    }
  }

  void _calculateDistance() {
    if (_currentPosition == null || _officeData == null) return;
    final offLat = double.tryParse(_officeData!['latitude']?.toString() ?? '');
    final offLng = double.tryParse(_officeData!['longitude']?.toString() ?? '');
    if (offLat == null || offLng == null) return;

    final dist = _haversineMeters(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      offLat,
      offLng,
    );

    setState(() {
      _distanceFromOffice = dist;
    });
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // meters
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static Future<String> _getDeviceFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('lynx_emp_device_uuid');
    if (id == null || id.isEmpty) {
      final randPart = (Random().nextInt(900000) + 100000).toString();
      id = 'DEV-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}-$randPart';
      await prefs.setString('lynx_emp_device_uuid', id);
    }
    return id;
  }

  static String _getDeviceInfo() {
    try {
      return '${Platform.operatingSystem.toUpperCase()} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'Mobile App Device';
    }
  }

  Future<void> _markPunch(String punchType) async {
    if (_currentPosition == null) {
      await _refreshCurrentGps();
      if (_currentPosition == null) {
        _showToast('GPS position unavailable. Please enable location & retry.', isError: true);
        return;
      }
    }

    setState(() => _isPunching = true);
    try {
      final devId = await _getDeviceFingerprint();
      final devInfo = _getDeviceInfo();

      final payload = {
        'type': punchType, // 'IN' or 'OUT'
        'punch_type': punchType,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'device_id': devId,
        'device_info': devInfo,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final res = await ApiClient.post(ApiEndpoints.hrmsEmployeePunch, payload);
      setState(() => _isPunching = false);

      if (res != null && res['success'] == true) {
        final dist = double.tryParse((res['distance_meters'] ?? res['data']?['checkin_distance_meters'])?.toString() ?? '') ?? _distanceFromOffice ?? 0.0;
        final officeName = res['office_name'] ?? _officeData?['office_name'] ?? 'Head Office';
        final isCompliant = res['is_geofence_compliant'] != false && res['data']?['is_geofence_compliant'] != false;
        final lateMins = res['late_arrival_mins'] ?? res['data']?['lateness_mins'] ?? 0;
        final earlyMins = res['early_departure_mins'] ?? res['data']?['early_departure_mins'] ?? 0;
        final otHours = res['overtime_hours'] ?? res['data']?['overtime_hours'] ?? 0;

        _showPunchSuccessDialog(
          punchType: punchType,
          officeName: officeName.toString(),
          distance: dist,
          isCompliant: isCompliant,
          lateMins: lateMins,
          earlyMins: earlyMins,
          otHours: otHours,
        );

        _loadProfileData();
      } else {
        final msg = res?['message'] ?? 'Failed to record attendance punch';
        _showToast(msg.toString(), isError: true);
      }
    } catch (e) {
      setState(() => _isPunching = false);
      _showToast('Error recording punch: $e', isError: true);
    }
  }

  void _showPunchSuccessDialog({
    required String punchType,
    required String officeName,
    required double distance,
    required bool isCompliant,
    required dynamic lateMins,
    required dynamic earlyMins,
    required dynamic otHours,
  }) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCompliant ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCompliant ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: isCompliant ? successGreen : dangerRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Punch $punchType Recorded!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your $punchType attendance has been geotagged and securely recorded.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  children: [
                    _infoRow('Time:', DateFormat('hh:mm:ss a').format(DateTime.now())),
                    _infoRow('Assigned Office:', officeName),
                    _infoRow('Distance from Office:', '${distance.toStringAsFixed(1)} meters'),
                    _infoRow(
                      'Geofence Status:',
                      isCompliant ? 'Compliant (Within Radius)' : 'Out of Bounds Violation',
                      valColor: isCompliant ? successGreen : dangerRed,
                    ),
                    if (punchType == 'IN' && (num.tryParse(lateMins.toString()) ?? 0) > 0)
                      _infoRow('Late Arrival:', '$lateMins mins late', valColor: warningAmber),
                    if (punchType == 'OUT' && (num.tryParse(earlyMins.toString()) ?? 0) > 0)
                      _infoRow('Early Departure:', '$earlyMins mins early', valColor: dangerRed),
                    if (punchType == 'OUT' && (num.tryParse(otHours.toString()) ?? 0) > 0)
                      _infoRow('Overtime Tracked:', '$otHours hrs', valColor: accentIndigo),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accentIndigo),
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('OK, Got It'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final codeOrEmailCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    int step = 1; // 1: Send OTP, 2: Reset Password
    bool isSubmitting = false;
    String? statusMsg;
    bool isError = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: accentIndigo, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                step == 1 ? 'Forgot Password' : 'Enter OTP & Reset',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step == 1) ...[
                    const Text(
                      'Enter your Employee Code or Registered Email address. We will send a 6-digit OTP to your email.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeOrEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Employee Code or Email *',
                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Enter the 6-digit OTP sent to your registered email and choose a new password.',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: '6-Digit OTP *',
                        prefixIcon: Icon(Icons.password_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password *',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password *',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  if (statusMsg != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusMsg!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isError ? dangerRed : successGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accentIndigo),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (step == 1) {
                        final input = codeOrEmailCtrl.text.trim();
                        if (input.isEmpty) return;
                        setDlgState(() {
                          isSubmitting = true;
                          statusMsg = null;
                        });
                        try {
                          final res = await ApiClient.post(ApiEndpoints.hrmsEmployeeForgotOtp, {
                            'login': input,
                            'email_or_code': input,
                          });
                          setDlgState(() => isSubmitting = false);
                          if (res != null && res['success'] == true) {
                            setDlgState(() {
                              step = 2;
                              otpCtrl.clear();
                              statusMsg = res['message'] ?? 'OTP sent to your email. Please check your inbox.';
                              isError = false;
                            });
                          } else {
                            setDlgState(() {
                              statusMsg = res?['message'] ?? 'Failed to send OTP';
                              isError = true;
                            });
                          }
                        } catch (err) {
                          setDlgState(() {
                            isSubmitting = false;
                            statusMsg = 'Error: $err';
                            isError = true;
                          });
                        }
                      } else {
                        // Step 2: Reset
                        final otp = otpCtrl.text.trim();
                        final newP = newPassCtrl.text.trim();
                        final confP = confirmPassCtrl.text.trim();
                        if (otp.length != 6 || newP.isEmpty) return;
                        if (newP != confP) {
                          setDlgState(() {
                            statusMsg = 'Passwords do not match';
                            isError = true;
                          });
                          return;
                        }
                        setDlgState(() {
                          isSubmitting = true;
                          statusMsg = null;
                        });
                        try {
                          final res = await ApiClient.post(ApiEndpoints.hrmsEmployeeResetPassword, {
                            'login': codeOrEmailCtrl.text.trim(),
                            'email_or_code': codeOrEmailCtrl.text.trim(),
                            'otp': otp,
                            'new_password': newP,
                          });
                          setDlgState(() => isSubmitting = false);
                          if (res != null && res['success'] == true) {
                            Navigator.pop(dlgCtx);
                            _showToast('Password reset successfully! Please login with your new password.');
                            _loginIdCtrl.text = codeOrEmailCtrl.text.trim();
                            _passwordCtrl.text = newP;
                          } else {
                            setDlgState(() {
                              statusMsg = res?['message'] ?? 'Failed to reset password';
                              isError = true;
                            });
                          }
                        } catch (err) {
                          setDlgState(() {
                            isSubmitting = false;
                            statusMsg = 'Error: $err';
                            isError = true;
                          });
                        }
                      }
                    },
              child: Text(isSubmitting
                  ? 'Please wait...'
                  : (step == 1 ? 'Send OTP' : 'Reset Password')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRequestLeaveDialog() async {
    if (_leaveBalances.isEmpty) {
      _showToast('No leave quotas assigned to your account.', isError: true);
      return;
    }

    dynamic selectedLeaveTypeId = _leaveBalances.first['leave_type_id'] ?? _leaveBalances.first['id'];
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    int calculateDays(DateTime s, DateTime e) {
      int count = 0;
      for (DateTime d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
        if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
          count++;
        }
      }
      return count == 0 ? 1 : count;
    }

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totalDays = calculateDays(startDate, endDate);
          final selectedLb = _leaveBalances.firstWhere(
            (b) => (b['leave_type_id'] ?? b['id'])?.toString() == selectedLeaveTypeId?.toString(),
            orElse: () => _leaveBalances.first,
          );
          final allocated = double.tryParse((selectedLb['allocated'] ?? selectedLb['allocated_quota'] ?? 0).toString()) ?? 0;
          final used = double.tryParse((selectedLb['used'] ?? selectedLb['used_quota'] ?? 0).toString()) ?? 0;
          final remaining = double.tryParse((selectedLb['remaining'] ?? selectedLb['remaining_quota'] ?? (allocated - used)).toString()) ?? 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.beach_access, color: accentIndigo, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Leave Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<dynamic>(
                    value: selectedLeaveTypeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _leaveBalances.map((lb) {
                      final id = lb['leave_type_id'] ?? lb['id'];
                      final name = lb['name'] ?? lb['leave_type_name'] ?? 'Leave';
                      final left = lb['remaining'] ?? lb['remaining_quota'] ?? 0;
                      return DropdownMenuItem<dynamic>(
                        value: id,
                        child: Text('$name ($left day(s) left)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedLeaveTypeId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    startDate = picked;
                                    if (endDate.isBefore(startDate)) {
                                      endDate = startDate;
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: borderSubtle),
                                  borderRadius: BorderRadius.circular(10),
                                  color: bgGrey,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: accentIndigo),
                                    const SizedBox(width: 6),
                                    Text(DateFormat('dd MMM yyyy').format(startDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    endDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: borderSubtle),
                                  borderRadius: BorderRadius.circular(10),
                                  color: bgGrey,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event, size: 14, color: accentIndigo),
                                    const SizedBox(width: 6),
                                    Text(DateFormat('dd MMM yyyy').format(endDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Requested Duration:', style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
                        Text(
                          '$totalDays Day(s)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: totalDays > remaining ? dangerRed : successGreen),
                        ),
                      ],
                    ),
                  ),
                  if (totalDays > remaining) ...[
                    const SizedBox(height: 4),
                    Text('⚠️ Requested days exceed available balance ($remaining days left).', style: const TextStyle(color: dangerRed, fontSize: 11)),
                  ],
                  const SizedBox(height: 12),

                  const Text('Reason for Leave *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Family function, urgent personal work, medical visit...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accentIndigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) {
                          _showToast('Please provide a reason for the leave', isError: true);
                          return;
                        }
                        if (selectedLeaveTypeId == null) {
                          _showToast('Please select a leave type', isError: true);
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          final payload = {
                            'employee_id': _employeeData?['id'],
                            'leave_type_id': selectedLeaveTypeId,
                            'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                            'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                            'reason': reason,
                          };
                          final res = await ApiClient.post(ApiEndpoints.hrmsLeaves, payload);
                          if (res != null && res['success'] == true) {
                            if (mounted) Navigator.pop(dlgCtx);
                            _showToast('Leave request submitted! Awaiting manager approval.');
                            _loadProfileData();
                          } else {
                            final msg = res?['message'] ?? 'Failed to submit leave request';
                            _showToast(msg.toString(), isError: true);
                            setDialogState(() => isSubmitting = false);
                          }
                        } catch (e) {
                          _showToast('Error submitting leave: $e', isError: true);
                          setDialogState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRequestLoanDialog() async {
    final amountCtrl = TextEditingController();
    final emiCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final emi = double.tryParse(emiCtrl.text.trim()) ?? 0.0;
          final months = (amt > 0 && emi > 0) ? (amt / emi).ceil() : 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: warningAmber, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Request Advance / Loan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Request an employee salary advance or loan. Requires management approval.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 14),

                  const Text('Loan Amount (₹) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'e.g. 10000',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),

                  const Text('Monthly EMI Repayment (₹) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emiCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'e.g. 2000',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  if (months > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Estimated Repayment Term: ~$months month(s)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                  const SizedBox(height: 12),

                  const Text('Purpose / Reason *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Medical emergency, urgent home repair, travel...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accentIndigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final loanAmt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                        final loanEmi = double.tryParse(emiCtrl.text.trim()) ?? 0;
                        final reason = reasonCtrl.text.trim();

                        if (loanAmt <= 0) {
                          _showToast('Please enter a valid loan amount', isError: true);
                          return;
                        }
                        if (loanEmi <= 0) {
                          _showToast('Please enter a valid monthly EMI amount', isError: true);
                          return;
                        }
                        if (loanEmi > loanAmt) {
                          _showToast('Monthly EMI cannot exceed total loan amount', isError: true);
                          return;
                        }
                        if (reason.isEmpty) {
                          _showToast('Please provide a reason or purpose', isError: true);
                          return;
                        }

                        setDlgState(() => isSubmitting = true);
                        try {
                          final res = await ApiClient.post(ApiEndpoints.hrmsEmployeeRequestLoan, {
                            'loan_amount': loanAmt,
                            'monthly_emi': loanEmi,
                            'notes': reason,
                          });
                          if (res != null && res['success'] == true) {
                            if (mounted) Navigator.pop(dlgCtx);
                            _showToast(res['message']?.toString() ?? 'Loan request submitted successfully!');
                            _loadProfileData();
                          } else {
                            final msg = res?['message'] ?? 'Failed to submit loan request';
                            _showToast(msg.toString(), isError: true);
                            setDlgState(() => isSubmitting = false);
                          }
                        } catch (e) {
                          _showToast('Error requesting loan: $e', isError: true);
                          setDlgState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRequestSalaryRaiseDialog() async {
    final currentSalary = double.tryParse(_employeeData?['base_salary']?.toString() ?? '0') ?? 0.0;
    final newSalaryCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime effectiveDate = DateTime.now().add(const Duration(days: 15));
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final requested = double.tryParse(newSalaryCtrl.text.trim()) ?? 0.0;
          final hikePercent = (currentSalary > 0 && requested > currentSalary)
              ? (((requested - currentSalary) / currentSalary) * 100).toStringAsFixed(1)
              : null;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: successGreen, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Request Salary Raise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Propose a salary revision based on performance and achievements.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgGrey,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Base Salary:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('₹${currentSalary.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryNavy)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Proposed New Salary (₹) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newSalaryCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'e.g. ${(currentSalary * 1.15).toStringAsFixed(0)}',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  if (hikePercent != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Proposed Increment: +$hikePercent% (₹${(requested - currentSalary).toStringAsFixed(2)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ),
                  ],
                  const SizedBox(height: 12),

                  const Text('Proposed Effective Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effectiveDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDlgState(() => effectiveDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderSubtle),
                        borderRadius: BorderRadius.circular(10),
                        color: bgGrey,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMMM yyyy').format(effectiveDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const Icon(Icons.calendar_today, size: 16, color: accentIndigo),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Justification & Accomplishments *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe targets met, projects completed, additional responsibilities handled...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: successGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final proposed = double.tryParse(newSalaryCtrl.text.trim()) ?? 0;
                        final reason = reasonCtrl.text.trim();

                        if (proposed <= currentSalary) {
                          _showToast('Proposed salary must be higher than current salary (₹${currentSalary.toStringAsFixed(2)})', isError: true);
                          return;
                        }
                        if (reason.isEmpty) {
                          _showToast('Please provide accomplishments or reasons for the raise', isError: true);
                          return;
                        }

                        setDlgState(() => isSubmitting = true);
                        try {
                          final res = await ApiClient.post(ApiEndpoints.hrmsEmployeeRequestRaise, {
                            'requested_salary': proposed,
                            'effective_date': DateFormat('yyyy-MM-dd').format(effectiveDate),
                            'reason': reason,
                          });
                          if (res != null && res['success'] == true) {
                            if (mounted) Navigator.pop(dlgCtx);
                            _showToast(res['message']?.toString() ?? 'Salary raise request submitted!');
                            _loadProfileData();
                          } else {
                            final msg = res?['message'] ?? 'Failed to submit salary raise request';
                            _showToast(msg.toString(), isError: true);
                            setDlgState(() => isSubmitting = false);
                          }
                        } catch (e) {
                          _showToast('Error requesting raise: $e', isError: true);
                          setDlgState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printSalarySlipPdf(Map<String, dynamic> slip) async {
    try {
      final pdfDoc = pw.Document();
      final period = slip['payrollRun']?['pay_period'] ?? '2026-11';
      final empName = _employeeData?['full_name'] ?? 'Employee';
      final empCode = _employeeData?['employee_code'] ?? 'EMP-0002';
      final desig = _employeeData?['designation']?['name'] ?? _employeeData?['designation_name'] ?? 'Staff Member';
      final office = _officeData?['office_name'] ?? 'Head Office';
      final bankName = _employeeData?['bank_name'] ?? '-';
      final bankAcc = _employeeData?['bank_account_no'] ?? '-';
      final ifsc = _employeeData?['bank_ifsc'] ?? '-';

      final prorated = double.tryParse(slip['prorated_salary']?.toString() ?? '0') ?? 0.0;
      final bonuses = double.tryParse(slip['bonuses']?.toString() ?? '0') ?? 0.0;
      final otPay = double.tryParse(slip['overtime_pay']?.toString() ?? '0') ?? 0.0;
      final commission = double.tryParse(slip['sales_commission']?.toString() ?? '0') ?? 0.0;
      final grossPay = double.tryParse(slip['gross_pay']?.toString() ?? '0') ?? 0.0;
      final netPay = double.tryParse(slip['net_pay']?.toString() ?? '0') ?? 0.0;

      final statDeduct = double.tryParse(slip['statutory_deductions']?.toString() ?? '0') ?? 0.0;
      final loanEmi = double.tryParse(slip['loan_emi']?.toString() ?? '0') ?? 0.0;
      final shortage = double.tryParse(slip['shortage_penalties']?.toString() ?? '0') ?? 0.0;
      final totalDeduct = double.tryParse(slip['total_deductions']?.toString() ?? '0') ?? 0.0;

      final daysPresent = slip['days_present'] ?? 0;
      final daysAbsent = slip['days_absent'] ?? 0;
      final daysLeave = slip['days_on_leave'] ?? 0;

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text('FAMALTH TECHNOLOGIES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('OFFICIAL SALARY PAYSLIP', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        pw.Text('Pay Period: $period', style: const pw.TextStyle(fontSize: 11)),
                        pw.Divider(thickness: 1.2),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Employee: $empName ($empCode)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text('Designation: $desig', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Branch / Office: $office', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Days Present: $daysPresent', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Days Absent: $daysAbsent', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Paid Leaves: $daysLeave', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 14),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('EARNINGS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('AMOUNT (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('DEDUCTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('AMOUNT (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Earned Base Salary', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(prorated.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Statutory (PF/ESI/TDS)', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(statDeduct.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Bonuses / Incentives', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(bonuses.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Loan / Advance EMI', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(loanEmi.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Overtime / Commission', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((otPay + commission).toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Shortage / Penalties', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(shortage.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Gross Earnings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(grossPay.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Deductions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(totalDeduct.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green400)),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('NET TAKE-HOME PAY:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Text('INR ${netPay.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green900)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('Disbursed To Account: $bankName | A/C: $bankAcc | IFSC: $ifsc', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Spacer(),
                  pw.Divider(),
                  pw.Center(child: pw.Text('This is a computer-generated salary slip and requires no physical signature.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfDoc.save(),
        name: 'Salary_Slip_${period}_$empCode.pdf',
      );
    } catch (e) {
      _showToast('Error generating PDF slip: $e', isError: true);
    }
  }

  void _showSalarySlipModal(Map<String, dynamic> slip) {
    final period = slip['payrollRun']?['pay_period'] ?? '2026-11';
    final gross = double.tryParse(slip['gross_pay']?.toString() ?? '0') ?? 0.0;
    final net = double.tryParse(slip['net_pay']?.toString() ?? '0') ?? 0.0;
    final prorated = double.tryParse(slip['prorated_salary']?.toString() ?? '0') ?? 0.0;
    final bonuses = double.tryParse(slip['bonuses']?.toString() ?? '0') ?? 0.0;
    final deductions = double.tryParse(slip['total_deductions']?.toString() ?? '0') ?? 0.0;
    final daysPresent = slip['days_present'] ?? 0;
    final daysAbsent = slip['days_absent'] ?? 0;
    final daysLeave = slip['days_on_leave'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salary Payslip — $period', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primaryNavy)),
                    const SizedBox(height: 2),
                    const Text('Official Disbursed Salary Breakdown', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(bctx),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NET TAKE-HOME PAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534), letterSpacing: 0.8)),
                            SizedBox(height: 2),
                            Text('Deposited to registered bank', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                          ],
                        ),
                        Text(
                          '₹${net.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricTile(label: 'Present Days', value: '$daysPresent', icon: Icons.calendar_today_rounded, color: successGreen),
                        _metricTile(label: 'Absent Days', value: '$daysAbsent', icon: Icons.event_busy_rounded, color: dangerRed),
                        _metricTile(label: 'Paid Leaves', value: '$daysLeave', icon: Icons.beach_access_rounded, color: accentIndigo),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Column(
                      children: [
                        _infoRow('Earned Base Salary:', '₹${prorated.toStringAsFixed(2)}'),
                        _infoRow('Bonuses & Incentives:', '₹${bonuses.toStringAsFixed(2)}', valColor: successGreen),
                        _infoRow('Gross Earnings:', '₹${gross.toStringAsFixed(2)}', valColor: primaryNavy),
                        const Divider(height: 16),
                        _infoRow('Total Deductions:', '₹${deductions.toStringAsFixed(2)}', valColor: dangerRed),
                        const Divider(height: 16),
                        _infoRow('Net Payable Amount:', '₹${net.toStringAsFixed(2)}', valColor: successGreen),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_rounded, size: 20, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bank: ${_employeeData?['bank_name'] ?? '-'} • A/C: ${_employeeData?['bank_account_no'] ?? '-'} • IFSC: ${_employeeData?['bank_ifsc'] ?? '-'}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accentIndigo,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.print_rounded, size: 20),
              label: const Text('Print / Save Payslip PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: () {
                Navigator.pop(bctx);
                _printSalarySlipPdf(slip);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? dangerRed : successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valColor ?? primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        backgroundColor: bgGrey,
        body: Center(child: CircularProgressIndicator(color: accentIndigo)),
      );
    }

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.badge_rounded, color: accentIndigo, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Employee App',
              style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        actions: [
          if (_isLoggedIn) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: accentIndigo),
              tooltip: 'Refresh Data',
              onPressed: () async {
                await _loadProfileData();
                await _refreshCurrentGps();
                _showToast('Synced with server');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: dangerRed),
              tooltip: 'Logout',
              onPressed: () async {
                await TokenStorage.clear();
                setState(() {
                  _isLoggedIn = false;
                  _employeeData = null;
                  _officeData = null;
                  _selectedNavIndex = 0;
                });
              },
            ),
          ],
        ],
      ),
      bottomNavigationBar: _isLoggedIn
          ? Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: borderSubtle)),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedNavIndex,
                onTap: (idx) => setState(() => _selectedNavIndex = idx),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: accentIndigo,
                unselectedItemColor: const Color(0xFF94A3B8),
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.how_to_reg_rounded),
                    label: 'Attendance',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.payments_rounded),
                    label: 'Salary & Slips',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_wallet_rounded),
                    label: 'Loans',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            )
          : null,
      body: _isLoggedIn ? _buildLoggedInView() : _buildLoginView(),
    );
  }

  // -------------------------------------------------------------
  // 1. LOGIN VIEW
  // -------------------------------------------------------------
  Widget _buildLoginView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, color: accentIndigo, size: 34),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Employee Attendance Portal',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: primaryNavy),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign in with your employee code or email to mark GPS geotagged attendance and track leaves.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _loginIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Employee Code or Email *',
                  hintText: 'e.g. EMP-001 or name@company.com',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password? (Reset via OTP)',
                    style: TextStyle(color: accentIndigo, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accentIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoggingIn ? null : _doLogin,
                child: _isLoggingIn
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Login to Employee App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. LOGGED IN EMPLOYEE PORTAL VIEW
  // -------------------------------------------------------------
  Widget _buildLoggedInView() {
    switch (_selectedNavIndex) {
      case 1:
        return _buildSalaryTab();
      case 2:
        return _buildLoansTab();
      case 3:
        return _buildProfileTab();
      case 0:
      default:
        return _buildAttendanceTab();
    }
  }

  // -------------------------------------------------------------
  // SHARED HEADER CARD
  // -------------------------------------------------------------
  Widget _buildHeaderCard() {
    final empName = _employeeData?['full_name'] ?? 'Employee';
    final empCode = _employeeData?['employee_code'] ?? '';
    final desig = _employeeData?['designation']?['name'] ?? _employeeData?['designation_name'] ?? 'Staff Member';
    final officeName = _officeData?['office_name'] ?? 'Head Office';
    final officeCode = _officeData?['office_code'] ?? 'HO-01';
    final hasDeviceLock = (_boundDeviceId != null && _boundDeviceId!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEEF2FF),
            child: Text(
              empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
              style: const TextStyle(color: accentIndigo, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: primaryNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  '$empCode • $desig',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Text(
                        '🏢 $officeCode • $officeName',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasDeviceLock ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: hasDeviceLock ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasDeviceLock ? Icons.phonelink_lock_rounded : Icons.phonelink_setup_rounded,
                            size: 11,
                            color: hasDeviceLock ? successGreen : warningAmber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasDeviceLock ? 'Device Bound 🔒' : 'Phone Unbound',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: hasDeviceLock ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 0: ATTENDANCE & PUNCHES
  // -------------------------------------------------------------
  Widget _buildAttendanceTab() {
    final geofenceRadius = _officeData?['geofence_radius_meters'] ?? 100;
    final shiftStart = _shiftData?['start_time'] ?? '09:00 AM';
    final shiftEnd = _shiftData?['end_time'] ?? '05:00 PM';

    final hasPunchedIn = _todayAttendance != null && _todayAttendance!['punch_in'] != null;
    final hasPunchedOut = _todayAttendance != null && _todayAttendance!['punch_out'] != null;
    final inTime = hasPunchedIn ? DateFormat('hh:mm a').format(DateTime.parse(_todayAttendance!['punch_in']).toLocal()) : '--:--';
    final outTime = hasPunchedOut ? DateFormat('hh:mm a').format(DateTime.parse(_todayAttendance!['punch_out']).toLocal()) : '--:--';

    final allowedRadius = double.tryParse(geofenceRadius?.toString() ?? '') ?? 100.0;
    final isWithinGeofence = _distanceFromOffice != null && _distanceFromOffice! <= allowedRadius;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadProfileData();
        await _refreshCurrentGps();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 14),

          // 2. Live GPS & Geotagged Attendance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: accentIndigo, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Geotagged GPS Attendance',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: _isFetchingGps
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, color: accentIndigo, size: 20),
                      tooltip: 'Refresh Location',
                      onPressed: _refreshCurrentGps,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Live distance status
                if (_distanceFromOffice != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isWithinGeofence ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWithinGeofence ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isWithinGeofence ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: isWithinGeofence ? successGreen : dangerRed,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isWithinGeofence
                                    ? 'Within Office Geofence (${_distanceFromOffice!.toStringAsFixed(1)}m away)'
                                    : 'Outside Geofence (${_distanceFromOffice!.toStringAsFixed(1)}m from office)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: isWithinGeofence ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isWithinGeofence
                                    ? 'Allowed radius: ${geofenceRadius}m. You are authorized to punch.'
                                    : 'Exceeds ${geofenceRadius}m limit. Punch will be flagged for review.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isWithinGeofence ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_gpsError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: dangerRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_gpsError!, style: const TextStyle(fontSize: 11.5, color: dangerRed)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('Fetching your live GPS coordinates...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
                const SizedBox(height: 14),

                // Punch In & Punch Out buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: hasPunchedIn ? const Color(0xFF94A3B8) : successGreen,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(hasPunchedIn ? Icons.check_circle_rounded : Icons.login_rounded, size: 18),
                        label: Text(
                          hasPunchedIn ? 'Checked IN' : 'Check IN',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: (_isPunching || hasPunchedIn) ? null : () => _markPunch('IN'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: (!hasPunchedIn || hasPunchedOut) ? const Color(0xFF94A3B8) : dangerRed,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(hasPunchedOut ? Icons.check_circle_rounded : Icons.logout_rounded, size: 18),
                        label: Text(
                          hasPunchedOut ? 'Checked OUT' : 'Check OUT',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: (_isPunching || !hasPunchedIn || hasPunchedOut) ? null : () => _markPunch('OUT'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Today's Punch Summary Tile
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Check In', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(inTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                  ],
                ),
                Container(width: 1, height: 28, color: borderSubtle),
                Column(
                  children: [
                    const Text('Check Out', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(outTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                  ],
                ),
                Container(width: 1, height: 28, color: borderSubtle),
                Column(
                  children: [
                    const Text('Shift Timings', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text('$shiftStart - $shiftEnd', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryNavy)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Monthly Attendance & Overtime Tracker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MONTHLY PERFORMANCE & ATTENDANCE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _metricTile(
                        label: 'Present Days',
                        value: '${_stats['present_days'] ?? 0} days',
                        icon: Icons.calendar_month_rounded,
                        color: successGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricTile(
                        label: 'Late Mins',
                        value: '${_stats['late_minutes'] ?? 0}m',
                        icon: Icons.timer_outlined,
                        color: warningAmber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricTile(
                        label: 'Overtime',
                        value: '${_stats['overtime_hours'] ?? 0}h',
                        icon: Icons.more_time_rounded,
                        color: accentIndigo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. Leave Balances Section (Assigned, Taken, Remaining/Left)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LEAVE BALANCES & QUOTAS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Request Leave', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _showRequestLeaveDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_leaveBalances.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No leave quotas assigned yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  )
                else
                  ..._leaveBalances.map((lb) {
                    final name = lb['name'] ?? lb['leave_type_name'] ?? 'Leave';
                    final allocated = double.tryParse((lb['allocated'] ?? lb['allocated_quota'] ?? lb['quota'] ?? 0).toString()) ?? 0;
                    final used = double.tryParse((lb['used'] ?? lb['used_quota'] ?? lb['taken'] ?? 0).toString()) ?? 0;
                    final remaining = double.tryParse((lb['remaining'] ?? lb['remaining_quota'] ?? lb['left'] ?? (allocated - used)).toString()) ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryNavy)),
                                const SizedBox(height: 2),
                                Text('Entitled: $allocated days • Taken: $used days', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: remaining > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$remaining Left',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: remaining > 0 ? successGreen : dangerRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5.5 My Leave Applications
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'MY LEAVE APPLICATIONS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    Text(
                      '${_myLeaves.length} Submitted',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_myLeaves.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No leave applications submitted yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  )
                else
                  ..._myLeaves.map((app) {
                    final lt = app['leaveType'] ?? {};
                    final typeName = lt['name'] ?? 'Leave';
                    final start = app['start_date'] ?? '';
                    final end = app['end_date'] ?? '';
                    final days = app['total_days'] ?? '1';
                    final status = (app['status'] ?? 'Pending').toString();
                    final reason = app['reason'] ?? '';

                    Color chipBg = const Color(0xFFFEF3C7);
                    Color chipColor = const Color(0xFFD97706);
                    IconData chipIcon = Icons.hourglass_top_rounded;
                    String statusLabel = 'Pending Approval';

                    if (status.toLowerCase() == 'approved') {
                      chipBg = const Color(0xFFDCFCE7);
                      chipColor = const Color(0xFF16A34A);
                      chipIcon = Icons.check_circle_rounded;
                      statusLabel = 'Approved (Auto-Logged)';
                    } else if (status.toLowerCase() == 'rejected') {
                      chipBg = const Color(0xFFFEE2E2);
                      chipColor = const Color(0xFFDC2626);
                      chipIcon = Icons.cancel_rounded;
                      statusLabel = 'Rejected';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(typeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryNavy)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(chipIcon, size: 12, color: chipColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: chipColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$start to $end • $days day(s)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          if (reason.toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Reason: $reason',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 6. Recent Punch History
          if (_recentPunches.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECENT PUNCH HISTORY',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  ..._recentPunches.where((p) => p['punch_in'] != null).map((p) {
                    final date = p['punch_date'] ?? '';
                    final inT = p['punch_in'] != null ? DateFormat('hh:mm a').format(DateTime.parse(p['punch_in']).toLocal()) : '--:--';
                    final outT = p['punch_out'] != null ? DateFormat('hh:mm a').format(DateTime.parse(p['punch_out']).toLocal()) : '--:--';
                    final rawDist = double.tryParse(p['checkin_distance_meters']?.toString() ?? '');
                    final inDist = rawDist != null ? '${rawDist.toStringAsFixed(0)}m' : '—';
                    final isComp = p['is_geofence_compliant'] != false;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: primaryNavy)),
                              Text('In: $inT ($inDist) • Out: $outT', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isComp ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isComp ? 'Compliant' : 'Out of Bounds',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isComp ? successGreen : dangerRed),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: SALARY & OFFICIAL PAYSLIPS
  // -------------------------------------------------------------
  Widget _buildSalaryTab() {
    final baseSalary = double.tryParse((_employeeData?['base_salary'] ?? 0).toString()) ?? 0;
    final structureName = _payStructure?['name'] ?? 'Standard Pay Structure';

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 14),

          // 1. Current Compensation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: accentIndigo, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'CURRENT COMPENSATION',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.trending_up_rounded, size: 14),
                      label: const Text('Request Raise', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _showRequestSalaryRaiseDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Base Monthly Salary', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${NumberFormat('#,##,###.##').format(baseSalary)}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Structure: $structureName',
                          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Official Payslips Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'OFFICIAL SALARY SLIPS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    Text(
                      '${_salarySlips.length} Available',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_salarySlips.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No salary slips published for your profile yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ),
                  )
                else
                  ..._salarySlips.map((slip) {
                    final period = slip['payrollRun']?['pay_period'] ?? 'Period';
                    final netPay = double.tryParse((slip['net_pay'] ?? 0).toString()) ?? 0;
                    final grossPay = double.tryParse((slip['gross_earnings'] ?? 0).toString()) ?? 0;
                    final deductions = double.tryParse((slip['total_deductions'] ?? 0).toString()) ?? 0;
                    final status = slip['status'] ?? 'Paid';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                period,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Net Take-Home', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${NumberFormat('#,##,###.##').format(netPay)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: successGreen),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Gross: ₹${NumberFormat('#,##,###').format(grossPay)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text('Deductions: ₹${NumberFormat('#,##,###').format(deductions)}', style: const TextStyle(fontSize: 11, color: dangerRed)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: borderSubtle),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.visibility_outlined, size: 14, color: primaryNavy),
                                label: const Text('View Slip', style: TextStyle(fontSize: 11, color: primaryNavy, fontWeight: FontWeight.bold)),
                                onPressed: () => _showSalarySlipModal(slip),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: accentIndigo,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.print_rounded, size: 14),
                                label: const Text('Print PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _printSalarySlipPdf(slip),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Salary Revision Requests
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SALARY RAISE REQUESTS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    Text(
                      '${_salaryRevisions.length} Total',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_salaryRevisions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No salary revision requests logged.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ),
                  )
                else
                  ..._salaryRevisions.map((rev) {
                    final oldSal = double.tryParse((rev['previous_salary'] ?? rev['current_salary'] ?? 0).toString()) ?? 0;
                    final newSal = double.tryParse((rev['revised_salary'] ?? rev['requested_salary'] ?? 0).toString()) ?? 0;
                    final effDate = rev['effective_date'] ?? '';
                    final status = (rev['status'] ?? 'Pending').toString();
                    final reason = rev['notes'] ?? rev['reason'] ?? '';

                    Color chipBg = const Color(0xFFFEF3C7);
                    Color chipColor = const Color(0xFFD97706);
                    if (status.toLowerCase() == 'approved') {
                      chipBg = const Color(0xFFDCFCE7);
                      chipColor = const Color(0xFF16A34A);
                    } else if (status.toLowerCase() == 'rejected') {
                      chipBg = const Color(0xFFFEE2E2);
                      chipColor = const Color(0xFFDC2626);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${NumberFormat('#,##,###').format(oldSal)} → ₹${NumberFormat('#,##,###').format(newSal)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryNavy),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: chipColor),
                                ),
                              ),
                            ],
                          ),
                          if (effDate.toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Effective: $effDate', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                          if (reason.toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('Reason: $reason', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: LOANS & ADVANCES
  // -------------------------------------------------------------
  Widget _buildLoansTab() {
    double totalBorrowed = 0;
    double totalBalance = 0;
    double monthlyEmi = 0;

    for (final l in _loans) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      final amt = double.tryParse((l['loan_amount'] ?? 0).toString()) ?? 0;
      final emi = double.tryParse((l['monthly_emi'] ?? 0).toString()) ?? 0;
      final bal = double.tryParse((l['remaining_balance'] ?? amt).toString()) ?? 0;
      if (status != 'rejected') {
        totalBorrowed += amt;
      }
      if (status == 'approved' || status == 'active' || status == 'pending') {
        totalBalance += bal;
        monthlyEmi += emi;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 14),

          // Quick Stats & Action Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.handshake_outlined, color: accentIndigo, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'LOANS & ADVANCES',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Request Loan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _showRequestLoanDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _metricTile(
                        label: 'Total Borrowed',
                        value: '₹${NumberFormat('#,##,###').format(totalBorrowed)}',
                        icon: Icons.account_balance_rounded,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricTile(
                        label: 'Outstanding',
                        value: '₹${NumberFormat('#,##,###').format(totalBalance)}',
                        icon: Icons.pending_actions_rounded,
                        color: warningAmber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricTile(
                        label: 'Monthly EMI',
                        value: '₹${NumberFormat('#,##,###').format(monthlyEmi)}',
                        icon: Icons.calendar_today_rounded,
                        color: accentIndigo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Loan Records List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LOAN & ADVANCE APPLICATIONS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    Text(
                      '${_loans.length} Total',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No loan or salary advance requests found.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ),
                  )
                else
                  ..._loans.map((loan) {
                    final amount = double.tryParse((loan['loan_amount'] ?? 0).toString()) ?? 0;
                    final emi = double.tryParse((loan['monthly_emi'] ?? 0).toString()) ?? 0;
                    final balance = double.tryParse((loan['remaining_balance'] ?? amount).toString()) ?? 0;
                    final status = (loan['status'] ?? 'Pending').toString();
                    final type = loan['loan_type'] ?? 'Salary Advance';
                    final notes = loan['notes'] ?? loan['reason'] ?? '';
                    final date = loan['created_at'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(loan['created_at']).toLocal()) : '';

                    Color chipBg = const Color(0xFFFEF3C7);
                    Color chipColor = const Color(0xFFD97706);
                    if (status.toLowerCase() == 'approved' || status.toLowerCase() == 'active') {
                      chipBg = const Color(0xFFDCFCE7);
                      chipColor = const Color(0xFF16A34A);
                    } else if (status.toLowerCase() == 'rejected') {
                      chipBg = const Color(0xFFFEE2E2);
                      chipColor = const Color(0xFFDC2626);
                    } else if (status.toLowerCase() == 'paid' || status.toLowerCase() == 'closed') {
                      chipBg = const Color(0xFFEFF6FF);
                      chipColor = const Color(0xFF2563EB);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    type,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: primaryNavy),
                                  ),
                                  if (date.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text('($date)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: chipColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Loan', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${NumberFormat('#,##,###').format(amount)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('Monthly EMI', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${NumberFormat('#,##,###').format(emi)} / mo',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryNavy),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Balance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${NumberFormat('#,##,###').format(balance)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: warningAmber),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (notes.toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Reason: $notes', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: COMPLETE EMPLOYEE PROFILE & KYC
  // -------------------------------------------------------------
  Widget _buildProfileTab() {
    final emp = _employeeData ?? {};
    final empName = emp['full_name'] ?? '—';
    final fatherName = emp['father_name'] ?? '—';
    final empCode = emp['employee_code'] ?? '—';
    final email = emp['email'] ?? '—';
    final mobile = emp['mobile_no'] ?? emp['mobile_number'] ?? emp['phone'] ?? '—';
    final gender = emp['gender'] ?? '—';
    final dob = emp['dob'] ?? emp['date_of_birth'] ?? '—';
    final bloodGroup = emp['blood_group'] ?? '—';

    final desig = emp['designation']?['name'] ?? emp['designation_name'] ?? '—';
    final dept = emp['department'] ?? emp['department_name'] ?? 'Operations';
    final doj = emp['doj'] ?? emp['date_of_joining'] ?? '—';

    final bankName = emp['bank_name'] ?? '—';
    final bankAcc = emp['bank_account_no'] ?? emp['account_number'] ?? '—';
    final ifsc = emp['bank_ifsc'] ?? emp['ifsc_code'] ?? '—';
    final pan = emp['pan_number'] ?? emp['pan_no'] ?? '—';
    final uan = emp['uan_number'] ?? emp['uan_no'] ?? '—';
    final esi = emp['esi_number'] ?? emp['esi_no'] ?? '—';

    final boundDev = _boundDeviceId ?? emp['bound_device_id'] ?? 'Not Yet Bound (Auto-binds on Punch)';
    final boundInfo = _boundDeviceInfo ?? emp['bound_device_info'] ?? '—';

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 14),

          // 1. Device Security & Anti-Buddy Punch Enforcement
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security_rounded, color: successGreen, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'DEVICE SECURITY & ANTI-BUDDY PUNCH',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: successGreen, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Loophole Protection Active: Your attendance can only be punched from this registered device. Shared-phone or buddy punching across accounts is automatically blocked.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF166534), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _profileField('Device ID / Token', boundDev),
                _profileField('Hardware / OS Info', boundInfo),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Personal Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PERSONAL DETAILS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                _profileField('Full Name', empName),
                _profileField("Father's Name", fatherName),
                _profileField('Employee Code', empCode),
                _profileField('Email Address', email),
                _profileField('Mobile Phone', mobile),
                _profileField('Gender', gender),
                _profileField('Date of Birth', dob),
                _profileField('Blood Group', bloodGroup),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Employment & Shift
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EMPLOYMENT & ASSIGNMENT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                _profileField('Department', dept),
                _profileField('Designation', desig),
                _profileField('Joining Date', doj),
                _profileField('Assigned Office', '${_officeData?['office_name'] ?? 'Head Office'} (${_officeData?['office_code'] ?? 'HO-01'})'),
                _profileField('Shift Hours', '${_shiftData?['start_time'] ?? '09:00 AM'} - ${_shiftData?['end_time'] ?? '05:00 PM'}'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Bank & Statutory KYC
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BANK & STATUTORY KYC',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                _profileField('Bank Name', bankName),
                _profileField('Bank Account No.', bankAcc),
                _profileField('IFSC Code', ifsc),
                _profileField('PAN Number', pan),
                _profileField('UAN / PF Number', uan),
                _profileField('ESI Number', esi),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: primaryNavy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

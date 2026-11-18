import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

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
  Map<String, dynamic> _stats = {};
  List<dynamic> _recentPunches = [];

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
              _officeData = res['office'];
              _shiftData = res['shift'];
              _todayAttendance = res['today_attendance'];
              _leaveBalances = res['leave_balances'] ?? [];
              _stats = res['stats'] ?? {};
              _recentPunches = res['recent_punches'] ?? [];
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
            _officeData = res['office'];
            _shiftData = res['shift'];
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
          _officeData = res['office'] ?? _officeData;
          _shiftData = res['shift'] ?? _shiftData;
          _todayAttendance = res['today_attendance'];
          _leaveBalances = res['leave_balances'] ?? [];
          _stats = res['stats'] ?? {};
          _recentPunches = res['recent_punches'] ?? [];
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
      final payload = {
        'punch_type': punchType, // 'IN' or 'OUT'
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final res = await ApiClient.post(ApiEndpoints.hrmsEmployeePunch, payload);
      setState(() => _isPunching = false);

      if (res != null && res['success'] == true) {
        final dist = (res['distance_meters'] as num?)?.toDouble() ?? _distanceFromOffice ?? 0.0;
        final officeName = res['office_name'] ?? _officeData?['office_name'] ?? 'Head Office';
        final isCompliant = res['is_geofence_compliant'] != false;
        final lateMins = res['late_arrival_mins'] ?? 0;
        final earlyMins = res['early_departure_mins'] ?? 0;
        final otHours = res['overtime_hours'] ?? 0;

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
        content: Column(
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
                  if (punchType == 'IN' && (lateMins as num) > 0)
                    _infoRow('Late Arrival:', '$lateMins mins late', valColor: warningAmber),
                  if (punchType == 'OUT' && (earlyMins as num) > 0)
                    _infoRow('Early Departure:', '$earlyMins mins early', valColor: dangerRed),
                  if (punchType == 'OUT' && (otHours as num) > 0)
                    _infoRow('Overtime Tracked:', '$otHours hrs', valColor: accentIndigo),
                ],
              ),
            ),
          ],
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
                          });
                          setDlgState(() => isSubmitting = false);
                          if (res != null && res['success'] == true) {
                            setDlgState(() {
                              step = 2;
                              statusMsg = res['message'] ?? 'OTP sent successfully to your email.';
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
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valColor ?? primaryNavy,
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
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: dangerRed),
              tooltip: 'Logout',
              onPressed: () async {
                await TokenStorage.clear();
                setState(() {
                  _isLoggedIn = false;
                  _employeeData = null;
                  _officeData = null;
                });
              },
            ),
        ],
      ),
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
    final empName = _employeeData?['full_name'] ?? 'Employee';
    final empCode = _employeeData?['employee_code'] ?? '';
    final desig = _employeeData?['designation']?['name'] ?? _employeeData?['designation_name'] ?? 'Staff Member';
    final officeName = _officeData?['office_name'] ?? 'Head Office';
    final officeCode = _officeData?['office_code'] ?? 'HO-01';
    final geofenceRadius = _officeData?['geofence_radius_meters'] ?? 100;
    // final shiftName = _shiftData?['name'] ?? 'General Shift';
    final shiftStart = _shiftData?['start_time'] ?? '09:00 AM';
    final shiftEnd = _shiftData?['end_time'] ?? '05:00 PM';

    final hasPunchedIn = _todayAttendance != null && _todayAttendance!['punch_in'] != null;
    final hasPunchedOut = _todayAttendance != null && _todayAttendance!['punch_out'] != null;
    final inTime = hasPunchedIn ? DateFormat('hh:mm a').format(DateTime.parse(_todayAttendance!['punch_in']).toLocal()) : '--:--';
    final outTime = hasPunchedOut ? DateFormat('hh:mm a').format(DateTime.parse(_todayAttendance!['punch_out']).toLocal()) : '--:--';

    final isWithinGeofence = _distanceFromOffice != null && _distanceFromOffice! <= (geofenceRadius as num).toDouble();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadProfileData();
        await _refreshCurrentGps();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Employee Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: accentIndigo,
                  child: Text(
                    empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        empName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$empCode • $desig',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🏢 $officeCode • $officeName',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                          backgroundColor: successGreen,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: Text(hasPunchedIn ? 'Re-Punch IN' : 'Check IN', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isPunching ? null : () => _markPunch('IN'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: dangerRed,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(hasPunchedOut ? 'Re-Punch OUT' : 'Check OUT', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isPunching ? null : () => _markPunch('OUT'),
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
                    Text(
                      '${_leaveBalances.length} Categories',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                    final allocated = double.tryParse((lb['allocated_quota'] ?? lb['quota'] ?? 0).toString()) ?? 0;
                    final used = double.tryParse((lb['used_quota'] ?? lb['taken'] ?? 0).toString()) ?? 0;
                    final remaining = double.tryParse((lb['remaining_quota'] ?? lb['left'] ?? (allocated - used)).toString()) ?? 0;

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
                  ..._recentPunches.map((p) {
                    final date = p['punch_date'] ?? '';
                    final inT = p['punch_in'] != null ? DateFormat('hh:mm a').format(DateTime.parse(p['punch_in']).toLocal()) : '--:--';
                    final outT = p['punch_out'] != null ? DateFormat('hh:mm a').format(DateTime.parse(p['punch_out']).toLocal()) : '--:--';
                    final inDist = p['checkin_distance_meters'] != null ? '${(p['checkin_distance_meters'] as num).toStringAsFixed(0)}m' : '—';
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

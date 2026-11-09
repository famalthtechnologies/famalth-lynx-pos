import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_brand.dart';
import '../../core/config/app_config.dart';
import '../dashboard/server_config_screen.dart';
import 'mobile_billing_app_screen.dart';
import 'mobile_billing_splash_screen.dart';

class MobileBillingAuthScreen extends StatefulWidget {
  final String? notice;
  const MobileBillingAuthScreen({super.key, this.notice});

  @override
  State<MobileBillingAuthScreen> createState() => _MobileBillingAuthScreenState();
}

class _MobileBillingAuthScreenState extends State<MobileBillingAuthScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _outletCtrl = TextEditingController();
  String _selectedRole = 'ADMIN'; // Default to ADMIN as seen in user's profile
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _availableRoles = ['ADMIN', 'STORE', 'CASHIER', 'MANAGER'];

  @override
  void initState() {
    super.initState();
    if (widget.notice != null && widget.notice!.trim().isNotEmpty) {
      _errorMessage = widget.notice!.trim();
    }
    final defaultOutlet =
        AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : 'OUTLET001';
    _outletCtrl.text = defaultOutlet;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _outletCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final outlet = _outletCtrl.text.trim().isNotEmpty
        ? _outletCtrl.text.trim()
        : 'OUTLET001';

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both username and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First attempt with the selected role
      var result = await AuthService.login(
        username,
        password,
        _selectedRole,
        outlet,
      );

      // If backend reports role mismatch (e.g. user assigned ADMIN instead of CASHIER),
      // auto-detect assigned role from the error message and retry seamlessly
      if (!result.success && result.message.contains("assigned role '")) {
        final match = RegExp(r"assigned role '([^']+)'").firstMatch(result.message);
        if (match != null && match.group(1) != null) {
          final detectedRole = match.group(1)!;
          if (_availableRoles.contains(detectedRole)) {
            _selectedRole = detectedRole;
          }
          result = await AuthService.login(
            username,
            password,
            detectedRole,
            outlet,
          );
        }
      }

      if (!mounted) return;

      if (result.success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MobileBillingAppScreen(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = result.message.isNotEmpty
              ? result.message
              : 'Authentication failed. Please verify credentials.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().replaceAll('Exception:', '').trim();

      // If exception message contains assigned role, auto-retry with detected role
      if (errStr.contains("assigned role '")) {
        final match = RegExp(r"assigned role '([^']+)'").firstMatch(errStr);
        if (match != null && match.group(1) != null) {
          final detectedRole = match.group(1)!;
          try {
            final retryResult = await AuthService.login(
              username,
              password,
              detectedRole,
              outlet,
            );
            if (retryResult.success && mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MobileBillingAppScreen(),
                ),
              );
              return;
            }
          } catch (_) {}
        }
      }

      setState(() {
        _errorMessage = errStr;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Server Status Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF5),
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFFA7F3D0)),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Color(0xFF10B981),
                          size: 10,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Connected to Server',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569)),
                    tooltip: 'Server Connection Settings',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ServerConfigScreen(
                            nextScreen: MobileBillingSplashScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Brand Icon & Title
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                AppBrand.coreBrand,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mobile POS & Store Billing',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // Login Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Outlet Code
                    TextField(
                      controller: _outletCtrl,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Outlet Code',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(
                          Icons.store_outlined,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Workstation Role Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Workstation Role',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: _availableRoles.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedRole = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Username
                    TextField(
                      controller: _usernameCtrl,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF64748B),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Sign In Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Sign In to Billing POS',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Connected to Server',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

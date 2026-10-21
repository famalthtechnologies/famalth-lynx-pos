import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/control_plane_storage.dart';
import '../settings/master_control_plane_screen.dart';
import 'control_plane_server_dialog.dart';

class ControlPlaneLoginScreen extends StatefulWidget {
  const ControlPlaneLoginScreen({super.key});

  @override
  State<ControlPlaneLoginScreen> createState() => _ControlPlaneLoginScreenState();
}

class _ControlPlaneLoginScreenState extends State<ControlPlaneLoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'Owner@Lynx2026');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
    _checkSetupStatus();
  }

  Future<void> _checkExistingAuth() async {
    final isAuth = await ControlPlaneStorage.isAuthenticated();
    if (isAuth && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MasterControlPlaneScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _checkSetupStatus() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/auth/setup-status');
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _needsSetup = res['data']?['needs_setup'] == true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.post('/api/v1/control-plane/auth/login', {
        'username': username,
        'password': password,
      });

      if (res['success'] == true && res['data'] != null) {
        final token = res['data']['token'];
        final user = res['data']['user'];

        await ControlPlaneStorage.saveToken(token);
        await ControlPlaneStorage.saveUser(Map<String, dynamic>.from(user));

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MasterControlPlaneScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Authentication failed.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // FIRST-TIME MASTER OWNER REGISTRATION & INITIALIZATION DIALOG
  // =========================================================================
  Future<void> _showInitializeMasterDialog() async {
    final nameCtrl = TextEditingController(text: 'Software Owner');
    final userCtrl = TextEditingController(text: 'owner');
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final otpFormKey = GlobalKey<FormState>();
    int currentStep = 1; // 1 = Registration Form, 2 = Email Verification (OTP)
    bool obscurePass = true;
    bool obscureConfirm = true;
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> requestVerificationOtp() async {
            if (!formKey.currentState!.validate()) return;
            if (passCtrl.text != confirmPassCtrl.text) {
              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.red),
              );
              return;
            }

            final messenger = ScaffoldMessenger.of(dialogCtx);
            setDialogState(() => isProcessing = true);

            try {
              final res = await ApiClient.post('/api/v1/control-plane/auth/request-owner-setup-otp', {
                'email': emailCtrl.text.trim(),
              });

              messenger.showSnackBar(
                SnackBar(
                  content: Text(res['message'] ?? 'Verification code sent to your email address!'),
                  backgroundColor: const Color(0xFF0284C7),
                ),
              );
              setDialogState(() {
                currentStep = 2;
              });
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                  backgroundColor: Colors.red,
                ),
              );
            } finally {
              setDialogState(() => isProcessing = false);
            }
          }

          Future<void> submit() async {
            if (!otpFormKey.currentState!.validate()) return;

            final nav = Navigator.of(dialogCtx);
            final messenger = ScaffoldMessenger.of(dialogCtx);
            setDialogState(() => isProcessing = true);

            try {
              final res = await ApiClient.post('/api/v1/control-plane/auth/initialize-master', {
                'full_name': nameCtrl.text.trim(),
                'username': userCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'password': passCtrl.text,
                'otp': otpCtrl.text.trim(),
              });

              if (res != null && res['success'] == true && res['data'] != null) {
                final token = res['data']['token'];
                final user = res['data']['user'];

                await ControlPlaneStorage.saveToken(token);
                await ControlPlaneStorage.saveUser(Map<String, dynamic>.from(user));

                nav.pop();

                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  this.context,
                  MaterialPageRoute(builder: (_) => const MasterControlPlaneScreen()),
                  (route) => false,
                );
              }
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                  backgroundColor: Colors.red,
                ),
              );
            } finally {
              setDialogState(() => isProcessing = false);
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: currentStep == 1 ? const Color(0xFFF0FDF4) : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: currentStep == 1 ? const Color(0xFFBBF7D0) : const Color(0xFFBAE6FD)),
                  ),
                  child: Icon(
                    currentStep == 1 ? Icons.security_rounded : Icons.mark_email_read_outlined,
                    color: currentStep == 1 ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStep == 1 ? 'Initialize Software Owner' : 'Verify Email Address',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      currentStep == 1
                          ? 'Air-Gapped Setup (Step 1: Master Credentials)'
                          : 'Air-Gapped Setup (Step 2: OTP Verification)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: currentStep == 1
                    ? Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.shield_outlined, color: Color(0xFF0284C7), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Role: SUPER_ADMIN (Software Owner - Locked)\nFull root privileges and ownership are provisioned to this account.',
                                      style: TextStyle(color: Color(0xFF0369A1), fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Owner / Organization Full Name *',
                                prefixIcon: Icon(Icons.badge_outlined, size: 20),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name required' : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: userCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Master Username *',
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                                hintText: 'e.g. owner or admin',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Username required' : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Primary Recovery Email *',
                                prefixIcon: Icon(Icons.email_outlined, size: 20),
                                helperText: 'Mandatory: We will send an OTP to verify this email before setup.',
                                helperMaxLines: 2,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty || !v.contains('@')) ? 'Valid recovery email required' : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Contact Phone Number (Optional)',
                                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: passCtrl,
                              obscureText: obscurePass,
                              decoration: InputDecoration(
                                labelText: 'Master Password (min 8 chars) *',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                                  onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters required' : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: confirmPassCtrl,
                              obscureText: obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'Confirm Master Password *',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                                  onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Confirm password';
                                if (v != passCtrl.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                          ],
                        ),
                      )
                    : Form(
                        key: otpFormKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Verification Code Sent',
                                        style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                      children: [
                                        const TextSpan(text: 'We sent a 6-digit code to '),
                                        TextSpan(
                                          text: emailCtrl.text.trim(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                        const TextSpan(text: '. This guarantees that recovery emails and OTPs will work properly.'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: isProcessing
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              currentStep = 1;
                                            });
                                          },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0284C7)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Wrong email? Click to change',
                                          style: TextStyle(
                                            color: Color(0xFF0284C7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            TextFormField(
                              controller: otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                              decoration: const InputDecoration(
                                labelText: '6-Digit Verification Code *',
                                hintText: '------',
                                prefixIcon: Icon(Icons.pin_outlined),
                                counterText: '',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().length != 6) {
                                  return 'Enter 6-digit code';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Resend Code', style: TextStyle(fontSize: 12)),
                                  onPressed: isProcessing ? null : requestVerificationOtp,
                                ),
                                const Text(
                                  'Valid for 10 minutes',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            actions: [
              if (currentStep == 1) ...[
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                  icon: isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send Verification Code'),
                  onPressed: isProcessing ? null : requestVerificationOtp,
                ),
              ] else ...[
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => setDialogState(() {
                            currentStep = 1;
                          }),
                  child: const Text('Back to Edit', style: TextStyle(color: Color(0xFF64748B))),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  icon: isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Verify & Initialize Owner'),
                  onPressed: isProcessing ? null : submit,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // FORGOT USERNAME DIALOG
  // =========================================================================
  Future<void> _showForgotUsernameDialog() async {
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitRecovery() async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(dialogCtx);
              final messenger = ScaffoldMessenger.of(dialogCtx);
              setDialogState(() => isProcessing = true);

              try {
                final res = await ApiClient.post('/api/v1/control-plane/auth/recover-username', {
                  'email': emailCtrl.text.trim(),
                });

                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Recovery email sent.'),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              } finally {
                setDialogState(() => isProcessing = false);
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_search_rounded, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Recover Operator Username', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Text(
                          'Enter your registered operator email address. We will verify your credentials and email you all active operator usernames associated with your account.',
                          style: TextStyle(color: Color(0xFF0369A1), fontSize: 12, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Registered Operator Email *',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty || !v.contains('@')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                  onPressed: isProcessing ? null : submitRecovery,
                  child: isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send Recovery Email'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // FORGOT PASSWORD DIALOG (2-STEP OTP VERIFICATION & RESET)
  // =========================================================================
  Future<void> _showForgotPasswordDialog() async {
    int currentStep = 1;
    bool isProcessing = false;
    String maskedEmail = '';
    String? staffId;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final userOrEmailCtrl = TextEditingController(text: _usernameController.text.trim());
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> requestOtp({bool isResend = false}) async {
              final idText = userOrEmailCtrl.text.trim();
              final messenger = ScaffoldMessenger.of(dialogCtx);
              if (idText.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Operator Username or Email required'), backgroundColor: Colors.red),
                );
                return;
              }

              setDialogState(() => isProcessing = true);

              try {
                final res = await ApiClient.post('/api/v1/control-plane/auth/forgot-password/request-otp', {
                  'usernameOrEmail': idText,
                });

                if (res['success'] == true) {
                  maskedEmail = res['data']?['maskedEmail'] ?? '';
                  staffId = res['data']?['staffId'];
                  setDialogState(() => currentStep = 2);

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'OTP Sent!'),
                      backgroundColor: const Color(0xFF0284C7),
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setDialogState(() => isProcessing = false);
              }
            }

            Future<void> submitReset() async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(dialogCtx);
              final messenger = ScaffoldMessenger.of(dialogCtx);

              if (newPassCtrl.text != confirmPassCtrl.text) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('New passwords do not match!'), backgroundColor: Colors.red),
                );
                return;
              }

              setDialogState(() => isProcessing = true);

              try {
                final res = await ApiClient.post('/api/v1/control-plane/auth/forgot-password/verify-and-reset', {
                  'staffId': staffId,
                  'usernameOrEmail': userOrEmailCtrl.text.trim(),
                  'otp': otpCtrl.text.trim(),
                  'newPassword': newPassCtrl.text,
                });

                if (res['success'] == true) {
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Password reset successfully.'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                  // Update current password field with new password
                  _passwordController.text = newPassCtrl.text;
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setDialogState(() => isProcessing = false);
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF16A34A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    currentStep == 1 ? 'Reset Master Password' : 'Enter OTP & Set Password',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentStep == 1) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: const Text(
                            'Enter your operator username or registered email. We will send a secure 6-digit OTP code to verify your identity before resetting your master password.',
                            style: TextStyle(color: Color(0xFF0369A1), fontSize: 12, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: userOrEmailCtrl,
                          decoration: InputDecoration(
                            labelText: 'Operator Username or Email *',
                            labelStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Username or email required' : null,
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            'OTP has been dispatched to $maskedEmail. Please check your inbox and enter the 6-digit verification code below.',
                            style: const TextStyle(color: Color(0xFF15803D), fontSize: 12, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: otpCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '• • • • • •',
                            labelText: '6-Digit OTP Code *',
                            labelStyle: const TextStyle(fontSize: 13, letterSpacing: 0),
                            prefixIcon: const Icon(Icons.dialpad_rounded, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().length != 6) ? 'Enter 6-digit OTP' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: newPassCtrl,
                          obscureText: obscureNew,
                          decoration: InputDecoration(
                            labelText: 'New Master Password (min 8 chars) *',
                            labelStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                              onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 8) return 'Minimum 8 characters required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPassCtrl,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password *',
                            labelStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                              onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please confirm password';
                            if (v != newPassCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.replay_rounded, size: 14),
                            label: const Text('Resend OTP Code', style: TextStyle(fontSize: 12)),
                            onPressed: isProcessing ? null : () => requestOtp(isResend: true),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                  onPressed: isProcessing
                      ? null
                      : () {
                          if (currentStep == 1) {
                            requestOtp();
                          } else {
                            submitReset();
                          }
                        },
                  child: isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(currentStep == 1 ? 'Send Verification OTP' : 'Verify & Set Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Clean Light Slate background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Server Connectivity Badge Top
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ControlPlaneServerBadge(
                    onChanged: _checkSetupStatus,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(36.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF64748B).withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header branding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FAMALTH CLOUD CONSOLE',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                'Enterprise Master Control Plane',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Notice Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_rounded, color: Color(0xFF0284C7), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Restricted Zone: Dedicated IAM for Software Owners, Developers, Resellers & L2 Support staff.',
                                style: TextStyle(color: Color(0xFF0369A1), fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // First-Time Setup Banner (Only visible if system needs initial owner setup)
                      if (_needsSetup) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_user_rounded, color: Color(0xFF15803D), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Initial Setup Required',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Set up your primary Software Owner account with your real recovery email address so OTP password resets and verification work immediately.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF14532D), height: 1.35),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.app_registration_rounded, size: 18),
                                  label: const Text(
                                    'Initialize Software Owner Account',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                  ),
                                  onPressed: _showInitializeMasterDialog,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Username / Email
                      const Text(
                        'OPERATOR USERNAME / EMAIL',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B), size: 20),
                          hintText: 'admin or username@famalth.com',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Password
                      const Text(
                        'MASTER PASSWORD',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF64748B),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          hintText: '••••••••••••',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _handleLogin(),
                      ),

                      const SizedBox(height: 12),

                      // Forgot Username & Forgot Password actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _showForgotUsernameDialog,
                            child: const Text(
                              'Forgot Username?',
                              style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Login Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'AUTHENTICATE & ENTER CONSOLE',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.6),
                                  ),
                                ],
                              ),
                      ),

                      if (canGoBack) ...[
                        const SizedBox(height: 16),
                        // Return to POS Terminal
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF64748B), size: 16),
                          label: const Text(
                            'Back to Store POS Terminal',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Famalth Lynx Cloud Infrastructure • Enterprise IAM',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

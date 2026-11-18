import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../dashboard/server_config_screen.dart';
import 'employee_portal_screen.dart';

class EmployeeAppSplashScreen extends StatefulWidget {
  const EmployeeAppSplashScreen({super.key});

  @override
  State<EmployeeAppSplashScreen> createState() => _EmployeeAppSplashScreenState();
}

class _EmployeeAppSplashScreenState extends State<EmployeeAppSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  static const Color primaryNavy = Color(0xFF1E293B);
  static const Color accentIndigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();

    _initializeApp();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    try {
      final bool hasConfig = await AppConfig.configExists();
      if (!hasConfig) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ServerConfigScreen(
              nextScreen: EmployeeAppSplashScreen(),
            ),
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const EmployeePortalScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Settings button at top right to change server URL if required
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
                tooltip: 'Server Settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ServerConfigScreen(
                        nextScreen: EmployeeAppSplashScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: accentIndigo.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: const Column(
                      children: [
                        Text(
                          'Staff Attendance',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: primaryNavy,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Geotagged GPS Check-In & Leave Tracker',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accentIndigo,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Enterprise Workforce Cloud',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

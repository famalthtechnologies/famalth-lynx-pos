import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../dashboard/server_config_screen.dart';
import 'public_appointment_booking_screen.dart';

class ClinicAppSplashScreen extends StatefulWidget {
  final dynamic outletId;
  final String? doctorName;

  const ClinicAppSplashScreen({
    super.key,
    this.outletId,
    this.doctorName,
  });

  @override
  State<ClinicAppSplashScreen> createState() => _ClinicAppSplashScreenState();
}

class _ClinicAppSplashScreenState extends State<ClinicAppSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();

    _navigateToClinic();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigateToClinic() async {
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    try {
      final bool hasConfig = await AppConfig.configExists();
      if (!hasConfig) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ServerConfigScreen(
              nextScreen: ClinicAppSplashScreen(),
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
        builder: (context) => PublicAppointmentBookingScreen(
          initialOutletId: widget.outletId,
          initialDoctorName: widget.doctorName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF0D9488); // Medical Teal

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  size: 48,
                  color: brandColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Doctor & Clinic Portal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explore Specialists • Verified Doctors • Book Appointments',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

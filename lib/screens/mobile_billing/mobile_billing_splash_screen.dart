import 'package:flutter/material.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_brand.dart';
import '../../core/config/app_config.dart';
import '../dashboard/server_config_screen.dart';
import 'mobile_billing_app_screen.dart';
import 'mobile_billing_auth_screen.dart';

class MobileBillingSplashScreen extends StatefulWidget {
  const MobileBillingSplashScreen({super.key});

  @override
  State<MobileBillingSplashScreen> createState() =>
      _MobileBillingSplashScreenState();
}

class _MobileBillingSplashScreenState extends State<MobileBillingSplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkStatusAndNavigate();
  }

  Future<void> _checkStatusAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      final hasConfig = await AppConfig.configExists();
      if (!hasConfig) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ServerConfigScreen(
              nextScreen: MobileBillingSplashScreen(),
            ),
          ),
        );
        return;
      }

      final token = await TokenStorage.read();
      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MobileBillingAppScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MobileBillingAuthScreen(),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MobileBillingAuthScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              AppBrand.coreBrand,
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mobile POS & Store Billing',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

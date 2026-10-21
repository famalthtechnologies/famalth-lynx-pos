import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../dashboard/server_config_screen.dart';
import 'table_dining_screen.dart';

class DiningAppSplashScreen extends StatefulWidget {
  final String? outletId;
  final String? tableId;
  final String? tableName;
  final String? seatNumber;
  final String? clientTag;

  const DiningAppSplashScreen({
    super.key,
    this.outletId,
    this.tableId,
    this.tableName,
    this.seatNumber,
    this.clientTag,
  });

  @override
  State<DiningAppSplashScreen> createState() => _DiningAppSplashScreenState();
}

class _DiningAppSplashScreenState extends State<DiningAppSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();

    _navigateToDining();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigateToDining() async {
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
              nextScreen: DiningAppSplashScreen(),
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
        builder: (context) => TableDiningScreen(
          outletId: widget.outletId,
          tableId: widget.tableId,
          tableName: widget.tableName,
          seatNumber: widget.seatNumber,
          clientTag: widget.clientTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFFE23744); // Zomato/Swiggy dining red

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
                child: const Center(
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: brandColor,
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Digital Dining & Self-Order',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Scan • Order • Settle by Seat or Table',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
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

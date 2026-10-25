import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/api/api_client.dart';
import 'core/config/app_config.dart';
import 'core/auth/control_plane_storage.dart';
import 'screens/control_plane/control_plane_login_screen.dart';
import 'screens/settings/master_control_plane_screen.dart';
import 'main.dart' show globalSnackbarKey, globalNavigatorKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.isAdminConsole = true;
  await AppConfig.init();

  final bool isAuth = await ControlPlaneStorage.isAuthenticated();

  runApp(EnterpriseControlPlaneApp(initialAuthenticated: isAuth));
}

class EnterpriseControlPlaneApp extends StatelessWidget {
  final bool initialAuthenticated;

  const EnterpriseControlPlaneApp({
    super.key,
    required this.initialAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      scaffoldMessengerKey: globalSnackbarKey,
      title: 'Famalth Enterprise Control Plane',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Pure light slate
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          primary: const Color(0xFF0284C7),
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Color(0xFF0F172A),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        fontFamily: 'Segoe UI',
        fontFamilyFallback: const ['Inter', 'Roboto', 'Arial', 'sans-serif'],
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.5),
          displayMedium: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.4),
          titleLarge: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 18, letterSpacing: -0.3),
          titleMedium: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 15),
          bodyLarge: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w500, color: Color(0xFF1E293B), fontSize: 13.5),
          bodyMedium: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w400, color: Color(0xFF334155), fontSize: 12.5),
          bodySmall: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w400, color: Color(0xFF64748B), fontSize: 11),
          labelLarge: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 12),
        ),
      ),
      home: initialAuthenticated
          ? const MasterControlPlaneScreen()
          : const ControlPlaneLoginScreen(),
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null && (uri.path == '/login' || uri.path == '/auth')) {
          return MaterialPageRoute(builder: (_) => const ControlPlaneLoginScreen());
        }
        return MaterialPageRoute(
          builder: (_) => initialAuthenticated
              ? const MasterControlPlaneScreen()
              : const ControlPlaneLoginScreen(),
        );
      },
    );
  }
}

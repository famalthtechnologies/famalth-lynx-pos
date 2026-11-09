import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/security/recovery_controller.dart';
import 'controllers/security/user_controller.dart';
import 'controllers/settings/notification_services.dart';
import 'controllers/settings/app_branding_controller.dart';
import 'controllers/settings/system_settings_controller.dart';
import 'controllers/settings/theme_controller.dart';
import 'controllers/settings/ui_preferences_controller.dart';
import 'controllers/settings/property_info_controller.dart';
import 'controllers/sales/sales_controller.dart';
import 'core/config/app_config.dart';
import 'core/config/date_time_service.dart';
import 'main.dart'; // Reuses MyApp, global navigator and snackbar keys
import 'screens/mobile_billing/mobile_billing_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.isMobileBilling = true;
  await NotificationService.init();
  await AppConfig.init();
  await DateTimeService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SystemSettingsController()..load()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => UiPreferencesController()..load()),
        ChangeNotifierProvider(create: (_) => AppBrandingController()..loadLocal()),
        ChangeNotifierProvider(create: (_) => UserController()),
        ChangeNotifierProvider(create: (_) => RecoveryController()),
        ChangeNotifierProvider(create: (_) => PropertyInfoController()..load()),
        ChangeNotifierProvider(create: (_) => SalesController()),
      ],
      child: const MyApp(homeWidget: MobileBillingSplashScreen()),
    ),
  );
}

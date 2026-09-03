import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/main_dashboard.dart';
import 'screens/login_page.dart';
import 'config/app_config.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

/// Backward-compatible alias referencing the centralized ThemeService notifier.
final ValueNotifier<ThemeMode> themeNotifier = ThemeService.themeModeNotifier;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.init();
  await ThemeService.init();
  AppConfig.logConfig();
  final user = FirebaseAuth.instance.currentUser;
  runApp(MyApp(isLoggedIn: user != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'FitLoop',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: isLoggedIn ? const MainDashboard() : const LoginPage(),
        );
      },
    );
  }
}

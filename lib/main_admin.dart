// lib/main_admin.dart
//
// Standalone Admin / Operations Portal App entrypoint.
// Run with: flutter run -t lib/main_admin.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Services/app_bootstrap.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  final session = await bootstrapApp(defaultRole: 'ADMIN');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
      ],
      child: const CraveyAdminApp(),
    ),
  );
}

class CraveyAdminApp extends StatelessWidget {
  const CraveyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cravey Admin - Operations Portal',
      theme: AppTheme.adminTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(
              title: 'Cravey Admin',
              subtitle: 'Platform Operations & Fleet Control',
              icon: Icons.admin_panel_settings_rounded,
              gradient: AppTheme.adminGradient,
              shadowColor: AppTheme.adminPrimary,
              fixedRole: 'ADMIN',
              unauthenticatedRoute: '/login',
            ),
        '/login': (context) => const LoginScreen(
              fixedRole: 'ADMIN',
              nextRoute: '/admin-dashboard',
            ),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const AdminDashboardScreen(),
      ),
    );
  }
}

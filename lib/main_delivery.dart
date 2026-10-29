// lib/main_delivery.dart
//
// Standalone Delivery Partner / Rider App entrypoint.
// Run with: flutter run -t lib/main_delivery.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Services/app_bootstrap.dart';
import 'models/cart_state.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/delivery_dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  final session = await bootstrapApp(defaultRole: 'DELIVERY');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => CartState()),
      ],
      child: const CraveyDeliveryApp(),
    ),
  );
}

class CraveyDeliveryApp extends StatelessWidget {
  const CraveyDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cravey Rider - Delivery Fleet',
      theme: AppTheme.deliveryTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(
              title: 'Cravey Rider',
              subtitle: 'Live Dispatches & Trip Earnings',
              icon: Icons.two_wheeler_rounded,
              gradient: AppTheme.deliveryGradient,
              shadowColor: AppTheme.deliveryPrimary,
              fixedRole: 'DELIVERY',
              unauthenticatedRoute: '/login',
            ),
        '/login': (context) => const LoginScreen(
              fixedRole: 'DELIVERY',
              nextRoute: '/delivery-dashboard',
            ),
        '/delivery-dashboard': (context) => const DeliveryDashboardScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const DeliveryDashboardScreen(),
      ),
    );
  }
}

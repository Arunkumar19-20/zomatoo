// lib/main_restaurant.dart
//
// Standalone Restaurant Partner / Merchant App entrypoint.
// Run with: flutter run -t lib/main_restaurant.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Services/app_bootstrap.dart';
import 'screens/splash_screen.dart';
import 'screens/restaurant_login_screen.dart';
import 'screens/restaurant_dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  final session = await bootstrapApp(defaultRole: 'OWNER');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
      ],
      child: const CraveyRestaurantApp(),
    ),
  );
}

class CraveyRestaurantApp extends StatelessWidget {
  const CraveyRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cravey Partner - Restaurant Manager',
      theme: AppTheme.restaurantTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(
              title: 'Cravey Partner',
              subtitle: 'Kitchen Queue & Menu Manager',
              icon: Icons.storefront_rounded,
              gradient: AppTheme.restaurantGradient,
              shadowColor: AppTheme.restaurantPrimary,
              fixedRole: 'OWNER',
              unauthenticatedRoute: '/login',
            ),
        '/login': (context) => const RestaurantLoginScreen(
              nextRoute: '/restaurant-dashboard',
            ),
        '/restaurant-dashboard': (context) => const RestaurantDashboardScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const RestaurantDashboardScreen(),
      ),
    );
  }
}

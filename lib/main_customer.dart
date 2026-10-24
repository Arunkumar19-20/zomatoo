// lib/main_customer.dart
//
// Standalone Customer App entrypoint for Cravey.
// Run with: flutter run -t lib/main_customer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/cart_state.dart';
import 'Services/app_bootstrap.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/delivery_intro_screen.dart';
import 'screens/home_screen.dart';
import 'screens/restaurant_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/search_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  final session = await bootstrapApp(defaultRole: 'CUSTOMER');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => CartState()),
      ],
      child: const CraveyCustomerApp(),
    ),
  );
}

class CraveyCustomerApp extends StatelessWidget {
  const CraveyCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cravey - Food Delivery',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(
              title: 'Cravey',
              subtitle: 'Satisfy Your Desires',
              fixedRole: 'CUSTOMER',
              unauthenticatedRoute: '/onboarding',
            ),
        '/onboarding': (context) => const OnboardingScreen(nextRoute: '/login'),
        '/login': (context) => const LoginScreen(fixedRole: 'CUSTOMER'),
        '/signup': (context) => const CreateAccountScreen(),
        '/intro': (context) => const DeliveryIntroScreen(),
        '/home': (context) => const HomeScreen(),
        '/restaurant': (context) => const RestaurantDetailScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/tracking': (context) => const OrderTrackingScreen(),
        '/orders-history': (context) => const OrderHistoryScreen(),
        '/search': (context) => const SearchScreen(),
        '/offers': (context) => const OffersScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }
}

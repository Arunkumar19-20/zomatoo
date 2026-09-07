import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/cart_state.dart';
import 'Services/session_provider.dart';
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
import 'theme/app_theme.dart';
import 'Services/web_oauth_storage_stub.dart'
    if (dart.library.html) 'Services/web_oauth_storage_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore any saved JWT session before the UI renders.
  final session = SessionProvider();

  // Web: check if auth.html wrote a token to localStorage after the
  // direct-tab OAuth redirect returned the user to '/'.
  if (kIsWeb) {
    try {
      final raw = getOAuthToken();
      if (raw != null && raw.isNotEmpty) {
        clearOAuthToken();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final token = decoded['token']?.toString();
        final email = decoded['email']?.toString() ?? '';
        final role  = decoded['role']?.toString() ?? 'CUSTOMER';
        if (token != null && token.isNotEmpty) {
          await session.login(token, email, role);
        }
      }
    } catch (_) {}
  }

  await session.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => CartState()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cravey',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const CreateAccountScreen(),
        '/intro': (context) => const DeliveryIntroScreen(),
        '/home': (context) => const HomeScreen(),
        '/restaurant': (context) => const RestaurantDetailScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/tracking': (context) => const OrderTrackingScreen(),
      },
    );
  }
}

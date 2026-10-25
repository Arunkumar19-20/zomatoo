import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/cart_state.dart';
import 'services/session_provider.dart';
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
import 'screens/role_selection_screen.dart';
import 'screens/restaurant_dashboard_screen.dart';
import 'screens/delivery_dashboard_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/drop_detail_screen.dart';
import 'screens/drop_checkout_screen.dart';
import 'theme/app_theme.dart';
import 'services/web_oauth_storage_stub.dart'
    if (dart.library.html) 'services/web_oauth_storage_web.dart';
import 'services/payment_service.dart';
import 'services/restaurant_service.dart';
import 'services/cart_service.dart';
import 'services/order_service.dart';
import 'repositories/restaurant_repository.dart';
import 'repositories/cart_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/payment_repository.dart';
import 'controllers/checkout_controller.dart';
import 'services/drop_service.dart';
import 'repositories/drop_repository.dart';
import 'models/drop_state.dart';
import 'services/dish_search_service.dart';
import 'repositories/dish_search_repository.dart';
import 'models/dish_search_state.dart';
import 'services/insights_service.dart';
import 'services/demand_gap_service.dart';
import 'repositories/demand_gap_repository.dart';
import 'services/search_privacy.dart';
import 'repositories/insights_repository.dart';
import 'models/trending_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaymentService.initialize();

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
  await SearchPrivacy.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<RestaurantRepository>(create: (_) => RestaurantService()),
        Provider<CartRepository>(create: (_) => CartService()),
        Provider<OrderRepository>(create: (_) => OrderService()),
        Provider<PaymentRepository>(create: (_) => PaymentService()),
        Provider<DropRepository>(create: (_) => DropService()),
        Provider<DishSearchRepository>(create: (_) => DishSearchService()),
        Provider<MenuTagRepository>(create: (_) => DishSearchService()),
        Provider<TrendingRepository>(create: (_) => InsightsService()),
        Provider<OwnerInsightsRepository>(create: (_) => InsightsService()),
        Provider<DemandGapRepository>(create: (_) => DemandGapService()),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => CartState()),
        ChangeNotifierProvider(
          create: (ctx) => DishSearchState(repository: ctx.read<DishSearchRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => TrendingState(repository: ctx.read<TrendingRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => DropState(
            repository: ctx.read<DropRepository>(),
            isLoggedIn: () => session.isLoggedIn,
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => CheckoutController(
            paymentRepository: ctx.read<PaymentRepository>(),
          ),
        ),
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
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const CreateAccountScreen(),
        '/intro': (context) => const DeliveryIntroScreen(),
        '/home': (context) => const HomeScreen(),
        '/restaurant': (context) => const RestaurantDetailScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/tracking': (context) => const OrderTrackingScreen(),
        '/restaurant-dashboard': (context) => const RestaurantDashboardScreen(),
        '/delivery-dashboard': (context) => const DeliveryDashboardScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/orders-history': (context) => const OrderHistoryScreen(),
        '/drop': (context) => const DropDetailScreen(),
        '/drop-checkout': (context) => const DropCheckoutScreen(),
      },
    );
  }
}

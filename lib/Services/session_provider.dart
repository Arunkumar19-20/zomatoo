// lib/Services/session_provider.dart
//
// Holds the currently logged-in user's data so any screen can read:
//   - Whether there is an active session
//   - The raw JWT token
//   - The AppUser (userId, name, email, role)
//   - The Customer profile (customerId — needed for /orders/checkout)
//
// Usage:
//   context.read<SessionProvider>().login(result);
//   context.watch<SessionProvider>().customerId

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'user_service.dart';
import '../models/models.dart';

import 'jwt_helper.dart';

class SessionProvider extends ChangeNotifier {
  AppUser? _user;
  Customer? _customer;
  bool _loadingProfile = false;
  String _selectedRole = 'CUSTOMER'; // Default role before login

  AppUser? get user => _user;
  Customer? get customer => _customer;
  bool get isLoggedIn => ApiClient.instance.isLoggedIn || _user != null;
  bool get loadingProfile => _loadingProfile;
  String get selectedRole => _selectedRole;
  String get effectiveRole => _user?.role ?? _selectedRole;

  void setSelectedRole(String role) {
    _selectedRole = role;
    notifyListeners();
  }

  /// Default email mapping to real users present in the PostgreSQL database.
  static String defaultEmailForRole(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
      case 'RESTAURANT':
        return 'arunkumar2006.d@gmail.com';
      case 'DELIVERY':
      case 'DELIVERY_PARTNER':
        return 'rahul.singh@gmail.com';
      case 'ADMIN':
        return 'admin1@zomato.com';
      case 'CUSTOMER':
      default:
        return 'aarav.sharma@gmail.com';
    }
  }

  static String defaultNameForRole(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
      case 'RESTAURANT':
        return 'Arun Kumar';
      case 'DELIVERY':
      case 'DELIVERY_PARTNER':
        return 'Rahul Singh';
      case 'ADMIN':
        return 'Admin One';
      case 'CUSTOMER':
      default:
        return 'Aarav Sharma';
    }
  }

  /// Returns the appropriate dashboard route for a given user role.
  static String routeForRole(String? role) {
    switch (role?.toUpperCase()) {
      case 'OWNER':
      case 'RESTAURANT':
        return '/restaurant-dashboard';
      case 'DELIVERY':
      case 'DELIVERY_PARTNER':
        return '/delivery-dashboard';
      case 'ADMIN':
        return '/admin-dashboard';
      case 'CUSTOMER':
      default:
        return '/home';
    }
  }

  /// The customer id stored in the backend Customer table — required for checkout.
  int? get customerId => _customer?.customerId;

  /// Sign-in using real backend HS256 tokens matching the PostgreSQL database users.
  Future<void> loginAsDemo(String role, {String? email, String? name}) async {
    final resolvedRole = role.toUpperCase();
    final resolvedEmail = email ?? defaultEmailForRole(resolvedRole);
    final resolvedName = name ?? defaultNameForRole(resolvedRole);
    final realToken = JwtHelper.generateBackendToken(resolvedEmail, resolvedRole);

    ApiClient.instance.setToken(realToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', realToken);
    await prefs.setString('auth_email', resolvedEmail);
    await prefs.setString('auth_role', resolvedRole);

    _selectedRole = resolvedRole;
    _user = AppUser(
      name: resolvedName,
      email: resolvedEmail,
      role: resolvedRole,
    );
    notifyListeners();

    // Fetch real profile details from the database
    await Future.wait([
      _fetchUserProfile(),
      _fetchCustomerProfile(),
    ]);
  }

  /// Called after a successful Google OAuth login.
  Future<void> login(String token, String email, String role) async {
    ApiClient.instance.setToken(token);

    _selectedRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_email', email);
    await prefs.setString('auth_role', role);

    // Set basic user first so the UI can render immediately.
    _user = AppUser(email: email, role: role);
    notifyListeners();

    // Fetch full profile (includes name) and customer profile in parallel.
    await Future.wait([
      _fetchUserProfile(),
      _fetchCustomerProfile(),
    ]);
  }

  /// Tries to restore a saved session from SharedPreferences.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final email = prefs.getString('auth_email');
    final role = prefs.getString('auth_role');

    if (token != null && token.isNotEmpty) {
      ApiClient.instance.setToken(token);
      if (role != null) _selectedRole = role;
      _user = AppUser(email: email, role: role);
      notifyListeners();
      await Future.wait([
        _fetchUserProfile(),
        _fetchCustomerProfile(),
      ]);
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!ApiClient.instance.isLoggedIn) return;
    try {
      final svc = UserService();
      final profile = await svc.getUserProfile();
      // Merge the fetched name/userId into the existing user, keeping
      // the role and email that came from the JWT token.
      _user = AppUser(
        userId: profile.userId,
        name: profile.name,
        email: _user?.email ?? profile.email,
        role: _user?.role ?? profile.role,
      );
      notifyListeners();
    } catch (_) {
      // Not fatal — name will fall back to email prefix in the UI.
    }
  }

  Future<void> _fetchCustomerProfile() async {
    if (!ApiClient.instance.isLoggedIn) return;
    _loadingProfile = true;
    notifyListeners();
    try {
      final svc = UserService();
      _customer = await svc.getCustomerProfile();
    } catch (_) {
      // Profile fetch may fail if role != CUSTOMER; not fatal.
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    ApiClient.instance.setToken(null);
    _user = null;
    _customer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_email');
    await prefs.remove('auth_role');
    notifyListeners();
  }
}

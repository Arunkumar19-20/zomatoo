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
    _selectedRole = normalizeRole(role);
    notifyListeners();
  }

  /// Normalizes role strings to standard keys: OWNER, DELIVERY, ADMIN, CUSTOMER.
  /// Handles aliases and typos like RESTAURANT, RESTURENT, etc.
  static String normalizeRole(String? role) {
    if (role == null) return 'CUSTOMER';
    final r = role.trim().toUpperCase();
    if (r == 'OWNER' ||
        r == 'RESTAURANT' ||
        r == 'RESTURENT' ||
        r == 'RESTAURANT_OWNER' ||
        r == 'MERCHANT') {
      return 'OWNER';
    }
    if (r == 'DELIVERY' ||
        r == 'DELIVERY_PARTNER' ||
        r == 'RIDER' ||
        r == 'DRIVER') {
      return 'DELIVERY';
    }
    if (r == 'ADMIN' || r == 'ADMINISTRATOR') {
      return 'ADMIN';
    }
    return 'CUSTOMER';
  }

  /// Default email mapping to real users present in the PostgreSQL database.
  static String defaultEmailForRole(String role) {
    final normalized = normalizeRole(role);
    switch (normalized) {
      case 'OWNER':
        return 'arunkumar2006.d@gmail.com';
      case 'DELIVERY':
        return 'rahul.singh@gmail.com';
      case 'ADMIN':
        return 'admin1@zomato.com';
      case 'CUSTOMER':
      default:
        return 'aarav.sharma@gmail.com';
    }
  }

  static String defaultNameForRole(String role) {
    final normalized = normalizeRole(role);
    switch (normalized) {
      case 'OWNER':
        return 'Arun Kumar';
      case 'DELIVERY':
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
    final normalized = normalizeRole(role);
    switch (normalized) {
      case 'OWNER':
        return '/restaurant-dashboard';
      case 'DELIVERY':
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
    final resolvedRole = normalizeRole(role);
    final resolvedEmail = email ?? defaultEmailForRole(resolvedRole);
    final resolvedName = name ?? defaultNameForRole(resolvedRole);
    final realToken = JwtHelper.generateBackendToken(resolvedEmail, resolvedRole);

    debugPrint('[AUTH] loginAsDemo → role="$resolvedRole" email="$resolvedEmail"');

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
    debugPrint('[AUTH] _user.role="${_user?.role}" _selectedRole="$_selectedRole"');
    notifyListeners();

    // Fetch real profile details from the database
    await Future.wait([
      _fetchUserProfile(),
      // Only fetch customer profile for CUSTOMER role
      if (resolvedRole == 'CUSTOMER') _fetchCustomerProfile(),
    ]);
    debugPrint('[AUTH] After profile fetch → _user.role="${_user?.role}" _selectedRole="$_selectedRole"');
  }

  /// Called after a successful Google OAuth login.
  Future<void> login(String token, String email, String role) async {
    final normRole = normalizeRole(role);
    ApiClient.instance.setToken(token);

    _selectedRole = normRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_email', email);
    await prefs.setString('auth_role', normRole);

    // Set basic user first so the UI can render immediately.
    _user = AppUser(email: email, role: normRole);
    notifyListeners();

    // Fetch full profile (includes name) and customer profile in parallel.
    await Future.wait([
      _fetchUserProfile(),
      // Only fetch customer profile for CUSTOMER role
      if (normRole == 'CUSTOMER') _fetchCustomerProfile(),
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
      // IMPORTANT: set _selectedRole BEFORE _fetchUserProfile runs so its
      // role guard (`_selectedRole.isNotEmpty ? _selectedRole : ...`) works.
      if (role != null && role.isNotEmpty) {
        _selectedRole = normalizeRole(role);
      }
      _user = AppUser(email: email, role: _selectedRole);
      notifyListeners();
      await Future.wait([
        _fetchUserProfile(),
        // Only fetch customer profile for CUSTOMER role
        if (_selectedRole == 'CUSTOMER') _fetchCustomerProfile(),
      ]);
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!ApiClient.instance.isLoggedIn) return;
    try {
      final svc = UserService();
      final profile = await svc.getUserProfile();
      // IMPORTANT: Always keep the role the user explicitly chose (_selectedRole).
      // The backend /user/profile returns the DB-stored role which may differ
      // from the role the user selected on the role-selection screen.
      // The JWT token we generate already encodes the correct chosen role,
      // so we must never let the backend response override it.
      final keptRole = _selectedRole.isNotEmpty ? _selectedRole : (_user?.role ?? profile.role);
      debugPrint('[AUTH] _fetchUserProfile: DB role="${profile.role}" keeping="$keptRole"');
      _user = AppUser(
        userId: profile.userId,
        name: profile.name,
        email: _user?.email ?? profile.email,
        role: keptRole,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[AUTH] _fetchUserProfile error: $e');
      // Not fatal — name will fall back to email prefix in the UI.
    }
  }

  Future<void> _fetchCustomerProfile() async {
    // Only valid for CUSTOMER role — other roles will get 403 from the backend
    if (!ApiClient.instance.isLoggedIn) return;
    final role = _selectedRole.isNotEmpty ? _selectedRole : (_user?.role ?? '');
    if (role != 'CUSTOMER') {
      debugPrint('[AUTH] _fetchCustomerProfile skipped for role="$role"');
      return;
    }
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


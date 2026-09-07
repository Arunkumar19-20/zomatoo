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

class SessionProvider extends ChangeNotifier {
  AppUser? _user;
  Customer? _customer;
  bool _loadingProfile = false;

  AppUser? get user => _user;
  Customer? get customer => _customer;
  bool get isLoggedIn => ApiClient.instance.isLoggedIn;
  bool get loadingProfile => _loadingProfile;

  /// The customer id stored in the backend Customer table — required for checkout.
  int? get customerId => _customer?.customerId;

  /// Called after a successful Google OAuth login.
  Future<void> login(String token, String email, String role) async {
    ApiClient.instance.setToken(token);

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

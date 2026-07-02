// lib/services/auth_service.dart
//
// High-level auth API: kicks off the Google OAuth redirect flow
// (via GoogleLoginPage), stores the resulting JWT, and attaches it to
// every future ApiClient request.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'google_login_page.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';
  static const _roleKey = 'auth_role';

  /// Loads a previously saved token (call this at app startup).
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      ApiClient.instance.setToken(token);
    }
  }

  /// Opens the Google login redirect page for the given [role]
  /// ("CUSTOMER", "OWNER", or "DELIVERY") and returns the logged-in
  /// user's info once the backend issues a token, or null if the user
  /// cancelled / it failed.
  Future<GoogleLoginResult?> loginWithGoogle(
    BuildContext context, {
    String role = 'CUSTOMER',
  }) async {
    final result = await Navigator.of(context).push<GoogleLoginResult>(
      MaterialPageRoute(builder: (_) => GoogleLoginPage(role: role)),
    );

    if (result != null) {
      ApiClient.instance.setToken(result.token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, result.token);
      await prefs.setString(_emailKey, result.email);
      await prefs.setString(_roleKey, result.role);
    }

    return result;
  }

  Future<void> logout() async {
    ApiClient.instance.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_roleKey);
  }

  bool get isLoggedIn => ApiClient.instance.isLoggedIn;
}

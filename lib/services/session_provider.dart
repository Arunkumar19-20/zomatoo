import 'package:flutter/material.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'user_service.dart';
import '../models/models.dart';

class SessionProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppUser? _user;
  Customer? _customer;
  bool _loadingProfile = false;

  SessionProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isLoggedIn) {
      // Proactive single-flight token refresh on app resume if near expiry
      if (AuthService.instance.isTokenExpired(bufferSeconds: 60)) {
        AuthService.instance.refreshToken().then((_) {
          notifyListeners();
        }).catchError((_) {});
      }
    }
  }

  AppUser? get user => _user;
  Customer? get customer => _customer;
  bool get isLoggedIn => AuthService.instance.isLoggedIn;
  bool get loadingProfile => _loadingProfile;

  int? get userId => _user?.userId ?? AuthService.instance.userId;
  int? get customerId => _customer?.customerId;
  bool get isEmailVerified => _user?.emailVerified ?? AuthService.instance.isEmailVerified;

  /// Logs in with email and password using the native Spring Boot endpoint.
  Future<void> loginWithCredentials(String email, String password) async {
    await AuthService.instance.login(email, password);
    _user = AppUser(
      userId: AuthService.instance.userId,
      name: AuthService.instance.name,
      email: AuthService.instance.email,
      role: AuthService.instance.role,
      emailVerified: AuthService.instance.isEmailVerified,
    );
    notifyListeners();

    await Future.wait([
      _fetchUserProfile(),
      if (AuthService.instance.role == 'CUSTOMER') _fetchCustomerProfile(),
    ]);
  }

  /// Called after a successful Google OAuth login or legacy redirect.
  Future<void> login(String token, String email, String role) async {
    ApiClient.instance.setToken(token);
    _user = AppUser(
      email: email,
      role: role,
      emailVerified: true,
    );
    notifyListeners();

    await Future.wait([
      _fetchUserProfile(),
      _fetchCustomerProfile(),
    ]);
  }

  /// Resends account verification email.
  Future<void> resendVerification() async {
    await AuthService.instance.resendVerification();
  }

  /// Restores session on startup from secure storage.
  Future<void> restoreSession() async {
    await AuthService.instance.restoreSession();

    if (AuthService.instance.isLoggedIn) {
      _user = AppUser(
        userId: AuthService.instance.userId,
        name: AuthService.instance.name,
        email: AuthService.instance.email,
        role: AuthService.instance.role,
        emailVerified: AuthService.instance.isEmailVerified,
      );
      notifyListeners();

      await Future.wait([
        _fetchUserProfile(),
        if (AuthService.instance.role == 'CUSTOMER') _fetchCustomerProfile(),
      ]);
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!ApiClient.instance.isLoggedIn) return;
    try {
      final svc = UserService();
      final profile = await svc.getUserProfile();
      _user = AppUser(
        userId: profile.userId,
        name: profile.name,
        email: profile.email ?? _user?.email,
        role: profile.role ?? _user?.role,
        emailVerified: profile.emailVerified,
      );
      AuthService.instance.updateEmailVerified(profile.emailVerified);
      notifyListeners();
    } catch (_) {
      // Not fatal — name and email fall back to JWT fields
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
    await AuthService.instance.logout();
    _user = null;
    _customer = null;
    notifyListeners();
  }
}

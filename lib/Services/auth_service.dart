import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'google_login_page.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kEmail = 'email';
  static const _kRole = 'role';
  static const _kName = 'name';
  static const _kEmailVerified = 'email_verified';

  String? _accessToken;
  String? _refreshToken;
  int? _userId;
  String? _email;
  String? _role;
  String? _name;
  bool _emailVerified = false;

  // Single-flight refresh future shared across all concurrent callers
  Future<String?>? _refreshFuture;

  String? get accessToken => _accessToken;
  String? get currentRefreshToken => _refreshToken;
  int? get userId => _userId;
  String? get email => _email;
  String? get role => _role;
  String? get name => _name;
  bool get isEmailVerified => _emailVerified;
  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;

  void setManualAccessToken(String token) {
    _accessToken = token;
  }

  void setTokensForTesting({String? accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// Loads saved credentials from secure storage on app launch.
  Future<void> restoreSession() async {
    try {
      _accessToken = await _storage.read(key: _kAccessToken);
      _refreshToken = await _storage.read(key: _kRefreshToken);
      final userIdStr = await _storage.read(key: _kUserId);
      _userId = userIdStr != null ? int.tryParse(userIdStr) : null;
      _email = await _storage.read(key: _kEmail);
      _role = await _storage.read(key: _kRole);
      _name = await _storage.read(key: _kName);
      final verifiedStr = await _storage.read(key: _kEmailVerified);
      _emailVerified = verifiedStr == 'true';

      // Proactively refresh if access token is expired or expiring within 60s
      if (_refreshToken != null && isTokenExpired(bufferSeconds: 60)) {
        await refreshToken();
      }
    } catch (e) {
      debugPrint('Failed to restore session from secure storage: $e');
    }
  }

  /// Checks if the current access token is expired using JWT exp claim.
  bool isTokenExpired({int bufferSeconds = 60}) {
    if (_accessToken == null || _accessToken!.isEmpty) return true;
    try {
      final parts = _accessToken!.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is int) {
        final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return DateTime.now().add(Duration(seconds: bufferSeconds)).isAfter(expDate);
      }
    } catch (_) {
      return true;
    }
    return false;
  }

  /// Single-flight token refresh. Coalesces concurrent calls into 1 HTTP request.
  Future<String?> refreshToken() {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }
    _refreshFuture = _doRefreshToken().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<String?> _doRefreshToken() async {
    final currentRefreshToken = _refreshToken;
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/auth/refresh'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/refresh'),
          statusCode: 401,
          data: {'message': 'No refresh token available'},
        ),
      );
    }

    // Must use rawDio (interceptor-free) to avoid deadlocking QueuedInterceptor
    final dio = ApiClient.instance.rawDio;
    final response = await dio.post<dynamic>(
      '/api/auth/refresh',
      data: {'refreshToken': currentRefreshToken},
    );

    final rawData = response.data;
    final Map<String, dynamic>? data = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is String ? jsonDecode(rawData) as Map<String, dynamic>? : null);

    if (data != null && data['accessToken'] != null) {
      final newAccessToken = data['accessToken'] as String;
      final newRefreshToken = data['refreshToken'] as String?;
      final userRole = data['role'] as String?;
      final userName = data['name'] as String?;
      final verified = data['emailVerified'] as bool? ?? false;
      final uid = data['userId'] as int?;

      await _saveSession(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? currentRefreshToken,
        userId: uid ?? _userId,
        email: data['email'] as String? ?? _email,
        role: userRole ?? _role,
        name: userName ?? _name,
        emailVerified: verified,
      );
      return newAccessToken;
    }
    return null;
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await ApiClient.instance.rawDio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      final data = response.data!;
      await _saveSession(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: data['userId'] as int?,
        email: data['email'] as String?,
        role: data['role'] as String?,
        name: data['name'] as String?,
        emailVerified: data['emailVerified'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.instance.rawDio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> resendVerification() async {
    try {
      await ApiClient.instance.dio.post<Map<String, dynamic>>(
        '/api/auth/resend-verification',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<GoogleLoginResult?> loginWithGoogle(
    BuildContext context, {
    String role = 'CUSTOMER',
  }) async {
    final result = await Navigator.of(context).push<GoogleLoginResult>(
      MaterialPageRoute(builder: (_) => GoogleLoginPage(role: role)),
    );

    if (result != null) {
      await _saveSession(
        accessToken: result.token,
        refreshToken: result.token, // Google login issues access token
        email: result.email,
        role: result.role,
        emailVerified: true, // Google accounts are verified by default
      );
    }

    return result;
  }

  Future<void> logout() async {
    final tokenToRevoke = _refreshToken;
    try {
      if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
        await ApiClient.instance.rawDio.post<Map<String, dynamic>>(
          '/api/auth/logout',
          data: {'refreshToken': tokenToRevoke},
        );
      }
    } catch (e) {
      debugPrint('Logout request failed (continuing local cleanup): $e');
    } finally {
      await _clearSession();
    }
  }

  Future<void> _saveSession({
    required String accessToken,
    required String refreshToken,
    int? userId,
    String? email,
    String? role,
    String? name,
    bool emailVerified = false,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userId = userId;
    _email = email;
    _role = role;
    _name = name;
    _emailVerified = emailVerified;

    try {
      await _storage.write(key: _kAccessToken, value: accessToken);
      await _storage.write(key: _kRefreshToken, value: refreshToken);
      if (userId != null) await _storage.write(key: _kUserId, value: userId.toString());
      if (email != null) await _storage.write(key: _kEmail, value: email);
      if (role != null) await _storage.write(key: _kRole, value: role);
      if (name != null) await _storage.write(key: _kName, value: name);
      await _storage.write(key: _kEmailVerified, value: emailVerified.toString());
    } catch (e) {
      debugPrint('Storage write notice: $e');
    }
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
    _role = null;
    _name = null;
    _emailVerified = false;

    try {
      await _storage.delete(key: _kAccessToken);
      await _storage.delete(key: _kRefreshToken);
      await _storage.delete(key: _kUserId);
      await _storage.delete(key: _kEmail);
      await _storage.delete(key: _kRole);
      await _storage.delete(key: _kName);
      await _storage.delete(key: _kEmailVerified);
    } catch (e) {
      debugPrint('Storage delete notice: $e');
    }
  }

  void updateEmailVerified(bool verified) {
    _emailVerified = verified;
    _storage.write(key: _kEmailVerified, value: verified.toString());
  }
}

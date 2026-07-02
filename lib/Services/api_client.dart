// lib/core/api_client.dart
//
// Central HTTP client used by every feature service. Wraps Dio with:
//  - a configurable base URL (your Spring Boot backend, default port 8080)
//  - automatic "Authorization: Bearer <token>" header once logged in
//  - shared error handling
//
// Update [baseUrl] to match where your backend is actually reachable from
// the device/emulator:
//   - Android emulator talking to localhost backend -> http://10.0.2.2:8080
//   - iOS simulator talking to localhost backend     -> http://127.0.0.1:8080
//   - Real device / deployed backend                 -> http://<your-ip-or-domain>:8080

import 'package:dio/dio.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (DioException e, handler) {
          // Centralized place to log / transform backend errors.
          handler.next(e);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  // TODO: point this at your backend's real address.
  static const String baseUrl = 'http://10.0.2.2:8080';

  late final Dio _dio;
  String? _token;

  Dio get dio => _dio;

  /// Call this once the Google OAuth flow returns a JWT (see AuthService).
  void setToken(String? token) => _token = token;

  String? get token => _token;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
}

/// Uniform exception thrown by all services below.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  factory ApiException.fromDioException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String msg;
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    } else if (data is String && data.isNotEmpty) {
      msg = data;
    } else {
      msg = e.message ?? 'Network error';
    }
    return ApiException(msg, statusCode: status);
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import 'auth_service.dart';

class ApiClient {
  ApiClient._internal() {
    final baseOptions = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    );

    // Interceptor-free Dio instance for raw calls (e.g. refresh, retries)
    _rawDio = Dio(baseOptions);

    // Main Dio instance equipped with single-flight AuthInterceptor
    _dio = Dio(baseOptions);
    _dio.interceptors.add(
      AuthInterceptor(
        rawDio: _rawDio,
        authService: AuthService.instance,
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  /// Dynamic URL configuration resolving localhost correctly based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      default:
        return 'http://localhost:8080';
    }
  }

  late final Dio _rawDio;
  late final Dio _dio;

  Dio get dio => _dio;
  Dio get rawDio => _rawDio;

  /// Backwards-compatible access to access token
  String? get token => AuthService.instance.accessToken;

  bool get isLoggedIn => AuthService.instance.isLoggedIn;

  void setToken(String? token) {
    if (token != null) {
      AuthService.instance.setManualAccessToken(token);
    }
  }
}

/// Uniform typed exception hierarchy thrown by all services.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic rawData;

  ApiException(this.message, {this.statusCode, this.code, this.rawData});

  factory ApiException.fromDioException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String msg = 'Network error';
    String? errorCode;

    if (data is Map) {
      if (data['message'] != null) {
        msg = data['message'].toString();
      } else if (data['error'] != null) {
        msg = data['error'].toString();
      }
      if (data['code'] != null) {
        errorCode = data['code'].toString();
      }
    } else if (data is String && data.isNotEmpty) {
      msg = data;
    } else if (e.message != null && e.message!.isNotEmpty) {
      msg = e.message!;
    }

    if (status == 401) {
      return UnauthorizedException(msg, rawData: data);
    }
    if (status == 403 && (errorCode == 'EMAIL_NOT_VERIFIED' || msg.toLowerCase().contains('verify your email'))) {
      return EmailNotVerifiedException(msg, rawData: data);
    }
    if (status == 429) {
      return RateLimitException(msg, rawData: data);
    }
    if (status == 404) {
      return NotFoundException(msg, rawData: data);
    }
    return ApiException(msg, statusCode: status, code: errorCode, rawData: data);
  }

  @override
  String toString() => 'ApiException($statusCode, code: $code): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message, {super.rawData}) : super(statusCode: 401, code: 'UNAUTHORIZED');
}

class EmailNotVerifiedException extends ApiException {
  EmailNotVerifiedException(super.message, {super.rawData}) : super(statusCode: 403, code: 'EMAIL_NOT_VERIFIED');
}

class RateLimitException extends ApiException {
  RateLimitException(super.message, {super.rawData}) : super(statusCode: 429, code: 'RATE_LIMIT');
}

class NotFoundException extends ApiException {
  NotFoundException(super.message, {super.rawData}) : super(statusCode: 404, code: 'NOT_FOUND');
}

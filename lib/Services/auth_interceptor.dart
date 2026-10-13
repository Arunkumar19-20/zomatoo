import 'package:dio/dio.dart';
import 'auth_service.dart';

/// Interceptor that handles bearer authentication and single-flight token refresh
/// using Dio's QueuedInterceptor to serialize concurrent requests.
class AuthInterceptor extends QueuedInterceptor {
  final Dio rawDio;
  final AuthService authService;

  AuthInterceptor({required this.rawDio, required this.authService});

  static const _unauthenticatedPaths = [
    '/api/auth/login',
    '/api/auth/register',
    '/api/auth/refresh',
    '/api/auth/forgot-password',
    '/api/auth/reset-password',
    '/api/auth/verify-email',
    '/google-login',
  ];

  bool _isWhitelisted(String path) {
    return _unauthenticatedPaths.any((p) => path.contains(p));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isWhitelisted(options.path)) {
      final token = authService.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final options = err.requestOptions;

    // Check if 401 on an authenticated route that hasn't already been retried
    if (response?.statusCode == 401 &&
        !_isWhitelisted(options.path) &&
        options.extra['_retried'] != true) {

      // Check if the token used in this request is already different from current token
      // (Happens when another concurrent request already refreshed the token while this one was queued)
      final usedAuthHeader = options.headers['Authorization'] as String?;
      final currentToken = authService.accessToken;
      final currentAuthHeader = currentToken != null ? 'Bearer $currentToken' : null;

      if (currentToken != null && usedAuthHeader != currentAuthHeader) {
        // Token was ALREADY refreshed! Retry immediately with the current token without calling refresh.
        try {
          final retryOptions = Options(
            method: options.method,
            headers: Map<String, dynamic>.from(options.headers)..['Authorization'] = currentAuthHeader,
            responseType: options.responseType,
            contentType: options.contentType,
            extra: Map<String, dynamic>.from(options.extra)..['_retried'] = true,
          );
          final res = await rawDio.request<dynamic>(
            options.path,
            data: options.data,
            queryParameters: options.queryParameters,
            options: retryOptions,
          );
          return handler.resolve(res);
        } catch (e) {
          if (e is DioException) {
            return handler.next(e);
          }
          return handler.next(err);
        }
      }

      // Tokens match: this request is the first to encounter 401, or needs a refresh
      try {
        final newAccessToken = await authService.refreshToken();
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          // Retry the request using the rawDio instance (no interceptors, avoids deadlock)
          final retryOptions = Options(
            method: options.method,
            headers: Map<String, dynamic>.from(options.headers)
              ..['Authorization'] = 'Bearer $newAccessToken',
            responseType: options.responseType,
            contentType: options.contentType,
            extra: Map<String, dynamic>.from(options.extra)..['_retried'] = true,
          );
          final res = await rawDio.request<dynamic>(
            options.path,
            data: options.data,
            queryParameters: options.queryParameters,
            options: retryOptions,
          );
          return handler.resolve(res);
        }
      } catch (refreshErr) {
        // CRITICAL SUBWAY TUNNEL SAFETY:
        // Only log out if refresh endpoint explicitly returned HTTP 401 (invalid/revoked token).
        // On connection errors, timeout, DNS failures, or 5xx: DO NOT log out. Keep credentials!
        if (refreshErr is DioException && refreshErr.response?.statusCode == 401) {
          await authService.logout();
        }
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}

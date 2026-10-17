import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/services/auth_interceptor.dart';
import 'package:tomatoo/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthInterceptor Tests', () {
    late Dio testDio;
    late Dio testRawDio;
    late AuthService authService;
    late AuthInterceptor authInterceptor;

    setUp(() {
      authService = AuthService.instance;
      authService.setManualAccessToken('initial_token');

      final baseOptions = BaseOptions(
        baseUrl: 'http://localhost:8080',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      );

      testRawDio = Dio(baseOptions);
      testDio = Dio(baseOptions);

      authInterceptor = AuthInterceptor(
        rawDio: testRawDio,
        authService: authService,
      );
      testDio.interceptors.add(authInterceptor);
    });

    test('1. Rotated token shortcut: queued request retries without refreshing again', () async {
      // Simulate that the token was already rotated to 'new_token'
      authService.setManualAccessToken('new_token');

      // Request that used 'initial_token' gets 401
      final options = RequestOptions(
        path: '/orders/1',
        headers: {'Authorization': 'Bearer initial_token'},
      );

      bool rawDioCalled = false;
      testRawDio.httpClientAdapter = _MockAdapter((req) async {
        rawDioCalled = true;
        // Verify it was retried with the NEW token
        expect(req.headers['Authorization'], 'Bearer new_token');
        expect(req.extra['_retried'], true);
        return ResponseBody.fromString('{"status":"ok"}', 200);
      });

      final handler = _CapturingErrorHandler();
      await authInterceptor.onError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
        handler,
      );

      expect(rawDioCalled, isTrue);
    });

    test('2. Retried request with _retried=true does not loop on second 401', () async {
      final options = RequestOptions(
        path: '/orders/1',
        headers: {'Authorization': 'Bearer initial_token'},
        extra: {'_retried': true},
      );

      final handler = _CapturingErrorHandler();
      await authInterceptor.onError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
        handler,
      );

      // Handler.next was called without retrying
      expect(handler.passedError, isNotNull);
      expect(handler.resolvedResponse, isNull);
    });

    test('3. Unauthenticated routes are ignored by interceptor', () async {
      final options = RequestOptions(
        path: '/api/auth/login',
        headers: {},
      );

      final handler = _CapturingErrorHandler();
      await authInterceptor.onError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
        handler,
      );

      expect(handler.passedError, isNotNull);
    });

    test('4. Offline error during refresh preserves credentials and does not log out', () async {
      // Simulate that the refresh call fails with a connection error
      ApiClient.instance.rawDio.httpClientAdapter = _MockAdapter((req) async {
        if (req.path.contains('/api/auth/refresh')) {
          throw DioException(
            requestOptions: req,
            error: 'SocketException: Connection refused',
            type: DioExceptionType.connectionError,
          );
        }
        return ResponseBody.fromString('{}', 200);
      });

      authService.setTokensForTesting(
        accessToken: 'valid_user_token',
        refreshToken: 'valid_refresh_token',
      );

      final options = RequestOptions(
        path: '/orders',
        headers: {'Authorization': 'Bearer valid_user_token'},
      );

      final handler = _CapturingErrorHandler();
      await authInterceptor.onError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
        handler,
      );

      // Verify the error was passed along
      expect(handler.passedError, isNotNull);
      // AND verify the session was NOT logged out!
      expect(authService.accessToken, 'valid_user_token');
      expect(authService.currentRefreshToken, 'valid_refresh_token');
    });

    test('5. Single-flight refresh coalesces simultaneous calls into 1 HTTP request', () async {
      int refreshNetworkCalls = 0;
      final completer = Completer<ResponseBody>();

      ApiClient.instance.rawDio.httpClientAdapter = _MockAdapter((req) {
        if (req.path.contains('/api/auth/refresh')) {
          refreshNetworkCalls++;
          return completer.future;
        }
        return Future.value(ResponseBody.fromString('{}', 200));
      });

      authService.setTokensForTesting(
        accessToken: 'token_1',
        refreshToken: 'refresh_1',
      );

      // Launch 3 refresh calls concurrently
      final future1 = authService.refreshToken();
      final future2 = authService.refreshToken();
      final future3 = authService.refreshToken();

      // Complete the network call
      completer.complete(
        ResponseBody.fromString(
          '{"accessToken":"new_single_flight_token","refreshToken":"new_refresh_token","userId":1}',
          200,
        ),
      );

      final results = await Future.wait([future1, future2, future3]);

      // All 3 callers got the exact same new token
      expect(results[0], 'new_single_flight_token');
      expect(results[1], 'new_single_flight_token');
      expect(results[2], 'new_single_flight_token');

      // Exactly 1 network call was made!
      expect(refreshNetworkCalls, 1);
    });

    test('6. Refresh returning 401 logs out the user and clears session', () async {
      ApiClient.instance.rawDio.httpClientAdapter = _MockAdapter((req) {
        if (req.path.contains('/api/auth/refresh')) {
          return Future.value(
            ResponseBody.fromString('{"message":"Invalid refresh token"}', 401),
          );
        }
        return Future.value(ResponseBody.fromString('{}', 200));
      });

      authService.setTokensForTesting(
        accessToken: 'expired_token',
        refreshToken: 'revoked_refresh_token',
      );

      final options = RequestOptions(
        path: '/orders',
        headers: {'Authorization': 'Bearer expired_token'},
      );

      final handler = _CapturingErrorHandler();
      await authInterceptor.onError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
        handler,
      );

      // Verify session was cleared
      expect(authService.accessToken, isNull);
      expect(authService.currentRefreshToken, isNull);
    });

    test('7. App-resume proactive refresh racing an in-flight 401 request coalesces to 1 refresh', () async {
      int refreshNetworkCalls = 0;
      final completer = Completer<ResponseBody>();

      ApiClient.instance.rawDio.httpClientAdapter = _MockAdapter((req) {
        if (req.path.contains('/api/auth/refresh')) {
          refreshNetworkCalls++;
          return completer.future;
        }
        return Future.value(ResponseBody.fromString('{}', 200));
      });

      authService.setTokensForTesting(
        accessToken: 'initial_token',
        refreshToken: 'valid_refresh',
      );

      // 1) Proactive refresh (e.g. app lifecycle resume) starts first
      final appResumeFuture = authService.refreshToken();

      // 2) Concurrently, an in-flight request fails with 401 and triggers onError
      final options = RequestOptions(
        path: '/orders/123',
        headers: {'Authorization': 'Bearer initial_token'},
      );

      bool retried = false;
      testRawDio.httpClientAdapter = _MockAdapter((req) async {
        retried = true;
        expect(req.headers['Authorization'], 'Bearer new_token_from_race');
        expect(req.extra['_retried'], true);
        return ResponseBody.fromString('{"status":"ok"}', 200);
      });

      final handler = _CapturingErrorHandler();
      final errorFuture = authInterceptor.onError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
        handler,
      );

      // 3) Complete the single refresh network call
      completer.complete(
        ResponseBody.fromString(
          '{"accessToken":"new_token_from_race","refreshToken":"new_refresh_from_race","userId":1}',
          200,
        ),
      );

      final appResumeToken = await appResumeFuture;
      await errorFuture;

      expect(appResumeToken, 'new_token_from_race');
      expect(refreshNetworkCalls, 1);
      expect(retried, isTrue);
      expect(handler.resolvedResponse?.statusCode, 200);
    });
  });

  group('ApiException Hierarchy Tests', () {
    test('Maps 401 to UnauthorizedException', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/orders'),
        response: Response(
          requestOptions: RequestOptions(path: '/orders'),
          statusCode: 401,
          data: {'message': 'Bad credentials'},
        ),
      );
      final apiEx = ApiException.fromDioException(dioEx);
      expect(apiEx, isA<UnauthorizedException>());
      expect(apiEx.statusCode, 401);
      expect(apiEx.message, 'Bad credentials');
    });

    test('Maps EMAIL_NOT_VERIFIED to EmailNotVerifiedException', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/orders/checkout'),
        response: Response(
          requestOptions: RequestOptions(path: '/orders/checkout'),
          statusCode: 403,
          data: {
            'status': 403,
            'message': 'Please verify your email before placing an order.',
            'code': 'EMAIL_NOT_VERIFIED',
          },
        ),
      );
      final apiEx = ApiException.fromDioException(dioEx);
      expect(apiEx, isA<EmailNotVerifiedException>());
      expect(apiEx.statusCode, 403);
      expect(apiEx.code, 'EMAIL_NOT_VERIFIED');
    });

    test('Maps 429 to RateLimitException', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          statusCode: 429,
          data: {'message': 'Too many requests'},
        ),
      );
      final apiEx = ApiException.fromDioException(dioEx);
      expect(apiEx, isA<RateLimitException>());
      expect(apiEx.statusCode, 429);
    });

    test('Maps 404 to NotFoundException', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/restaurants/999'),
        response: Response(
          requestOptions: RequestOptions(path: '/restaurants/999'),
          statusCode: 404,
          data: {'message': 'Restaurant not found'},
        ),
      );
      final apiEx = ApiException.fromDioException(dioEx);
      expect(apiEx, isA<NotFoundException>());
      expect(apiEx.statusCode, 404);
    });
  });
}

class _MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;
  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<dynamic>? requestStream, Future<void>? cancelFuture) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _CapturingErrorHandler extends ErrorInterceptorHandler {
  DioException? passedError;
  Response? resolvedResponse;

  @override
  void next(DioException err) {
    passedError = err;
  }

  @override
  void resolve(Response response) {
    resolvedResponse = response;
  }

  @override
  void reject(DioException err, [bool test = false]) {
    passedError = err;
  }
}

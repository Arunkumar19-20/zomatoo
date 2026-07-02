// lib/services/user_service.dart
// Mirrors: UserController (/user) and CustomerController (/customer)
//
// Both endpoints rely on the JWT set via ApiClient.instance.setToken(...)
// after a successful Google login (see AuthService). The customer profile
// endpoint additionally requires the token's role to be CUSTOMER.

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class UserService {
  final Dio _dio = ApiClient.instance.dio;

  /// GET /user/profile — resolved from the authenticated principal
  /// server-side; requires a valid Authorization header.
  Future<AppUser> getUserProfile() async {
    try {
      final res = await _dio.get('/user/profile');
      return AppUser.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /customer/profile — same idea, but specifically for CUSTOMER role
  /// accounts; the backend also accepts the header explicitly, so we pass
  /// it even though the Dio interceptor already attaches it globally.
  Future<Customer> getCustomerProfile() async {
    try {
      final res = await _dio.get(
        '/customer/profile',
        options: Options(headers: {
          if (ApiClient.instance.token != null)
            'Authorization': 'Bearer ${ApiClient.instance.token}',
        }),
      );
      return Customer.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

// lib/services/coupon_service.dart
// Mirrors: CouponController (/coupon)

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class CouponService {
  final Dio _dio = ApiClient.instance.dio;

  Future<Coupon> create(Coupon coupon) async {
    try {
      final res = await _dio.post('/coupon', data: coupon.toJson());
      return Coupon.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<Coupon>> getAll() async {
    try {
      final res = await _dio.get('/coupon');
      return (res.data as List).map((e) => Coupon.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<Coupon>> getActive() async {
    try {
      final res = await _dio.get('/coupon/active');
      return (res.data as List).map((e) => Coupon.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST /coupon/apply?code=&orderId= -> "Coupon applied! Discount = X"
  Future<String> apply({required String code, required int orderId}) async {
    try {
      final res = await _dio.post(
        '/coupon/apply',
        queryParameters: {'code': code, 'orderId': orderId},
      );
      return res.data.toString();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

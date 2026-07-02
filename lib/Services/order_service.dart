// lib/services/order_service.dart
// Mirrors: OrderController (/orders)

import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/models.dart';

class OrderService {
  final Dio _dio = ApiClient.instance.dio;

  /// POST /orders/checkout?cartId=&customerId=&restaurantId=
  Future<OrderModel> checkout({
    required int cartId,
    required int customerId,
    required int restaurantId,
  }) async {
    try {
      final res = await _dio.post(
        '/orders/checkout',
        queryParameters: {
          'cartId': cartId,
          'customerId': customerId,
          'restaurantId': restaurantId,
        },
      );
      return OrderModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// PUT /orders/{id}/status?status=
  /// Typical values seen in this backend: PLACED, PREPARING, OUT_FOR_DELIVERY,
  /// DELIVERED, CANCELLED (confirm exact values with your team).
  Future<OrderModel> updateStatus(int id, String status) async {
    try {
      final res = await _dio.put(
        '/orders/$id/status',
        queryParameters: {'status': status},
      );
      return OrderModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// DELETE /orders/{id} -> returns "Cancelled" or "Failed"
  Future<bool> cancel(int id) async {
    try {
      final res = await _dio.delete('/orders/$id');
      return res.data.toString() == 'Cancelled';
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

// lib/services/order_service.dart
// Mirrors: OrderController (/orders)

import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/models.dart';

class OrderService {
  final Dio _dio;

  OrderService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// POST /orders/checkout?restaurantId=
  Future<OrderResponseDTO> checkout({
    int? restaurantId,
    int? cartId,
    int? customerId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (restaurantId != null) queryParams['restaurantId'] = restaurantId;
      if (cartId != null) queryParams['cartId'] = cartId;
      if (customerId != null) queryParams['customerId'] = customerId;

      final res = await _dio.post(
        '/orders/checkout',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      return OrderResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /orders - Retrieves user's own order history
  Future<List<OrderResponseDTO>> getMyOrders() async {
    try {
      final res = await _dio.get('/orders');
      if (res.data is List) {
        return (res.data as List).map((e) => OrderResponseDTO.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /orders/{id} - Retrieves order details by ID
  Future<OrderResponseDTO> getOrderById(int id) async {
    try {
      final res = await _dio.get('/orders/$id');
      return OrderResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// PUT /orders/{id}/status?status=
  /// Typical values: PLACED, CONFIRMED, PREPARING, OUT_FOR_DELIVERY, DELIVERED, CANCELLED
  Future<OrderResponseDTO> updateStatus(int id, String status) async {
    try {
      final res = await _dio.put(
        '/orders/$id/status',
        queryParameters: {'status': status},
      );
      return OrderResponseDTO.fromJson(res.data);
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

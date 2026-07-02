// lib/services/delivery_service.dart
// Mirrors: DeliveryController (/delivery), DeliveryPartnerController
// (/api/delivery-partners), and DeliveryRatingController (/api/ratings)

import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/models.dart';

class DeliveryService {
  final Dio _dio = ApiClient.instance.dio;

  // ---- /delivery ----

  Future<DeliveryModel> getById(int id) async {
    try {
      final res = await _dio.get('/delivery/$id');
      return DeliveryModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/delivery/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<DeliveryModel> assignPartner(int deliveryId, int partnerId) async {
    try {
      final res = await _dio.put('/delivery/$deliveryId/assign/$partnerId');
      return DeliveryModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DeliveryModel>> getAll() async {
    try {
      final res = await _dio.get('/delivery');
      return (res.data as List).map((e) => DeliveryModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// NOTE: Delivery entity has nested `order` and `deliveryPartner` objects
  /// on the backend — pass whatever shape your create-delivery flow needs
  /// as a raw map here rather than through a slim model.
  Future<DeliveryModel> create(Map<String, dynamic> delivery) async {
    try {
      final res = await _dio.post('/delivery', data: delivery);
      return DeliveryModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<DeliveryModel> updateStatus(int id, String status) async {
    try {
      final res = await _dio.put('/delivery/$id/status', data: {'status': status});
      return DeliveryModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---- /api/delivery-partners ----

  Future<DeliveryPartner> createPartner(DeliveryPartner partner) async {
    try {
      final res = await _dio.post('/api/delivery-partners', data: partner.toJson());
      return DeliveryPartner.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<DeliveryPartner> getPartnerById(int id) async {
    try {
      final res = await _dio.get('/api/delivery-partners/$id');
      return DeliveryPartner.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DeliveryPartner>> getAllPartners() async {
    try {
      final res = await _dio.get('/api/delivery-partners');
      return (res.data as List).map((e) => DeliveryPartner.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<DeliveryPartner> updatePartner(int id, DeliveryPartner partner) async {
    try {
      final res = await _dio.put('/api/delivery-partners/$id', data: partner.toJson());
      return DeliveryPartner.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deletePartner(int id) async {
    try {
      await _dio.delete('/api/delivery-partners/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<bool> acceptOrder(int partnerId, int orderId) async {
    try {
      final res = await _dio.post('/api/delivery-partners/$partnerId/accept-order/$orderId');
      return res.data == true;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updatePartnerLocation(int partnerId, LocationModel location) async {
    try {
      await _dio.put('/api/delivery-partners/$partnerId/location', data: location.toJson());
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> completeDelivery(int partnerId, int orderId) async {
    try {
      await _dio.post('/api/delivery-partners/$partnerId/complete-order/$orderId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updatePartnerAvailability(int partnerId, bool isAvailable) async {
    try {
      await _dio.put(
        '/api/delivery-partners/$partnerId/availability',
        queryParameters: {'isAvailable': isAvailable},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---- /api/ratings ----

  Future<DeliveryRating> submitRating(DeliveryRating rating) async {
    try {
      final res = await _dio.post('/api/ratings', data: rating.toJson());
      return DeliveryRating.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DeliveryRating>> getAllRatings() async {
    try {
      final res = await _dio.get('/api/ratings');
      return (res.data as List).map((e) => DeliveryRating.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DeliveryRating>> getRatingsByPartner(int partnerId) async {
    try {
      final res = await _dio.get('/api/ratings/partner/$partnerId');
      return (res.data as List).map((e) => DeliveryRating.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DeliveryRating>> getRatingsByOrder(int orderId) async {
    try {
      final res = await _dio.get('/api/ratings/order/$orderId');
      return (res.data as List).map((e) => DeliveryRating.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

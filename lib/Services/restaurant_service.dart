// lib/services/restaurant_service.dart
// Mirrors: com.example.zomato.controller.RestaurantController (/restaurants)

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class RestaurantService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<Restaurant>> getAll() async {
    try {
      final res = await _dio.get('/restaurants');
      return (res.data as List).map((e) => Restaurant.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Restaurant> getById(int id) async {
    try {
      final res = await _dio.get('/restaurants/$id');
      return Restaurant.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Restaurant> create(Restaurant restaurant) async {
    try {
      final res = await _dio.post('/restaurants', data: restaurant.toJson());
      return Restaurant.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Restaurant> update(int id, Restaurant restaurant) async {
    try {
      final res = await _dio.put('/restaurants/$id', data: restaurant.toJson());
      return Restaurant.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/restaurants/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<Restaurant>> getByLocation(int locationId) async {
    try {
      final res = await _dio.get('/restaurants/location/$locationId');
      return (res.data as List).map((e) => Restaurant.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<Restaurant>> getOpenRestaurants() async {
    try {
      final res = await _dio.get('/restaurants/open');
      return (res.data as List).map((e) => Restaurant.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<Restaurant>> getByRating(double rating) async {
    try {
      final res = await _dio.get('/restaurants/rating/$rating');
      return (res.data as List).map((e) => Restaurant.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updateStatus(int id, bool isOpen) async {
    try {
      await _dio.put('/restaurants/$id/status', queryParameters: {'isOpen': isOpen});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> addMenuItem(MenuItem item) async {
    try {
      await _dio.post('/restaurants/menu-item', data: item.toJson());
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> removeMenuItem(int itemId) async {
    try {
      await _dio.delete('/restaurants/menu-item/$itemId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

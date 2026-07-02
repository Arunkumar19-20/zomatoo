// lib/services/location_service.dart
// Mirrors: LocationController (/locations)

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class LocationService {
  final Dio _dio = ApiClient.instance.dio;

  Future<LocationModel> create(LocationModel location) async {
    try {
      final res = await _dio.post('/locations', data: location.toJson());
      return LocationModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<LocationModel>> getAll() async {
    try {
      final res = await _dio.get('/locations');
      return (res.data as List).map((e) => LocationModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<LocationModel> getById(int id) async {
    try {
      final res = await _dio.get('/locations/$id');
      return LocationModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<LocationModel> update(int id, LocationModel location) async {
    try {
      final res = await _dio.put('/locations/$id', data: location.toJson());
      return LocationModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/locations/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

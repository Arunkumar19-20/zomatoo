// lib/services/notification_service.dart
// Mirrors: NotificationController (/api/notifications)

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class NotificationApiService {
  final Dio _dio = ApiClient.instance.dio;

  Future<NotificationModel> send(NotificationModel notification) async {
    try {
      final res = await _dio.post('/api/notifications', data: notification.toJson());
      return NotificationModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<NotificationModel> getById(int id) async {
    try {
      final res = await _dio.get('/api/notifications/$id');
      return NotificationModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<NotificationModel>> getByUser(int userId) async {
    try {
      final res = await _dio.get('/api/notifications/user/$userId');
      return (res.data as List).map((e) => NotificationModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<NotificationModel>> getUnread(int userId) async {
    try {
      final res = await _dio.get('/api/notifications/user/$userId/unread');
      return (res.data as List).map((e) => NotificationModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<NotificationModel> markAsRead(int id) async {
    try {
      final res = await _dio.put('/api/notifications/$id/read');
      return NotificationModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/api/notifications/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

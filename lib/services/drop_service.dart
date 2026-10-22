// lib/services/drop_service.dart
// Mirrors: DropController (/drops)

import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/drop_models.dart';
import '../repositories/drop_repository.dart';

class DropService implements DropRepository {
  final Dio _dio;

  DropService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) parse) {
    if (data is! List) return const [];
    return data.map((e) => parse(e as Map<String, dynamic>)).toList();
  }

  /// GET /drops - upcoming and live drops
  @override
  Future<List<DropDto>> getDrops() async {
    try {
      final res = await _dio.get('/drops');
      return _list(res.data, DropDto.fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /drops/{id}
  @override
  Future<DropDto> getDrop(int id) async {
    try {
      final res = await _dio.get('/drops/$id');
      return DropDto.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST /drops/{id}/reserve -> 201 (new hold) or 200 (existing hold)
  @override
  Future<ReservationDto> reserve(int dropId) async {
    try {
      final res = await _dio.post('/drops/$dropId/reserve');
      return ReservationDto.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// DELETE /drops/reservations/{id}
  @override
  Future<void> release(int reservationId) async {
    try {
      await _dio.delete('/drops/reservations/$reservationId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /drops/reservations/mine - HELD (not expired) and CONFIRMED reservations
  @override
  Future<List<ReservationDto>> getMyReservations() async {
    try {
      final res = await _dio.get('/drops/reservations/mine');
      return _list(res.data, ReservationDto.fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST /drops/{id}/waitlist
  @override
  Future<WaitlistEntryDto> joinWaitlist(int dropId) async {
    try {
      final res = await _dio.post('/drops/$dropId/waitlist');
      return WaitlistEntryDto.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// DELETE /drops/{id}/waitlist
  @override
  Future<void> leaveWaitlist(int dropId) async {
    try {
      await _dio.delete('/drops/$dropId/waitlist');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /drops/waitlist/mine
  @override
  Future<List<WaitlistEntryDto>> getMyWaitlist() async {
    try {
      final res = await _dio.get('/drops/waitlist/mine');
      return _list(res.data, WaitlistEntryDto.fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

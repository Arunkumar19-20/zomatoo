// lib/services/insights_service.dart
// Mirrors: SearchController (/search/trending) and OwnerInsightsController (/owner/insights)

import 'package:dio/dio.dart';
import 'api_client.dart';
import 'search_area.dart';
import '../models/insights_models.dart';
import '../repositories/insights_repository.dart';

class InsightsService implements TrendingRepository, OwnerInsightsRepository {
  final Dio _dio;

  InsightsService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// GET /search/trending?limit=
  @override
  Future<List<TrendingChip>> trending({int limit = 6}) async {
    try {
      final area = SearchArea.current;
      final res = await _dio.get('/search/trending', queryParameters: {'limit': limit, if (area != null) 'area': area});
      return (res.data as List).map((e) => TrendingChip.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /owner/insights
  @override
  Future<OwnerInsights> load() async {
    try {
      final res = await _dio.get('/owner/insights');
      return OwnerInsights.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> dismiss(int id) => _post('/owner/insights/$id/dismiss');

  @override
  Future<void> snooze(int id) => _post('/owner/insights/$id/snooze');

  @override
  Future<void> acted(int id) => _post('/owner/insights/$id/acted');

  /// POST /owner/insights/{id}/drop
  @override
  Future<int> createDrop(int id, {String? title, int? totalSlots}) async {
    try {
      final res = await _dio.post('/owner/insights/$id/drop', data: {
        if (title != null) 'title': title,
        if (totalSlots != null) 'totalSlots': totalSlots,
      });
      return ((res.data as Map<String, dynamic>)['id'] as num).toInt();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> _post(String path) async {
    try {
      await _dio.post(path);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

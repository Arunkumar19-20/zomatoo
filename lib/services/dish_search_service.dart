// lib/services/dish_search_service.dart
// Mirrors: SearchController (/search) and MenuItemTagController (/menu-items/flavor-tags, /suggest-tags)

import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/dish_search_models.dart';
import '../repositories/dish_search_repository.dart';
import 'search_client_id.dart';

class DishSearchService implements DishSearchRepository, MenuTagRepository {
  final Dio _dio;

  DishSearchService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// GET /search/dishes?q=&k=&veg=&maxPrice=
  @override
  Future<DishSearchResponse> search(String query, {int k = 10, bool? veg, double? maxPrice}) async {
    try {
      final res = await _dio.get('/search/dishes',
          queryParameters: {
            'q': query,
            'k': k,
            if (veg != null) 'veg': veg,
            if (maxPrice != null) 'maxPrice': maxPrice,
          },
          options: Options(headers: {'X-Search-Client': await SearchClientId.get()}));
      return DishSearchResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST /search/events/{searchId}/click (public; the server accepts it only for a dish that search showed)
  @override
  Future<void> reportClick(String searchId, int itemId, int rank, {String action = 'OPEN'}) async {
    try {
      await _dio.post('/search/events/$searchId/click',
          data: {'itemId': itemId, 'rank': rank, 'action': action},
          options: Options(headers: {'X-Search-Client': await SearchClientId.get()}));
    } catch (_) {
      // analytics must never get in the way of the customer
    }
  }

  /// GET /menu-items/flavor-tags
  @override
  Future<List<FlavorInfo>> flavorTags() async {
    try {
      final res = await _dio.get('/menu-items/flavor-tags');
      return (res.data as List).map((e) => FlavorInfo.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST /menu-items/suggest-tags (owner or admin)
  @override
  Future<List<TagSuggestion>> suggest({required String name, String? description, String? ingredients, String? categoryName}) async {
    try {
      final res = await _dio.post('/menu-items/suggest-tags', data: {
        'name': name,
        'description': description,
        'ingredients': ingredients,
        'categoryName': categoryName,
      });
      final list = (res.data as Map<String, dynamic>)['suggestions'] as List? ?? const [];
      return list.map((e) => TagSuggestion.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

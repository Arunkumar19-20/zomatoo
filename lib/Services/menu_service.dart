// lib/services/menu_service.dart
// Mirrors: MenuCategoryController (/categories) and MenuItemController (/menu-items)

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class MenuService {
  final Dio _dio = ApiClient.instance.dio;

  // ---- Categories ----

  Future<List<MenuCategory>> getAllCategories() async {
    try {
      final res = await _dio.get('/categories');
      return (res.data as List).map((e) => MenuCategory.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MenuCategory> getCategoryById(int id) async {
    try {
      final res = await _dio.get('/categories/$id');
      return MenuCategory.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<MenuCategory>> getCategoriesByRestaurant(int restaurantId) async {
    try {
      final res = await _dio.get('/categories/restaurant/$restaurantId');
      return (res.data as List).map((e) => MenuCategory.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MenuCategory> createCategory(int restaurantId, MenuCategory category) async {
    try {
      final res = await _dio.post('/categories/$restaurantId', data: category.toJson());
      return MenuCategory.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MenuCategory> updateCategory(int id, MenuCategory category) async {
    try {
      final res = await _dio.put('/categories/$id', data: category.toJson());
      return MenuCategory.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _dio.delete('/categories/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> addItemToCategory(MenuItem item) async {
    try {
      await _dio.post('/categories/add-item', data: item.toJson());
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> removeItemFromCategory(int itemId) async {
    try {
      await _dio.delete('/categories/remove-item/$itemId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---- Menu items ----

  Future<MenuItem> saveItem(MenuItem item) async {
    try {
      final res = await _dio.post('/menu-items', data: item.toJson());
      return MenuItem.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<MenuItem>> getAllItems() async {
    try {
      final res = await _dio.get('/menu-items');
      return (res.data as List).map((e) => MenuItem.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MenuItem> getItemById(int id) async {
    try {
      final res = await _dio.get('/menu-items/$id');
      return MenuItem.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await _dio.delete('/menu-items/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MenuItem> updateItem(int id, MenuItem item) async {
    try {
      final res = await _dio.put('/menu-items/$id', data: item.toJson());
      return MenuItem.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updatePrice(int id, double price) async {
    try {
      await _dio.put('/menu-items/$id/price', queryParameters: {'price': price});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> toggleAvailability(int id) async {
    try {
      await _dio.put('/menu-items/$id/toggle');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

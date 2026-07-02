// lib/services/cart_service.dart
// Mirrors: CartController (/cart) and CartItemController (/cart-items)

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class CartService {
  final Dio _dio = ApiClient.instance.dio;

  // ---- /cart ----

  Future<CartModel> createCart(CartModel cart) async {
    try {
      final res = await _dio.post('/cart', data: cart.toJson());
      return CartModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CartModel> getCart(int id) async {
    try {
      final res = await _dio.get('/cart/$id');
      return CartModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Convenience endpoint on CartController: POST /cart/add
  Future<CartItemModel> addItemViaCart(CartItemModel item) async {
    try {
      final res = await _dio.post('/cart/add', data: item.toJson());
      return CartItemModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<CartItemModel>> getItemsForCart(int cartId) async {
    try {
      final res = await _dio.get('/cart/items/$cartId');
      return (res.data as List).map((e) => CartItemModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteCartItem(int id) async {
    try {
      await _dio.delete('/cart/item/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> clearCartViaCart(int cartId) async {
    try {
      await _dio.delete('/cart/clear/$cartId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---- /cart-items ----

  Future<CartItemModel> addItem(CartItemModel item) async {
    try {
      final res = await _dio.post('/cart-items', data: item.toJson());
      return CartItemModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<CartItemModel>> getItemsByCart(int cartId) async {
    try {
      final res = await _dio.get('/cart-items/cart/$cartId');
      return (res.data as List).map((e) => CartItemModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CartItemModel> getItem(int id) async {
    try {
      final res = await _dio.get('/cart-items/$id');
      return CartItemModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CartItemModel> updateItem(int id, CartItemModel item) async {
    try {
      final res = await _dio.put('/cart-items/$id', data: item.toJson());
      return CartItemModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await _dio.delete('/cart-items/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> clearCart(int cartId) async {
    try {
      await _dio.delete('/cart-items/cart/$cartId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

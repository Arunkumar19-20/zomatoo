// lib/services/cart_service.dart
// Mirrors: CartController (/cart) and CartItemController (/cart-items)

import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/models.dart';

class CartService {
  final Dio _dio = ApiClient.instance.dio;

  // ---- Modern Authenticated Endpoints (CartController) ----

  /// GET /cart - Retrieves current user's cart
  Future<CartResponseDTO> getMyCart() async {
    try {
      final res = await _dio.get('/cart');
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST /cart/items - Adds menu item to cart
  Future<CartResponseDTO> addItem({required int menuItemId, int quantity = 1}) async {
    try {
      final res = await _dio.post('/cart/items', data: {
        'menuItemId': menuItemId,
        'quantity': quantity,
      });
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// PUT /cart/items/{cartItemId} - Updates quantity of an existing cart item
  Future<CartResponseDTO> updateQuantity(int cartItemId, int quantity) async {
    try {
      final res = await _dio.put(
        '/cart/items/$cartItemId',
        data: {'quantity': quantity},
      );
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// DELETE /cart/items/{cartItemId} - Removes an item from cart
  Future<CartResponseDTO> removeItem(int cartItemId) async {
    try {
      final res = await _dio.delete('/cart/items/$cartItemId');
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// DELETE /cart - Clears entire cart for authenticated user
  Future<CartResponseDTO> clearCart() async {
    try {
      final res = await _dio.delete('/cart');
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---- /cart legacy ----

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

  Future<CartItemModel> addCartItemLegacy(CartItemModel item) async {
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

  Future<void> clearCartItemsLegacy(int cartId) async {
    try {
      await _dio.delete('/cart-items/cart/$cartId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

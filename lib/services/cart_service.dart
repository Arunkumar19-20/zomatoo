// lib/services/cart_service.dart
// Mirrors: CartController (/cart) and CartItemController (/cart-items)

import 'package:dio/dio.dart';
import 'api_client.dart';
import 'search_attribution.dart';
import 'search_client_id.dart';
import '../models/models.dart';
import '../repositories/cart_repository.dart';

class CartService implements CartRepository {
  final Dio _dio;

  final SearchAttribution _attribution;

  CartService({Dio? dio, SearchAttribution? attribution})
      : _dio = dio ?? ApiClient.instance.dio,
        _attribution = attribution ?? SearchAttribution.instance;

  // ---- Modern Authenticated Endpoints (CartController) ----

  /// GET /cart - Retrieves current user's cart
  @override
  Future<CartResponseDTO> getMyCart() async {
    try {
      final res = await _dio.get('/cart');
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST /cart/items - Adds menu item to cart
  @override
  Future<CartResponseDTO> addItem({required int menuItemId, int quantity = 1}) async {
    // when this dish was opened from search results, say which search (the server checks it and keeps only the phrase, briefly)
    final fromSearch = _attribution.peek(menuItemId);
    try {
      final res = await _dio.post(
        '/cart/items',
        data: {
          'menuItemId': menuItemId,
          'quantity': quantity,
          if (fromSearch != null) 'searchId': fromSearch.searchId,
          if (fromSearch != null) 'searchRank': fromSearch.rank,
        },
        options: fromSearch == null ? null : Options(headers: {'X-Search-Client': await SearchClientId.get()}),
      );
      if (fromSearch != null) _attribution.forget(menuItemId);
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// PUT /cart/items/{cartItemId} - Updates quantity of an existing cart item
  @override
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
  @override
  Future<CartResponseDTO> removeItem(int cartItemId) async {
    try {
      final res = await _dio.delete('/cart/items/$cartItemId');
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// DELETE /cart - Clears entire cart for authenticated user
  @override
  Future<CartResponseDTO> clearCart() async {
    try {
      final res = await _dio.delete('/cart');
      return CartResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---- /cart legacy ----

  @override
  Future<CartModel> createCart(CartModel cart) async {
    try {
      final res = await _dio.post('/cart', data: cart.toJson());
      return CartModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<CartModel> getCart(int id) async {
    try {
      final res = await _dio.get('/cart/$id');
      return CartModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Convenience endpoint on CartController: POST /cart/add
  @override
  Future<CartItemModel> addItemViaCart(CartItemModel item) async {
    try {
      final res = await _dio.post('/cart/add', data: item.toJson());
      return CartItemModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<List<CartItemModel>> getItemsForCart(int cartId) async {
    try {
      final res = await _dio.get('/cart/items/$cartId');
      return (res.data as List).map((e) => CartItemModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> deleteCartItem(int id) async {
    try {
      await _dio.delete('/cart/item/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> clearCartViaCart(int cartId) async {
    try {
      await _dio.delete('/cart/clear/$cartId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---- /cart-items ----

  @override
  Future<CartItemModel> addCartItemLegacy(CartItemModel item) async {
    try {
      final res = await _dio.post('/cart-items', data: item.toJson());
      return CartItemModel.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
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

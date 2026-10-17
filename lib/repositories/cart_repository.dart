import '../models/models.dart';

abstract class CartRepository {
  Future<CartResponseDTO> getMyCart();

  Future<CartResponseDTO> addItem({required int menuItemId, int quantity = 1});

  Future<CartResponseDTO> updateQuantity(int cartItemId, int quantity);

  Future<CartResponseDTO> removeItem(int cartItemId);

  Future<CartResponseDTO> clearCart();

  // Legacy endpoints supported by CartService
  Future<CartModel> createCart(CartModel cart);

  Future<CartModel> getCart(int id);

  Future<CartItemModel> addItemViaCart(CartItemModel item);

  Future<List<CartItemModel>> getItemsForCart(int cartId);

  Future<void> deleteCartItem(int id);

  Future<void> clearCartViaCart(int cartId);

  Future<CartItemModel> addCartItemLegacy(CartItemModel item);

  Future<List<CartItemModel>> getItemsByCart(int cartId);
}

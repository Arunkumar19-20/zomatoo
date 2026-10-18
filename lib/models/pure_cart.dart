import 'food_item.dart';

class CartItem {
  final FoodItem foodItem;
  int quantity;
  int? backendCartItemId;

  CartItem({
    required this.foodItem,
    this.quantity = 1,
    this.backendCartItemId,
  });

  double get totalPrice => foodItem.price * quantity;
}

/// Pure business logic for cart calculation and restaurant restriction rules.
/// Completely decoupled from network, Flutter UI, and asynchronous server sync.
class PureCart {
  final List<CartItem> _items = [];
  Restaurant? _activeRestaurant;

  List<CartItem> get items => List.unmodifiable(_items);
  Restaurant? get activeRestaurant => _activeRestaurant;

  int get totalItemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee {
    if (_activeRestaurant == null) return 0.0;
    return _activeRestaurant!.deliveryFee;
  }

  double get serviceFee {
    if (_items.isEmpty) return 0.0;
    if (_activeRestaurant?.id == 'rest1') return 567.99;
    return 25.00;
  }

  double get total {
    if (_items.isEmpty) return 0.0;
    return subtotal + deliveryFee + serviceFee;
  }

  int getItemQuantity(FoodItem item) {
    final index = _items.indexWhere((element) => element.foodItem.id == item.id);
    return index >= 0 ? _items[index].quantity : 0;
  }

  /// Adds an item. Returns true if adding required clearing the cart due to restaurant mismatch.
  bool addItem(FoodItem item, Restaurant restaurant) {
    bool restaurantSwitched = false;
    if (_activeRestaurant != null && _activeRestaurant!.id != restaurant.id) {
      _items.clear();
      restaurantSwitched = true;
    }
    _activeRestaurant = restaurant;

    final existingIndex = _items.indexWhere((element) => element.foodItem.id == item.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(foodItem: item));
    }
    return restaurantSwitched;
  }

  /// Decrements quantity or removes if quantity reaches 0.
  /// Returns the affected CartItem (or null if not found), and whether it was completely removed.
  ({CartItem? item, bool wasRemoved}) removeItem(FoodItem item) {
    final existingIndex = _items.indexWhere((element) => element.foodItem.id == item.id);
    if (existingIndex < 0) return (item: null, wasRemoved: false);

    final cartItem = _items[existingIndex];
    if (cartItem.quantity > 1) {
      cartItem.quantity--;
      return (item: cartItem, wasRemoved: false);
    } else {
      final removed = _items.removeAt(existingIndex);
      if (_items.isEmpty) {
        _activeRestaurant = null;
      }
      return (item: removed, wasRemoved: true);
    }
  }

  /// Removes an item completely regardless of its quantity.
  CartItem? deleteItem(FoodItem item) {
    final existingIndex = _items.indexWhere((element) => element.foodItem.id == item.id);
    if (existingIndex >= 0) {
      final removed = _items.removeAt(existingIndex);
      if (_items.isEmpty) {
        _activeRestaurant = null;
      }
      return removed;
    }
    return null;
  }

  void clear() {
    _items.clear();
    _activeRestaurant = null;
  }

  /// Sets raw items and active restaurant (e.g. from backend sync)
  void setItems(List<CartItem> newItems, Restaurant? restaurant) {
    _items.clear();
    _items.addAll(newItems);
    _activeRestaurant = newItems.isEmpty ? null : restaurant;
  }
}

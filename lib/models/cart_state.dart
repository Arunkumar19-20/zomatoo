import 'dart:async';
import 'package:flutter/material.dart';
import 'food_item.dart';
import '../models/models.dart' as models;
import '../services/order_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

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

enum OrderStatus { preparing, onTheWay, delivered }

class CartState extends ChangeNotifier {
  final List<CartItem> _items = [];
  Restaurant? _activeRestaurant;

  // Services
  final CartService _cartService = CartService();
  final OrderService _orderService = OrderService();

  // Checkout Details
  String _deliveryAddress = "123 Foodie Lane, Gourmet City";
  String _paymentMethod = "Credit Card";

  // Backend IDs & Models (set after login + checkout)
  int? _backendCartId;
  int? _backendOrderId;
  models.OrderResponseDTO? _lastCreatedOrder;

  // Tracking Simulation
  OrderStatus _currentStatus = OrderStatus.preparing;
  Timer? _statusTimer;
  int _simulationSecondsRemaining = 30;

  // Recent Order Storage (so we can clear the cart after ordering)
  final List<CartItem> _recentOrderItems = [];
  Restaurant? _recentOrderRestaurant;
  double _recentOrderSubtotal = 0.0;
  double _recentOrderDeliveryFee = 0.0;
  double _recentOrderServiceFee = 0.0;
  double _recentOrderTotal = 0.0;

  // Checkout state
  bool _isPlacingOrder = false;
  String? _orderError;
  bool _isEmailNotVerified = false;

  List<CartItem> get items => List.unmodifiable(_items);
  Restaurant? get activeRestaurant => _activeRestaurant;

  String get deliveryAddress => _deliveryAddress;
  String get paymentMethod => _paymentMethod;
  OrderStatus get currentStatus => _currentStatus;
  int get simulationSecondsRemaining => _simulationSecondsRemaining;
  int? get backendCartId => _backendCartId;
  int? get backendOrderId => _backendOrderId;
  models.OrderResponseDTO? get lastCreatedOrder => _lastCreatedOrder;
  bool get isPlacingOrder => _isPlacingOrder;
  String? get orderError => _orderError;
  bool get isEmailNotVerified => _isEmailNotVerified;

  List<CartItem> get recentOrderItems => List.unmodifiable(_recentOrderItems);
  Restaurant? get recentOrderRestaurant => _recentOrderRestaurant;
  double get recentOrderSubtotal => _recentOrderSubtotal;
  double get recentOrderDeliveryFee => _recentOrderDeliveryFee;
  double get recentOrderServiceFee => _recentOrderServiceFee;
  double get recentOrderTotal => _recentOrderTotal;

  // Setters for Checkout Details
  void setDeliveryAddress(String newAddress) {
    _deliveryAddress = newAddress;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setBackendCartId(int id) {
    _backendCartId = id;
    notifyListeners();
  }

  /// Synchronizes local cart with the backend database
  Future<void> syncWithBackend() async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final cartRes = await _cartService.getMyCart();
      _backendCartId = cartRes.cartId;

      _items.clear();
      for (final itemDto in cartRes.items) {
        _items.add(CartItem(
          foodItem: FoodItem(
            id: 'item_${itemDto.itemId ?? itemDto.id}',
            name: itemDto.name ?? 'Item',
            description: '',
            price: itemDto.price ?? 0.0,
            imageUrl: itemDto.imageUrl ??
                'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&auto=format&fit=crop&q=60',
            category: itemDto.isVeg == true ? 'Veg' : 'Non-Veg',
            rating: 4.5,
            backendItemId: itemDto.itemId,
          ),
          quantity: itemDto.quantity,
          backendCartItemId: itemDto.id,
        ));
      }

      if (cartRes.restaurantName != null || cartRes.restaurantId != null) {
        _activeRestaurant = Restaurant(
          id: 'rest_${cartRes.restaurantId ?? 0}',
          name: cartRes.restaurantName ?? 'Restaurant',
          imageUrl:
              'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=60',
          rating: 4.5,
          deliveryTime: '25-35 min',
          deliveryFee: 29.0,
          cuisineTags: ['Fast Food'],
          menu: [],
          backendId: cartRes.restaurantId,
        );
      } else if (_items.isEmpty) {
        _activeRestaurant = null;
      }
      notifyListeners();
    } catch (_) {
      // Retain offline / local state if backend sync fails
    }
  }

  // Backend sync helpers
  void _syncClearCart() {
    if (!AuthService.instance.isLoggedIn) return;
    _cartService.clearCart().then((_) {}, onError: (_) {});
  }

  void _syncUpdateQuantity(int cartItemId, int quantity) {
    if (!AuthService.instance.isLoggedIn) return;
    _cartService.updateQuantity(cartItemId, quantity).then((_) {}, onError: (_) {});
  }

  void _syncRemoveItem(int cartItemId) {
    if (!AuthService.instance.isLoggedIn) return;
    _cartService.removeItem(cartItemId).then((_) {}, onError: (_) {});
  }

  void _syncAddItem(CartItem cartItem, int menuItemId) {
    if (!AuthService.instance.isLoggedIn) return;
    _cartService.addItem(menuItemId: menuItemId, quantity: 1).then((res) {
      _backendCartId = res.cartId;
      final match = res.items.firstWhere(
        (i) => i.itemId == menuItemId,
        orElse: () => models.CartItemDTO(),
      );
      if (match.id != null) {
        cartItem.backendCartItemId = match.id;
      }
    }, onError: (_) {});
  }

  // Cart Operations
  void addItem(FoodItem item, Restaurant restaurant) {
    // If adding item from a different restaurant, clear the cart first
    if (_activeRestaurant != null && _activeRestaurant!.id != restaurant.id) {
      _items.clear();
      _backendCartId = null;
      _syncClearCart();
    }
    _activeRestaurant = restaurant;

    final existingIndex = _items.indexWhere((element) => element.foodItem.id == item.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
      final cartItem = _items[existingIndex];
      if (cartItem.backendCartItemId != null) {
        _syncUpdateQuantity(cartItem.backendCartItemId!, cartItem.quantity);
      }
    } else {
      final newCartItem = CartItem(foodItem: item);
      _items.add(newCartItem);
      if (item.backendItemId != null) {
        _syncAddItem(newCartItem, item.backendItemId!);
      }
    }
    notifyListeners();
  }

  void removeItem(FoodItem item) {
    final existingIndex = _items.indexWhere((element) => element.foodItem.id == item.id);
    if (existingIndex >= 0) {
      final cartItem = _items[existingIndex];
      if (cartItem.quantity > 1) {
        cartItem.quantity--;
        if (cartItem.backendCartItemId != null) {
          _syncUpdateQuantity(cartItem.backendCartItemId!, cartItem.quantity);
        }
      } else {
        final removed = _items.removeAt(existingIndex);
        if (removed.backendCartItemId != null) {
          _syncRemoveItem(removed.backendCartItemId!);
        }
      }
    }
    if (_items.isEmpty) {
      _activeRestaurant = null;
    }
    notifyListeners();
  }

  void deleteItem(FoodItem item) {
    final existingIndex = _items.indexWhere((element) => element.foodItem.id == item.id);
    if (existingIndex >= 0) {
      final removed = _items.removeAt(existingIndex);
      if (removed.backendCartItemId != null) {
        _syncRemoveItem(removed.backendCartItemId!);
      }
    }
    if (_items.isEmpty) {
      _activeRestaurant = null;
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _activeRestaurant = null;
    _backendCartId = null;
    _syncClearCart();
    notifyListeners();
  }

  int getItemQuantity(FoodItem item) {
    final index = _items.indexWhere((element) => element.foodItem.id == item.id);
    return index >= 0 ? _items[index].quantity : 0;
  }

  int get totalItemCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  // Calculations
  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get deliveryFee {
    if (_activeRestaurant == null) return 0.0;
    return _activeRestaurant!.deliveryFee;
  }

  double get serviceFee {
    if (_items.isEmpty) return 0.0;
    if (_activeRestaurant?.id == "rest1") return 567.99;
    return 25.00;
  }

  double get total {
    if (_items.isEmpty) return 0.0;
    return subtotal + deliveryFee + serviceFee;
  }

  /// Places the order — calls backend checkout if authenticated,
  /// otherwise falls back to local simulation.
  Future<bool> placeOrder({int? customerId, int? restaurantId}) async {
    // Reset order tracking simulation state
    _statusTimer?.cancel();
    _currentStatus = OrderStatus.preparing;
    _simulationSecondsRemaining = 25;
    _backendOrderId = null;
    _lastCreatedOrder = null;
    _orderError = null;
    _isEmailNotVerified = false;

    _recentOrderItems.clear();
    _recentOrderItems.addAll(_items);
    _recentOrderRestaurant = _activeRestaurant;
    _recentOrderSubtotal = subtotal;
    _recentOrderDeliveryFee = deliveryFee;
    _recentOrderServiceFee = serviceFee;
    _recentOrderTotal = total;

    // Authenticated checkout against backend
    if (AuthService.instance.isLoggedIn) {
      _isPlacingOrder = true;
      notifyListeners();

      try {
        final order = await _orderService.checkout(
          restaurantId: restaurantId ?? _activeRestaurant?.backendId,
        );
        _backendOrderId = order.orderId;
        _lastCreatedOrder = order;
        _isPlacingOrder = false;
        startOrderSimulation();
        clearCart();
        notifyListeners();
        return true;
      } on EmailNotVerifiedException catch (e) {
        _isEmailNotVerified = true;
        _orderError = e.message;
        _isPlacingOrder = false;
        notifyListeners();
        return false;
      } on ApiException catch (e) {
        _orderError = e.message;
        _isPlacingOrder = false;
        notifyListeners();
        return false;
      } catch (e) {
        _orderError = e.toString();
        _isPlacingOrder = false;
        notifyListeners();
        return false;
      }
    }

    // Fallback: local simulation for guest/mock mode
    startOrderSimulation();
    clearCart();
    return true;
  }

  // Tracking Simulation
  void startOrderSimulation() {
    _statusTimer?.cancel();
    _currentStatus = OrderStatus.preparing;
    _simulationSecondsRemaining = 25;
    notifyListeners();

    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_simulationSecondsRemaining > 0) {
        _simulationSecondsRemaining--;
        if (_simulationSecondsRemaining == 15) {
          _currentStatus = OrderStatus.onTheWay;
        } else if (_simulationSecondsRemaining == 0) {
          _currentStatus = OrderStatus.delivered;
          _statusTimer?.cancel();
        }
        notifyListeners();
      } else {
        _statusTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
}

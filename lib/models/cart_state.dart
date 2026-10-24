import 'dart:async';
import 'package:flutter/material.dart';
import 'food_item.dart';
import '../Services/order_service.dart';
import '../Services/cart_service.dart';
import 'models.dart' as api;

class CartItem {
  final FoodItem foodItem;
  int quantity;

  CartItem({
    required this.foodItem,
    this.quantity = 1,
  });

  double get totalPrice => foodItem.price * quantity;
}

enum OrderStatus { preparing, onTheWay, delivered }

class CartState extends ChangeNotifier {
  final List<CartItem> _items = [];
  Restaurant? _activeRestaurant;

  // Checkout Details
  String _deliveryAddress = "123 Foodie Lane, Gourmet City";
  String _paymentMethod = "Credit Card";

  // Backend IDs (set after login + checkout)
  int? _backendCartId;
  int? _backendOrderId;
  int? _backendRestaurantId;
  bool _isSyncingCart = false;

  // Real-Time Delivery Tracking State
  OrderStatus _currentStatus = OrderStatus.preparing;
  Timer? _statusTimer;
  int _simulationSecondsRemaining = 45;
  double _liveProgress = 0.0; // 0.0 (restaurant) to 1.0 (delivered)
  double _liveSpeedKmH = 28.5;
  double _remainingDistanceKm = 3.2;

  // Delivery Partner Details
  final String _riderName = "Ravi Kumar";
  final String _riderPhone = "+91 98765 43210";
  final double _riderRating = 4.9;
  final String _riderVehicle = "TN 09 AB 1234 (Honda Activa)";

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

  List<CartItem> get items => List.unmodifiable(_items);
  Restaurant? get activeRestaurant => _activeRestaurant;

  String get deliveryAddress => _deliveryAddress;
  String get paymentMethod => _paymentMethod;
  OrderStatus get currentStatus => _currentStatus;
  int get simulationSecondsRemaining => _simulationSecondsRemaining;
  double get liveProgress => _liveProgress;
  double get liveSpeedKmH => _liveSpeedKmH;
  double get remainingDistanceKm => _remainingDistanceKm;
  String get riderName => _riderName;
  String get riderPhone => _riderPhone;
  double get riderRating => _riderRating;
  String get riderVehicle => _riderVehicle;

  int? get backendCartId => _backendCartId;
  int? get backendOrderId => _backendOrderId;
  int? get backendRestaurantId => _backendRestaurantId;
  bool get isPlacingOrder => _isPlacingOrder;
  bool get isSyncingCart => _isSyncingCart;
  String? get orderError => _orderError;

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

  /// Manually update order status in real time (e.g. from Delivery Boy dashboard)
  void updateOrderStatus(OrderStatus newStatus) {
    _currentStatus = newStatus;
    if (newStatus == OrderStatus.preparing) {
      _liveProgress = 0.05;
      _remainingDistanceKm = 3.2;
    } else if (newStatus == OrderStatus.onTheWay) {
      _liveProgress = 0.50;
      _remainingDistanceKm = 1.5;
    } else if (newStatus == OrderStatus.delivered) {
      _liveProgress = 1.0;
      _remainingDistanceKm = 0.0;
      _simulationSecondsRemaining = 0;
      _statusTimer?.cancel();
    }
    notifyListeners();
  }

  /// Syncs the current local cart with the backend.
  Future<void> syncCartWithBackend({
    required int customerId,
    required int restaurantId,
  }) async {
    if (_items.isEmpty) return;
    _isSyncingCart = true;
    _backendRestaurantId = restaurantId;
    notifyListeners();
    try {
      final svc = CartService();

      // 1. Create the cart in the backend
      final cartModel = await svc.createCart(api.CartModel(
        customerId: customerId,
        restaurantId: restaurantId,
        totalAmount: subtotal,
      ));
      _backendCartId = cartModel.id;

      // 2. Add each item to the backend cart
      for (final ci in _items) {
        final rawId = ci.foodItem.id.replaceFirst('api_', '');
        final itemId = int.tryParse(rawId);
        if (itemId == null) continue;
        await svc.addItemViaCart(api.CartItemModel(
          cartId: _backendCartId!,
          itemId: itemId,
          price: ci.foodItem.price,
          quantity: ci.quantity,
        ));
      }
    } catch (_) {
      // Non-fatal — will fall back to local simulation in placeOrder
    } finally {
      _isSyncingCart = false;
      notifyListeners();
    }
  }

  // Cart Operations
  void addItem(FoodItem item, Restaurant restaurant) {
    if (_activeRestaurant != null && _activeRestaurant!.id != restaurant.id) {
      _items.clear();
      _backendCartId = null;
    }
    _activeRestaurant = restaurant;

    final existingIndex = _items.indexWhere((element) => element.foodItem.id == item.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(foodItem: item));
    }
    notifyListeners();
  }

  void removeItem(FoodItem item) {
    final existingIndex = _items.indexWhere((element) => element.foodItem.id == item.id);
    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex].quantity--;
      } else {
        _items.removeAt(existingIndex);
      }
    }
    if (_items.isEmpty) {
      _activeRestaurant = null;
    }
    notifyListeners();
  }

  void deleteItem(FoodItem item) {
    _items.removeWhere((element) => element.foodItem.id == item.id);
    if (_items.isEmpty) {
      _activeRestaurant = null;
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _activeRestaurant = null;
    _backendCartId = null;
    notifyListeners();
  }

  int getItemQuantity(FoodItem item) {
    final index = _items.indexWhere((element) => element.foodItem.id == item.id);
    return index >= 0 ? _items[index].quantity : 0;
  }

  int quantityOf(String itemId) {
    final index = _items.indexWhere((e) => e.foodItem.id == itemId);
    return index >= 0 ? _items[index].quantity : 0;
  }

  void removeItemById(String itemId) {
    final index = _items.indexWhere((e) => e.foodItem.id == itemId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
    }
    if (_items.isEmpty) _activeRestaurant = null;
    notifyListeners();
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
    return 25.00;
  }

  double get total {
    if (_items.isEmpty) return 0.0;
    return subtotal + deliveryFee + serviceFee;
  }

  /// Places the order — calls backend if customerId + backendCartId are available,
  /// otherwise falls back to local simulation.
  Future<bool> placeOrder({int? customerId, int? restaurantId}) async {
    _statusTimer?.cancel();
    _currentStatus = OrderStatus.preparing;
    _simulationSecondsRemaining = 45;
    _liveProgress = 0.05;
    _remainingDistanceKm = 3.2;
    _liveSpeedKmH = 28.5;
    _backendOrderId = null;

    _recentOrderItems.clear();
    _recentOrderItems.addAll(_items);
    _recentOrderRestaurant = _activeRestaurant;
    _recentOrderSubtotal = subtotal;
    _recentOrderDeliveryFee = deliveryFee;
    _recentOrderServiceFee = serviceFee;
    _recentOrderTotal = total;

    final effectiveRestaurantId = restaurantId ?? _backendRestaurantId ?? _activeRestaurant?.backendId ?? 1;
    final effectiveCustomerId = customerId ?? 32;

    _isPlacingOrder = true;
    _orderError = null;
    notifyListeners();

    try {
      if (_backendCartId == null) {
        await syncCartWithBackend(
          customerId: effectiveCustomerId,
          restaurantId: effectiveRestaurantId,
        );
      }

      if (_backendCartId != null) {
        final order = await OrderService().checkout(
          cartId: _backendCartId!,
          customerId: effectiveCustomerId,
          restaurantId: effectiveRestaurantId,
        );
        _backendOrderId = order.orderId;
      }
      _isPlacingOrder = false;
      startOrderSimulation();
      clearCart();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CART] Checkout error: $e');
      _orderError = e.toString();
      _isPlacingOrder = false;
      startOrderSimulation();
      clearCart();
      notifyListeners();
      return true;
    }
  }

  // Real-Time Delivery Order Simulation Ticker
  void startOrderSimulation() {
    _statusTimer?.cancel();
    _currentStatus = OrderStatus.preparing;
    _simulationSecondsRemaining = 45;
    _liveProgress = 0.05;
    _remainingDistanceKm = 3.2;
    _liveSpeedKmH = 28.0;
    notifyListeners();

    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_simulationSecondsRemaining > 0) {
        _simulationSecondsRemaining--;

        // Calculate smooth live progress from 0.05 to 1.0
        final elapsed = 45 - _simulationSecondsRemaining;
        _liveProgress = (0.05 + (elapsed / 45.0) * 0.95).clamp(0.05, 1.0);
        _remainingDistanceKm = (3.2 * (1.0 - (_liveProgress - 0.05) / 0.95)).clamp(0.0, 3.2);

        // Fluctuate speed realistically
        _liveSpeedKmH = 24.0 + (elapsed % 7) * 2.2;

        if (_simulationSecondsRemaining == 30 && _currentStatus == OrderStatus.preparing) {
          _currentStatus = OrderStatus.onTheWay;
        } else if (_simulationSecondsRemaining == 0) {
          _currentStatus = OrderStatus.delivered;
          _liveProgress = 1.0;
          _remainingDistanceKm = 0.0;
          _liveSpeedKmH = 0.0;
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


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

enum OrderStatus {
  placed,          // 1. Order placed -> sent to restaurant
  preparing,       // 2. Restaurant accepted & chef is cooking dish
  readyForPickup,  // 3. Dish prepared! Broadcast to delivery partner fleet (waiting for rider to claim)
  partnerAssigned, // 4. First delivery partner to tap Accept claims the order
  onTheWay,        // 5. Partner picked up dish -> out for delivery
  delivered,       // 6. Arrived at customer -> verified with OTP & completed
}

class CartState extends ChangeNotifier {
  final List<CartItem> _items = [];
  Restaurant? _activeRestaurant;

  // Checkout Details
  String _deliveryAddress = "123 Foodie Lane, Gourmet City";
  String _paymentMethod = "Google Pay (UPI)";
  String _deliveryInstructions = "";
  double _tipAmount = 0.0;
  final String _deliveryOtp = "4892";
  bool _hasActiveOrder = false;

  // Backend IDs (set after login + checkout)
  int? _backendCartId;
  int? _backendOrderId;
  int? _backendRestaurantId;
  bool _isSyncingCart = false;

  // Real-Time Delivery Tracking State
  OrderStatus _currentStatus = OrderStatus.placed;
  Timer? _statusTimer;
  int _simulationSecondsRemaining = 45;
  double _liveProgress = 0.0; // 0.0 (restaurant) to 1.0 (delivered)
  double _liveSpeedKmH = 28.5;
  double _remainingDistanceKm = 3.2;

  // Delivery Partner Details (claimed exclusively by first partner who accepts)
  String _riderName = "Rahul Singh";
  String _riderPhone = "+91 98765 43210";
  double _riderRating = 4.9;
  String _riderVehicle = "KA 01 EQ 2049 (Honda Activa)";
  int? _claimedPartnerId;
  String? _claimedPartnerEmail;

  // Global registry of claimed orders: orderId -> {partnerId, name, email, vehicle, claimedAt}
  final Map<int, Map<String, dynamic>> _claimedOrdersMap = {};

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
  String get deliveryInstructions => _deliveryInstructions;
  double get tipAmount => _tipAmount;
  String get deliveryOtp => _deliveryOtp;
  bool get hasActiveOrder => _hasActiveOrder;

  OrderStatus get currentStatus => _currentStatus;
  int get simulationSecondsRemaining => _simulationSecondsRemaining;
  double get liveProgress => _liveProgress;
  double get liveSpeedKmH => _liveSpeedKmH;
  double get remainingDistanceKm => _remainingDistanceKm;
  String get riderName => _riderName;
  String get riderPhone => _riderPhone;
  double get riderRating => _riderRating;
  String get riderVehicle => _riderVehicle;
  int? get claimedPartnerId => _claimedPartnerId;
  String? get claimedPartnerEmail => _claimedPartnerEmail;
  Map<int, Map<String, dynamic>> get claimedOrdersMap => Map.unmodifiable(_claimedOrdersMap);

  /// Checks if an order is already claimed by ANY delivery partner
  bool isOrderClaimed(int orderId) {
    if (_claimedOrdersMap.containsKey(orderId)) return true;
    if (_hasActiveOrder &&
        (_backendOrderId == orderId || (orderId == 101 && _backendOrderId == null)) &&
        (_currentStatus == OrderStatus.partnerAssigned ||
         _currentStatus == OrderStatus.onTheWay ||
         _currentStatus == OrderStatus.delivered)) {
      return true;
    }
    return false;
  }

  /// Checks if an order was claimed by this SPECIFIC partner
  bool isOrderClaimedBy(int orderId, {int? partnerId, String? email, String? name}) {
    if (_claimedOrdersMap.containsKey(orderId)) {
      final info = _claimedOrdersMap[orderId]!;
      if (partnerId != null && info['partnerId'] != null && info['partnerId'] == partnerId) {
        return true;
      }
      if (email != null &&
          info['email'] != null &&
          info['email'].toString().toLowerCase() == email.toLowerCase()) {
        return true;
      }
      if (name != null &&
          info['name'] != null &&
          info['name'].toString().toLowerCase() == name.toLowerCase()) {
        return true;
      }
      return false;
    }
    if (_hasActiveOrder && (_backendOrderId == orderId || (orderId == 101 && _backendOrderId == null))) {
      if (_currentStatus == OrderStatus.partnerAssigned ||
          _currentStatus == OrderStatus.onTheWay ||
          _currentStatus == OrderStatus.delivered) {
        if (partnerId != null && _claimedPartnerId != null && _claimedPartnerId == partnerId) {
          return true;
        }
        if (email != null &&
            _claimedPartnerEmail != null &&
            _claimedPartnerEmail!.toLowerCase() == email.toLowerCase()) {
          return true;
        }
        if (name != null && _riderName.toLowerCase() == name.toLowerCase()) {
          return true;
        }
        return partnerId == null && email == null && name == null;
      }
    }
    return false;
  }

  /// Gets the name of the partner who claimed this order
  String? getOrderClaimedBy(int orderId) {
    if (_claimedOrdersMap.containsKey(orderId)) {
      return _claimedOrdersMap[orderId]!['name']?.toString();
    }
    if (_hasActiveOrder && (_backendOrderId == orderId || (orderId == 101 && _backendOrderId == null))) {
      return _riderName;
    }
    return null;
  }

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

  void setDeliveryInstructions(String instructions) {
    _deliveryInstructions = instructions;
    notifyListeners();
  }

  void setTipAmount(double tip) {
    _tipAmount = tip;
    notifyListeners();
  }

  void setBackendCartId(int id) {
    _backendCartId = id;
    notifyListeners();
  }

  bool hasDifferentRestaurant(Restaurant r) {
    return _activeRestaurant != null && _activeRestaurant!.id != r.id && _items.isNotEmpty;
  }

  /// Manually or cross-role update order status in real time
  void updateOrderStatus(OrderStatus newStatus) {
    _currentStatus = newStatus;
    _hasActiveOrder = true;
    if (newStatus == OrderStatus.placed) {
      _liveProgress = 0.02;
      _remainingDistanceKm = 3.8;
      _simulationSecondsRemaining = 60;
    } else if (newStatus == OrderStatus.preparing) {
      _liveProgress = 0.06;
      _remainingDistanceKm = 3.5;
      _simulationSecondsRemaining = 45;
    } else if (newStatus == OrderStatus.readyForPickup) {
      _liveProgress = 0.12;
      _remainingDistanceKm = 3.2;
      _simulationSecondsRemaining = 35;
    } else if (newStatus == OrderStatus.partnerAssigned) {
      _liveProgress = 0.22;
      _remainingDistanceKm = 2.6;
      _simulationSecondsRemaining = 25;
    } else if (newStatus == OrderStatus.onTheWay) {
      _liveProgress = 0.55;
      _remainingDistanceKm = 1.4;
      _simulationSecondsRemaining = 12;
    } else if (newStatus == OrderStatus.delivered) {
      _liveProgress = 1.0;
      _remainingDistanceKm = 0.0;
      _simulationSecondsRemaining = 0;
      _liveSpeedKmH = 0.0;
      _statusTimer?.cancel();
    }
    notifyListeners();
  }

  /// Called by the delivery partner who claims the order.
  /// Strict exclusivity: if another partner already claimed it, returns FALSE.
  bool acceptOrderAsPartner({
    int? orderId,
    String? partnerName,
    String? vehicle,
    double? rating,
    String? phone,
    int? partnerId,
    String? partnerEmail,
  }) {
    final oid = orderId ?? _backendOrderId ?? 101;

    // Exclusivity check: if another delivery partner already claimed it, reject!
    if (isOrderClaimed(oid) && !isOrderClaimedBy(oid, partnerId: partnerId, email: partnerEmail, name: partnerName)) {
      return false;
    }

    // Register exclusive claim
    _claimedOrdersMap[oid] = {
      'orderId': oid,
      'partnerId': partnerId,
      'name': partnerName ?? 'Rahul Singh',
      'email': partnerEmail ?? 'rahul.singh@gmail.com',
      'vehicle': vehicle ?? _riderVehicle,
      'claimedAt': DateTime.now().toIso8601String(),
    };

    if (orderId != null) _backendOrderId = orderId;
    if (partnerName != null && partnerName.isNotEmpty) _riderName = partnerName;
    if (vehicle != null && vehicle.isNotEmpty) _riderVehicle = vehicle;
    if (rating != null) _riderRating = rating;
    if (phone != null && phone.isNotEmpty) _riderPhone = phone;
    _claimedPartnerId = partnerId;
    _claimedPartnerEmail = partnerEmail;
    _simulationSecondsRemaining = 24;
    updateOrderStatus(OrderStatus.partnerAssigned);
    return true;
  }

  /// Called when the delivery partner picks up the food from the restaurant
  void markPickedUpByPartner() {
    _simulationSecondsRemaining = 12;
    updateOrderStatus(OrderStatus.onTheWay);
  }

  /// Called when the delivery partner delivers to customer and completes OTP
  void markDeliveredByPartner() {
    updateOrderStatus(OrderStatus.delivered);
  }

  /// Convert backend or cross-dashboard status string to OrderStatus enum
  void updateFromBackendStatus(String statusStr) {
    final s = statusStr.toUpperCase();
    if (s.contains('DELIVERED')) {
      updateOrderStatus(OrderStatus.delivered);
    } else if (s.contains('OUT_FOR_DELIVERY') || s.contains('ON_THE_WAY') || s.contains('PICKED_UP')) {
      updateOrderStatus(OrderStatus.onTheWay);
    } else if (s.contains('ASSIGN') || s.contains('ACCEPT')) {
      updateOrderStatus(OrderStatus.partnerAssigned);
    } else if (s.contains('READY') || s.contains('BROADCAST')) {
      updateOrderStatus(OrderStatus.readyForPickup);
    } else if (s.contains('PREPARING') || s.contains('COOK')) {
      updateOrderStatus(OrderStatus.preparing);
    } else {
      updateOrderStatus(OrderStatus.placed);
    }
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
    _currentStatus = OrderStatus.placed;
    _simulationSecondsRemaining = 60;
    _liveProgress = 0.02;
    _remainingDistanceKm = 3.8;
    _liveSpeedKmH = 26.0;
    _hasActiveOrder = true;
    notifyListeners();

    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_simulationSecondsRemaining > 0) {
        _simulationSecondsRemaining--;

        // Calculate smooth live progress from 0.02 to 1.0
        final elapsed = 60 - _simulationSecondsRemaining;
        _liveProgress = (0.02 + (elapsed / 60.0) * 0.98).clamp(0.02, 1.0);
        _remainingDistanceKm = (3.8 * (1.0 - _liveProgress)).clamp(0.0, 3.8);

        // Fluctuate speed realistically
        _liveSpeedKmH = 24.0 + (elapsed % 7) * 2.0;

        // Auto progression stages
        if (_simulationSecondsRemaining == 48 && _currentStatus == OrderStatus.placed) {
          _currentStatus = OrderStatus.preparing;
        } else if (_simulationSecondsRemaining == 34 && _currentStatus == OrderStatus.preparing) {
          _currentStatus = OrderStatus.readyForPickup;
        } else if (_currentStatus == OrderStatus.readyForPickup) {
          // Food cooked! Waiting for any delivery partner to accept from the delivery partner page
          notifyListeners();
          return;
        } else if (_simulationSecondsRemaining == 12 && _currentStatus == OrderStatus.partnerAssigned) {
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

  /// Manually advance to the next simulation phase for instant testing
  void advanceSimulationStep() {
    if (_currentStatus == OrderStatus.placed) {
      updateOrderStatus(OrderStatus.preparing);
    } else if (_currentStatus == OrderStatus.preparing) {
      updateOrderStatus(OrderStatus.readyForPickup);
    } else if (_currentStatus == OrderStatus.readyForPickup) {
      updateOrderStatus(OrderStatus.partnerAssigned);
    } else if (_currentStatus == OrderStatus.partnerAssigned) {
      updateOrderStatus(OrderStatus.onTheWay);
    } else if (_currentStatus == OrderStatus.onTheWay) {
      updateOrderStatus(OrderStatus.delivered);
    } else {
      updateOrderStatus(OrderStatus.placed);
    }
  }

  void dismissActiveOrder() {
    _hasActiveOrder = false;
    _statusTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
}


import 'dart:async';
import 'package:flutter/material.dart';
import 'food_item.dart';

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
  String _paymentMethod = "Credit Card"; // "Credit Card", "Cash on Delivery", "Cravey Wallet"
  
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

  List<CartItem> get items => List.unmodifiable(_items);
  Restaurant? get activeRestaurant => _activeRestaurant;
  
  String get deliveryAddress => _deliveryAddress;
  String get paymentMethod => _paymentMethod;
  OrderStatus get currentStatus => _currentStatus;
  int get simulationSecondsRemaining => _simulationSecondsRemaining;

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

  // Cart Operations
  void addItem(FoodItem item, Restaurant restaurant) {
    // If adding item from a different restaurant, clear the cart first (standard food app logic)
    if (_activeRestaurant != null && _activeRestaurant!.id != restaurant.id) {
      _items.clear();
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
    return 25.00; // default service fee
  }

  double get total {
    if (_items.isEmpty) return 0.0;
    return subtotal + deliveryFee + serviceFee;
  }

  void placeOrder() {
    _recentOrderItems.clear();
    _recentOrderItems.addAll(_items);
    _recentOrderRestaurant = _activeRestaurant;
    _recentOrderSubtotal = subtotal;
    _recentOrderDeliveryFee = deliveryFee;
    _recentOrderServiceFee = serviceFee;
    _recentOrderTotal = total;

    startOrderSimulation();
    clearCart();
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

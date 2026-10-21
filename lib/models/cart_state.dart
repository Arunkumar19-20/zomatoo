import 'dart:async';
import 'package:flutter/material.dart';
import 'food_item.dart';
import 'pure_cart.dart';
import '../models/models.dart' as models;
import '../repositories/cart_repository.dart';
import '../repositories/order_repository.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

// Re-export CartItem from pure_cart.dart for backward compatibility
export 'pure_cart.dart' show CartItem;

enum OrderStatus { preparing, onTheWay, delivered }

class CartState extends ChangeNotifier {
  final PureCart _pureCart;
  final CartRepository _cartRepository;
  final OrderRepository _orderRepository;

  CartState({
    PureCart? pureCart,
    CartRepository? cartRepository,
    OrderRepository? orderRepository,
  })  : _pureCart = pureCart ?? PureCart(),
        _cartRepository = cartRepository ?? CartService(),
        _orderRepository = orderRepository ?? OrderService();

  // Checkout Details
  String _deliveryAddress = "123 Foodie Lane, Gourmet City";
  String _paymentMethod = "Credit Card";

  // Backend IDs & Models (set after login + checkout)
  int? _backendCartId;
  int? _backendOrderId;
  models.OrderResponseDTO? _lastCreatedOrder;
  int? _backendRestaurantId;
  bool _isSyncingCart = false;

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

  // Pure cart getters delegated to _pureCart
  List<CartItem> get items => _pureCart.items;
  Restaurant? get activeRestaurant => _pureCart.activeRestaurant;
  int get totalItemCount => _pureCart.totalItemCount;
  double get subtotal => _pureCart.subtotal;
  double get deliveryFee => _pureCart.deliveryFee;
  double get serviceFee => _pureCart.serviceFee;
  double get total => _pureCart.total;
  int getItemQuantity(FoodItem item) => _pureCart.getItemQuantity(item);

  // Other state getters
  String get deliveryAddress => _deliveryAddress;
  String get paymentMethod => _paymentMethod;
  OrderStatus get currentStatus => _currentStatus;
  int get simulationSecondsRemaining => _simulationSecondsRemaining;
  int? get backendCartId => _backendCartId;
  int? get backendOrderId => _backendOrderId;
  models.OrderResponseDTO? get lastCreatedOrder => _lastCreatedOrder;
  int? get backendRestaurantId => _backendRestaurantId;
  bool get isPlacingOrder => _isPlacingOrder;
  bool get isSyncingCart => _isSyncingCart;
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
      final cartRes = await _cartRepository.getMyCart();
      _backendCartId = cartRes.cartId;

      final List<CartItem> newItems = [];
      for (final itemDto in cartRes.items) {
        newItems.add(CartItem(
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

      Restaurant? newRestaurant;
      if (cartRes.restaurantName != null || cartRes.restaurantId != null) {
        newRestaurant = Restaurant(
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
      }

      _pureCart.setItems(newItems, newRestaurant);
      notifyListeners();
    } catch (_) {
      // Retain offline / local state if backend sync fails
    }
  }

  // Backend sync helpers
  void _syncClearCart() {
    if (!AuthService.instance.isLoggedIn) return;
    _cartRepository.clearCart().then((_) {}, onError: (_) {});
  }

  void _syncUpdateQuantity(int cartItemId, int quantity) {
    if (!AuthService.instance.isLoggedIn) return;
    _cartRepository.updateQuantity(cartItemId, quantity).then((_) {}, onError: (_) {});
  }

  void _syncRemoveItem(int cartItemId) {
    if (!AuthService.instance.isLoggedIn) return;
    _cartRepository.removeItem(cartItemId).then((_) {}, onError: (_) {});
  }

  void _syncAddItem(CartItem cartItem, int menuItemId) {
    if (!AuthService.instance.isLoggedIn) return;
    _cartRepository.addItem(menuItemId: menuItemId, quantity: 1).then((res) {
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

  /// Syncs the current local cart with the backend.
  /// Creates a new cart record and adds every item in it.
  /// Stores the returned cartId so [placeOrder] can use it.
  Future<void> syncCartWithBackend({
    required int customerId,
    required int restaurantId,
  }) async {
    if (items.isEmpty) return;
    _isSyncingCart = true;
    _backendRestaurantId = restaurantId;
    notifyListeners();
    try {
      final svc = CartService();

      // 1. Create the cart in the backend
      final cartModel = await svc.createCart(models.CartModel(
        customerId: customerId,
        restaurantId: restaurantId,
        totalAmount: subtotal,
      ));
      _backendCartId = cartModel.id;

      // 2. Add each item to the backend cart
      for (final ci in items) {
        // Parse numeric menu-item id from 'api_<id>' or direct int string
        final rawId = ci.foodItem.id.replaceFirst('api_', '');
        final itemId = int.tryParse(rawId);
        if (itemId == null) continue;
        await svc.addItemViaCart(models.CartItemModel(
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
    final switched = _pureCart.addItem(item, restaurant);
    if (switched) {
      _backendCartId = null;
      _syncClearCart();
    }

    final cartItem = _pureCart.items.firstWhere((element) => element.foodItem.id == item.id);
    if (cartItem.quantity > 1) {
      if (cartItem.backendCartItemId != null) {
        _syncUpdateQuantity(cartItem.backendCartItemId!, cartItem.quantity);
      }
    } else {
      if (item.backendItemId != null) {
        _syncAddItem(cartItem, item.backendItemId!);
      }
    }
    notifyListeners();
  }

  void removeItem(FoodItem item) {
    final result = _pureCart.removeItem(item);
    if (result.item != null) {
      if (result.wasRemoved) {
        if (result.item!.backendCartItemId != null) {
          _syncRemoveItem(result.item!.backendCartItemId!);
        }
      } else {
        if (result.item!.backendCartItemId != null) {
          _syncUpdateQuantity(result.item!.backendCartItemId!, result.item!.quantity);
        }
      }
    }
    notifyListeners();
  }

  void deleteItem(FoodItem item) {
    final removed = _pureCart.deleteItem(item);
    if (removed != null && removed.backendCartItemId != null) {
      _syncRemoveItem(removed.backendCartItemId!);
    }
    notifyListeners();
  }

  void clearCart() {
    _pureCart.clear();
    _backendCartId = null;
    _syncClearCart();
    notifyListeners();
  }

  /// Places the order — calls backend checkout if authenticated or IDs available,
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
    _recentOrderItems.addAll(items);
    _recentOrderRestaurant = activeRestaurant;
    _recentOrderSubtotal = subtotal;
    _recentOrderDeliveryFee = deliveryFee;
    _recentOrderServiceFee = serviceFee;
    _recentOrderTotal = total;

    final effectiveRestaurantId = restaurantId ?? activeRestaurant?.backendId ?? _backendRestaurantId;

    // Authenticated checkout against backend (or if IDs provided)
    if (AuthService.instance.isLoggedIn || (customerId != null && _backendCartId != null && effectiveRestaurantId != null)) {
      _isPlacingOrder = true;
      notifyListeners();

      try {
        final order = await _orderRepository.checkout(
          restaurantId: effectiveRestaurantId,
          cartId: _backendCartId,
          customerId: customerId,
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

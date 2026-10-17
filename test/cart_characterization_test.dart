import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/cart_state.dart';
import 'package:tomatoo/models/food_item.dart';
import 'package:tomatoo/services/auth_service.dart';

void main() {
  group('CartState Characterization Tests', () {
    late CartState cartState;
    late Restaurant restaurantA;
    late Restaurant restaurantB;
    late Restaurant rest1;
    late FoodItem itemA1;
    late FoodItem itemA2;
    late FoodItem itemB1;

    setUp(() {
      cartState = CartState();

      restaurantA = Restaurant(
        id: 'restA',
        name: 'Restaurant A',
        imageUrl: '',
        rating: 4.5,
        deliveryTime: '30 min',
        deliveryFee: 40.0,
        cuisineTags: ['North Indian'],
        menu: [],
        backendId: 101,
      );

      restaurantB = Restaurant(
        id: 'restB',
        name: 'Restaurant B',
        imageUrl: '',
        rating: 4.2,
        deliveryTime: '45 min',
        deliveryFee: 60.0,
        cuisineTags: ['Chinese'],
        menu: [],
        backendId: 102,
      );

      rest1 = Restaurant(
        id: 'rest1',
        name: 'Special rest1',
        imageUrl: '',
        rating: 4.8,
        deliveryTime: '20 min',
        deliveryFee: 30.0,
        cuisineTags: ['Fast Food'],
        menu: [],
        backendId: 1,
      );

      itemA1 = FoodItem(
        id: 'itemA1',
        name: 'Paneer Tikka',
        description: 'Spicy cottage cheese',
        price: 200.0,
        imageUrl: '',
        category: 'Starter',
        rating: 4.5,
        backendItemId: 11,
      );

      itemA2 = FoodItem(
        id: 'itemA2',
        name: 'Butter Naan',
        description: 'Tandoori bread',
        price: 50.0,
        imageUrl: '',
        category: 'Breads',
        rating: 4.3,
        backendItemId: 12,
      );

      itemB1 = FoodItem(
        id: 'itemB1',
        name: 'Veg Hakka Noodles',
        description: 'Stir fried noodles',
        price: 180.0,
        imageUrl: '',
        category: 'Mains',
        rating: 4.0,
        backendItemId: 21,
      );
    });

    test('Add, increment, decrement, and remove items with exact totals', () {
      // 1. Initial empty state
      expect(cartState.items, isEmpty);
      expect(cartState.totalItemCount, 0);
      expect(cartState.subtotal, 0.0);
      expect(cartState.deliveryFee, 0.0);
      expect(cartState.serviceFee, 0.0);
      expect(cartState.total, 0.0);
      expect(cartState.activeRestaurant, isNull);

      // 2. Add first item
      cartState.addItem(itemA1, restaurantA);
      expect(cartState.items.length, 1);
      expect(cartState.items.first.quantity, 1);
      expect(cartState.getItemQuantity(itemA1), 1);
      expect(cartState.activeRestaurant?.id, 'restA');
      expect(cartState.subtotal, 200.0);
      expect(cartState.deliveryFee, 40.0);
      expect(cartState.serviceFee, 25.0); // Default non-rest1 fee
      expect(cartState.total, 200.0 + 40.0 + 25.0); // 265.0

      // 3. Increment itemA1 by adding again
      cartState.addItem(itemA1, restaurantA);
      expect(cartState.items.length, 1);
      expect(cartState.items.first.quantity, 2);
      expect(cartState.getItemQuantity(itemA1), 2);
      expect(cartState.subtotal, 400.0);
      expect(cartState.total, 400.0 + 40.0 + 25.0); // 465.0

      // 4. Add second item itemA2
      cartState.addItem(itemA2, restaurantA);
      expect(cartState.items.length, 2);
      expect(cartState.totalItemCount, 3);
      expect(cartState.subtotal, 450.0);
      expect(cartState.total, 450.0 + 40.0 + 25.0); // 515.0

      // 5. Decrement itemA1 via removeItem
      cartState.removeItem(itemA1);
      expect(cartState.getItemQuantity(itemA1), 1);
      expect(cartState.totalItemCount, 2);
      expect(cartState.subtotal, 250.0);

      // 6. Delete itemA2 completely via deleteItem
      cartState.deleteItem(itemA2);
      expect(cartState.items.length, 1);
      expect(cartState.getItemQuantity(itemA2), 0);
      expect(cartState.subtotal, 200.0);

      // 7. Decrement remaining itemA1 from 1 to 0 removes it and clears activeRestaurant
      cartState.removeItem(itemA1);
      expect(cartState.items, isEmpty);
      expect(cartState.activeRestaurant, isNull);
      expect(cartState.subtotal, 0.0);
      expect(cartState.deliveryFee, 0.0);
      expect(cartState.serviceFee, 0.0);
      expect(cartState.total, 0.0);
    });

    test('Special rest1 service fee rule (567.99)', () {
      cartState.addItem(itemA1, rest1);
      expect(cartState.activeRestaurant?.id, 'rest1');
      expect(cartState.serviceFee, 567.99);
      expect(cartState.deliveryFee, 30.0);
      expect(cartState.subtotal, 200.0);
      expect(cartState.total, 200.0 + 30.0 + 567.99);
    });

    test('Adding from a different restaurant clears the cart and resets restaurant', () {
      cartState.addItem(itemA1, restaurantA);
      expect(cartState.activeRestaurant?.id, 'restA');
      expect(cartState.items.length, 1);

      // Add from restaurant B
      cartState.addItem(itemB1, restaurantB);
      expect(cartState.activeRestaurant?.id, 'restB');
      expect(cartState.items.length, 1);
      expect(cartState.items.first.foodItem.id, 'itemB1');
      expect(cartState.subtotal, 180.0);
      expect(cartState.deliveryFee, 60.0);
    });

    test('clearCart empties items and resets restaurant and backendCartId', () {
      cartState.addItem(itemA1, restaurantA);
      cartState.setBackendCartId(777);
      expect(cartState.items, isNotEmpty);
      expect(cartState.backendCartId, 777);

      cartState.clearCart();
      expect(cartState.items, isEmpty);
      expect(cartState.activeRestaurant, isNull);
      expect(cartState.backendCartId, isNull);
      expect(cartState.subtotal, 0.0);
      expect(cartState.total, 0.0);
    });

    test('Guest local order placement copies recent order details and starts simulation', () {
      AuthService.instance.setTokensForTesting(accessToken: null, refreshToken: null);

      cartState.addItem(itemA1, restaurantA);
      cartState.setDeliveryAddress('Custom Address 42');
      cartState.setPaymentMethod('UPI');

      cartState.placeOrder();

      // Cart is cleared
      expect(cartState.items, isEmpty);
      expect(cartState.activeRestaurant, isNull);

      // Recent order preserved
      expect(cartState.recentOrderItems.length, 1);
      expect(cartState.recentOrderRestaurant?.id, 'restA');
      expect(cartState.recentOrderSubtotal, 200.0);
      expect(cartState.recentOrderDeliveryFee, 40.0);
      expect(cartState.recentOrderServiceFee, 25.0);
      expect(cartState.recentOrderTotal, 265.0);
      expect(cartState.currentStatus, OrderStatus.preparing);
      expect(cartState.simulationSecondsRemaining, 25);
    });
  });
}

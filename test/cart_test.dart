import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/cart_state.dart';
import 'package:tomatoo/models/food_item.dart';

void main() {
  group('CartState Tests', () {
    late CartState cartState;
    late Restaurant mockRestaurant;
    late FoodItem item1;
    late FoodItem item2;

    setUp(() {
      cartState = CartState();
      
      // Use items from mockRestaurants
      mockRestaurant = mockRestaurants[0]; // Punjabi Dhaba
      item1 = mockRestaurant.menu[0]; // Butter Chicken ($12.99)
      item2 = mockRestaurant.menu[1]; // Garlic Naan ($2.99)
    });

    test('Initial cart is empty', () {
      expect(cartState.items.length, 0);
      expect(cartState.totalItemCount, 0);
      expect(cartState.subtotal, 0.0);
      expect(cartState.total, 0.0);
      expect(cartState.activeRestaurant, null);
    });

    test('Add item to cart works correctly', () {
      cartState.addItem(item1, mockRestaurant);
      
      expect(cartState.items.length, 1);
      expect(cartState.totalItemCount, 1);
      expect(cartState.items[0].foodItem.id, item1.id);
      expect(cartState.items[0].quantity, 1);
      expect(cartState.activeRestaurant?.id, mockRestaurant.id);
      expect(cartState.subtotal, 567.99);
      expect(cartState.deliveryFee, mockRestaurant.deliveryFee);
    });

    test('Add same item twice increments quantity', () {
      cartState.addItem(item1, mockRestaurant);
      cartState.addItem(item1, mockRestaurant);

      expect(cartState.items.length, 1);
      expect(cartState.totalItemCount, 2);
      expect(cartState.items[0].quantity, 2);
      expect(cartState.subtotal, 567.99 * 2);
    });

    test('Add different item updates cart', () {
      cartState.addItem(item1, mockRestaurant);
      cartState.addItem(item2, mockRestaurant);

      expect(cartState.items.length, 2);
      expect(cartState.totalItemCount, 2);
      expect(cartState.subtotal, 567.99 + 99.00);
    });

    test('Remove item decrements quantity or removes it', () {
      cartState.addItem(item1, mockRestaurant);
      cartState.addItem(item1, mockRestaurant);
      
      cartState.removeItem(item1);
      expect(cartState.items[0].quantity, 1);

      cartState.removeItem(item1);
      expect(cartState.items.length, 0);
      expect(cartState.activeRestaurant, null);
    });

    test('Change address and payment method works', () {
      cartState.setDeliveryAddress("456 Park Avenue");
      cartState.setPaymentMethod("Cash on Delivery");

      expect(cartState.deliveryAddress, "456 Park Avenue");
      expect(cartState.paymentMethod, "Cash on Delivery");
    });

    test('Place order copies details to recent order and clears cart', () {
      cartState.addItem(item1, mockRestaurant);
      cartState.setDeliveryAddress("456 Park Avenue");
      cartState.setPaymentMethod("Cash on Delivery");

      cartState.placeOrder();

      // Cart should be empty
      expect(cartState.items.length, 0);
      expect(cartState.activeRestaurant, null);

      // Recent order should be filled
      expect(cartState.recentOrderItems.length, 1);
      expect(cartState.recentOrderItems[0].foodItem.id, item1.id);
      expect(cartState.recentOrderRestaurant?.id, mockRestaurant.id);
      expect(cartState.recentOrderTotal, 567.99 + 567.99 + 567.99);
      
      // Tracking status should be preparing
      expect(cartState.currentStatus, OrderStatus.preparing);
    });
  });
}

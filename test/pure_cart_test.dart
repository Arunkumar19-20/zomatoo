import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/pure_cart.dart';
import 'package:tomatoo/models/food_item.dart';

void main() {
  group('PureCart Unit Tests (Pure Logic, No Network)', () {
    late PureCart pureCart;
    late Restaurant restA;
    late Restaurant restB;
    late Restaurant rest1;
    late FoodItem item1;
    late FoodItem item2;
    late FoodItem item3;

    setUp(() {
      pureCart = PureCart();

      restA = Restaurant(
        id: 'restA',
        name: 'Curry Palace',
        imageUrl: '',
        rating: 4.5,
        deliveryTime: '25 min',
        deliveryFee: 35.0,
        cuisineTags: ['Indian'],
        menu: [],
        backendId: 10,
      );

      restB = Restaurant(
        id: 'restB',
        name: 'Wok & Roll',
        imageUrl: '',
        rating: 4.1,
        deliveryTime: '40 min',
        deliveryFee: 50.0,
        cuisineTags: ['Asian'],
        menu: [],
        backendId: 20,
      );

      rest1 = Restaurant(
        id: 'rest1',
        name: 'Special rest1',
        imageUrl: '',
        rating: 4.9,
        deliveryTime: '15 min',
        deliveryFee: 20.0,
        cuisineTags: ['Burgers'],
        menu: [],
        backendId: 1,
      );

      item1 = FoodItem(
        id: 'i1',
        name: 'Biryani',
        description: 'Fragrant spiced rice',
        price: 300.0,
        imageUrl: '',
        category: 'Mains',
        rating: 4.8,
      );

      item2 = FoodItem(
        id: 'i2',
        name: 'Raita',
        description: 'Yogurt dip',
        price: 60.0,
        imageUrl: '',
        category: 'Sides',
        rating: 4.0,
      );

      item3 = FoodItem(
        id: 'i3',
        name: 'Dim Sum',
        description: 'Steamed dumplings',
        price: 180.0,
        imageUrl: '',
        category: 'Starters',
        rating: 4.6,
      );
    });

    test('Initial empty state returns zeros and empty list', () {
      expect(pureCart.items, isEmpty);
      expect(pureCart.totalItemCount, 0);
      expect(pureCart.subtotal, 0.0);
      expect(pureCart.deliveryFee, 0.0);
      expect(pureCart.serviceFee, 0.0);
      expect(pureCart.total, 0.0);
      expect(pureCart.activeRestaurant, isNull);
    });

    test('Add item adds quantity 1 and sets active restaurant', () {
      final switched = pureCart.addItem(item1, restA);
      expect(switched, isFalse);
      expect(pureCart.items.length, 1);
      expect(pureCart.totalItemCount, 1);
      expect(pureCart.subtotal, 300.0);
      expect(pureCart.deliveryFee, 35.0);
      expect(pureCart.serviceFee, 25.0);
      expect(pureCart.total, 360.0);
      expect(pureCart.activeRestaurant?.id, 'restA');
    });

    test('Add same item increments existing quantity without duplication', () {
      pureCart.addItem(item1, restA);
      pureCart.addItem(item1, restA);

      expect(pureCart.items.length, 1);
      expect(pureCart.items.first.quantity, 2);
      expect(pureCart.totalItemCount, 2);
      expect(pureCart.subtotal, 600.0);
      expect(pureCart.total, 600.0 + 35.0 + 25.0);
    });

    test('Add different item within same restaurant', () {
      pureCart.addItem(item1, restA);
      pureCart.addItem(item2, restA);

      expect(pureCart.items.length, 2);
      expect(pureCart.totalItemCount, 2);
      expect(pureCart.subtotal, 360.0);
      expect(pureCart.total, 360.0 + 35.0 + 25.0);
    });

    test('Restaurant mismatch clears previous items and sets switched flag', () {
      pureCart.addItem(item1, restA);
      expect(pureCart.activeRestaurant?.id, 'restA');

      final switched = pureCart.addItem(item3, restB);
      expect(switched, isTrue);
      expect(pureCart.activeRestaurant?.id, 'restB');
      expect(pureCart.items.length, 1);
      expect(pureCart.items.first.foodItem.id, 'i3');
      expect(pureCart.subtotal, 180.0);
      expect(pureCart.deliveryFee, 50.0);
    });

    test('Special service fee applied for rest1', () {
      pureCart.addItem(item1, rest1);
      expect(pureCart.serviceFee, 567.99);
      expect(pureCart.total, 300.0 + 20.0 + 567.99);
    });

    test('removeItem decrements quantity then removes on 0', () {
      pureCart.addItem(item1, restA);
      pureCart.addItem(item1, restA);

      final r1 = pureCart.removeItem(item1);
      expect(r1.wasRemoved, isFalse);
      expect(r1.item?.quantity, 1);
      expect(pureCart.items.length, 1);
      expect(pureCart.activeRestaurant, isNotNull);

      final r2 = pureCart.removeItem(item1);
      expect(r2.wasRemoved, isTrue);
      expect(pureCart.items, isEmpty);
      expect(pureCart.activeRestaurant, isNull);
      expect(pureCart.total, 0.0);
    });

    test('deleteItem completely removes item regardless of quantity', () {
      pureCart.addItem(item1, restA);
      pureCart.addItem(item1, restA);
      pureCart.addItem(item2, restA);

      final removed = pureCart.deleteItem(item1);
      expect(removed?.foodItem.id, 'i1');
      expect(pureCart.items.length, 1);
      expect(pureCart.items.first.foodItem.id, 'i2');
      expect(pureCart.subtotal, 60.0);
    });

    test('clear resets items and restaurant', () {
      pureCart.addItem(item1, restA);
      pureCart.clear();

      expect(pureCart.items, isEmpty);
      expect(pureCart.activeRestaurant, isNull);
      expect(pureCart.subtotal, 0.0);
    });
  });
}

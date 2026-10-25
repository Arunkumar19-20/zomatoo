import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/food_item.dart';
import 'package:tomatoo/widgets/search/restaurant_matches.dart';
import 'package:tomatoo/widgets/search/restaurant_results_section.dart';

FoodItem dish(String name, {String category = 'Mains', String description = ''}) =>
    FoodItem(id: 'api_$name', name: name, description: description, price: 300, imageUrl: '', category: category, rating: 4.5);

Restaurant resto(String name, List<String> cuisines, List<FoodItem> menu, {double rating = 4.5, String? address, String? discount}) => Restaurant(
      id: 'api_$name',
      name: name,
      imageUrl: '',
      rating: rating,
      deliveryTime: '30 min',
      deliveryFee: 29,
      cuisineTags: cuisines,
      menu: menu,
      address: address,
      discountText: discount,
    );

void main() {
  final bella = resto('Bella Napoli', ['Italian', 'Wood Fired Pizza', 'Pasta'], [dish('Lasagna al Forno', category: 'Pasta'), dish('Margherita Pizza', category: 'Pizza')], rating: 4.6, address: '12 Via Roma Lane');
  final cravey = resto('Cravey Kitchen', ['Italian', 'American'], [dish('Pasta Primavera', category: 'Mains', description: 'Mentions pasta'), dish('Burger')], rating: 4.8);
  final spice = resto('Spice Route', ['North Indian'], [dish('Butter Chicken'), dish('Naan')], rating: 4.4);
  final tokyo = resto('Tokyo Ramen House', ['Japanese'], [dish('Tonkotsu Ramen', category: 'Ramen'), dish('Pasta Salad')], rating: 4.2);
  final all = [spice, cravey, tokyo, bella];

  List<String> names(String q, [List<Restaurant>? from]) => matchRestaurants(q, from ?? all).map((m) => m.restaurant.name).toList();

  group('matchRestaurants', () {
    test('a restaurant is relevant when it is the cuisine or serves the dish; the rest are left out', () {
      final r = names('pasta');
      expect(r, containsAll(['Bella Napoli', 'Cravey Kitchen', 'Tokyo Ramen House']));
      expect(r, isNot(contains('Spice Route')));
    });

    test('the cuisine ranks above a restaurant that merely has the dish', () {
      expect(names('pasta').first, 'Bella Napoli', reason: 'it is Pasta by cuisine and has pasta on the menu');
    });

    test('a name match comes first of all', () {
      expect(names('ramen').first, 'Tokyo Ramen House');
      expect(matchRestaurants('bella', all).single.reason, 'Name matches');
    });

    test('every word of the query has to be found: "italian pasta" is not every Italian place plus every pasta dish', () {
      expect(names('italian pasta'), unorderedEquals(['Bella Napoli', 'Cravey Kitchen']));
      expect(names('korean pasta'), isEmpty);
      expect(names('japanese pasta'), ['Tokyo Ramen House'], reason: 'Pasta Salad is on its menu');
    });

    test('plurals and the start of a word are fine, tiny fragments are not', () {
      expect(names('pastas'), containsAll(['Bella Napoli', 'Cravey Kitchen']));
      expect(names('ital'), unorderedEquals(['Bella Napoli', 'Cravey Kitchen']));
      expect(names('pa'), isEmpty, reason: 'two letters is not a word to match');
    });

    test('words that say what the customer is doing are ignored', () {
      expect(names('best italian restaurants near me'), unorderedEquals(['Bella Napoli', 'Cravey Kitchen']));
      expect(names('food'), isEmpty);
      expect(names('   '), isEmpty);
      expect(names(''), isEmpty);
    });

    test('the reason says why, in the order name, cuisine, menu, address', () {
      expect(matchRestaurants('italian', [bella]).single.reason, 'Cuisine: Italian');
      expect(matchRestaurants('pasta', [cravey]).single.reason, 'Serves Pasta Primavera');
      expect(matchRestaurants('lane', [bella]).single.reason, 'In 12 Via Roma Lane');
      final many = resto('Corner Cafe', ['Cafe'], [for (final n in ['Alfredo Pasta', 'Baked Pasta', 'Cold Pasta', 'Dry Pasta']) dish(n)]);
      expect(matchRestaurants('pasta', [many]).single.reason, contains('and 2 more'));
    });

    test('equally relevant restaurants go to the better rated, then by name', () {
      final a = resto('Zed Grill', ['Italian'], [], rating: 4.0);
      final b = resto('Alpha Grill', ['Italian'], [], rating: 4.0);
      final c = resto('Best Grill', ['Italian'], [], rating: 4.9);
      expect(names('italian', [a, b, c]), ['Best Grill', 'Alpha Grill', 'Zed Grill']);
    });
  });

  group('RestaurantResultsSection', () {
    Widget host({String query = 'pasta', List<Restaurant>? restaurants, bool loading = false, void Function(Restaurant)? onOpen}) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: RestaurantResultsSection(query: query, restaurants: restaurants ?? all, loading: loading, onOpen: onOpen ?? (_) {}))),
        );

    testWidgets('lists the relevant restaurants with a count and why each is there', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      expect(find.text('Restaurants for "pasta"'), findsOneWidget);
      expect(find.text('3 restaurants'), findsOneWidget);
      expect(find.byKey(const ValueKey('restaurant-hit-api_Bella Napoli')), findsOneWidget);
      expect(find.byKey(const ValueKey('restaurant-hit-api_Spice Route')), findsNothing);
      expect(find.byKey(const ValueKey('restaurant-reason-api_Bella Napoli')), findsOneWidget);
      expect(find.textContaining('Serves Pasta Primavera'), findsOneWidget);
    });

    testWidgets('tapping a restaurant opens it', (tester) async {
      Restaurant? opened;
      await tester.pumpWidget(host(onOpen: (r) => opened = r));
      await tester.tap(find.byKey(const ValueKey('restaurant-hit-api_Bella Napoli')));
      expect(opened?.name, 'Bella Napoli');
    });

    testWidgets('one match reads in the singular, and none says what to try', (tester) async {
      await tester.pumpWidget(host(query: 'butter chicken'));
      expect(find.text('1 restaurant'), findsOneWidget);
      await tester.pumpWidget(host(query: 'injera'));
      expect(find.byKey(const ValueKey('restaurant-empty')), findsOneWidget);
      expect(find.textContaining('Try Dishes'), findsOneWidget);
    });

    testWidgets('while restaurants are still loading it shows progress, not "no match"', (tester) async {
      await tester.pumpWidget(host(restaurants: const [], loading: true));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('restaurant-empty')), findsNothing);
    });

    testWidgets('a closed restaurant is marked', (tester) async {
      final closed = resto('Closed Pasta Co', ['Italian'], [], discount: 'Closed');
      await tester.pumpWidget(host(restaurants: [closed], query: 'italian'));
      expect(find.textContaining('Closed now'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/models/cart_state.dart';
import 'package:tomatoo/models/dish_search_models.dart';
import 'package:tomatoo/models/dish_search_state.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/services/search_attribution.dart';
import 'package:tomatoo/widgets/search/dish_cart.dart';
import 'package:tomatoo/widgets/search/dish_placeholder.dart';
import 'package:tomatoo/widgets/search/dish_result_card.dart';
import 'package:tomatoo/widgets/search/dish_results_section.dart';
import 'package:tomatoo/widgets/search/search_scope_chips.dart';

import 'fakes/fake_dish_search.dart';

void main() {
  late FakeDishSearchRepository repo;
  late DishSearchState state;
  late CartState cart;
  late SearchAttribution attribution;
  DishHit? opened;

  setUp(() {
    repo = FakeDishSearchRepository();
    attribution = SearchAttribution();
    state = DishSearchState(repository: repo, debounce: const Duration(milliseconds: 10), attribution: attribution);
    cart = CartState();
    opened = null;
  });

  tearDown(() => state.dispose());

  Widget host(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<DishSearchState>.value(value: state),
          ChangeNotifierProvider<CartState>.value(value: cart),
        ],
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child)))),
      );

  Future<void> search(WidgetTester tester, String q) async {
    state.onQueryChanged(q);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
  }

  group('DishResultsSection', () {
    testWidgets('renders nothing until the text looks like a craving', (tester) async {
      await tester.pumpWidget(host(DishResultsSection(onOpen: (h) => opened = h)));
      expect(find.byKey(const ValueKey('dish-results')), findsNothing);
      state.onQueryChanged('ab');
      await tester.pump();
      expect(find.byKey(const ValueKey('dish-results')), findsNothing);
    });

    testWidgets('shows the top-k with how the craving was read, matched flavors and the reason', (tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, hits: [
            makeHit(id: 1, name: 'Honey Hot Chicken Tenders'),
            makeHit(id: 2, name: 'Mango Habanero Wings', spice: 4, restaurant: 'Casa Fuego', reasons: const ['Looks sweet + spicy from its description']),
            makeHit(id: 3, name: 'Chili Chocolate Truffle', veg: true, spice: 2, price: 149, restaurant: 'Sugar & Spice Patisserie', tags: const ['sweet', 'spicy', 'rich']),
          ], total: 40));
      await tester.pumpWidget(host(DishResultsSection(onOpen: (h) => opened = h)));
      await search(tester, 'something sweet but also spicy');

      expect(find.text('Dishes for "something sweet but also spicy"'), findsOneWidget);
      expect(find.byKey(const ValueKey('dish-understood')), findsOneWidget);
      expect(find.textContaining('Read as: sweet + spicy'), findsOneWidget);
      expect(find.byKey(const ValueKey('dish-count')), findsOneWidget);
      expect(find.text('Top 3 of 40'), findsOneWidget);
      expect(find.text('Honey Hot Chicken Tenders'), findsOneWidget);
      expect(find.text('Mango Habanero Wings'), findsOneWidget);
      // a dish is described by its cuisine; taste tags belong to the Cravings filter only
      expect(find.text('American BBQ'), findsNWidgets(3));
      expect(find.text('Burgers'), findsNWidgets(3));
      expect(find.text('Sweet'), findsNothing);
      expect(find.text('Spicy'), findsNothing);
      expect(find.text('Tagged sweet + spicy by the restaurant'), findsNWidgets(2), reason: 'hits 1 and 3 share this reason');
      expect(find.text('Looks sweet + spicy from its description'), findsOneWidget);
      expect(find.text('₹379'), findsNWidgets(2));
      expect(find.text('₹149'), findsOneWidget);
      expect(find.text('#1'), findsNothing, reason: 'results are not numbered');
      expect(find.text('#3'), findsNothing);
    });

    testWidgets('tapping a dish hands it to the screen (to open its restaurant)', (tester) async {
      await tester.pumpWidget(host(DishResultsSection(onOpen: (h) => opened = h)));
      await search(tester, 'creamy and comforting');
      await tester.tap(find.byKey(const ValueKey('dish-hit-1')));
      await tester.pump();
      expect(opened?.itemId, 1);
    });

    testWidgets('no match explains what to try; keyword mode and filters are disclosed', (tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, hits: const [], flavors: const [], facets: const ['xyzzy']));
      await tester.pumpWidget(host(const DishResultsSection()));
      await search(tester, 'xyzzy');
      expect(find.byKey(const ValueKey('dish-empty')), findsOneWidget);
      expect(find.textContaining('Try describing the taste'), findsOneWidget);

      repo.handler = (q, k) => Future.value(makeResponse(q, mode: 'KEYWORD', veg: true, maxPrice: 300));
      await search(tester, 'spicy vegetarian under 300');
      final understood = tester.widget<Text>(find.byKey(const ValueKey('dish-understood'))).data!;
      expect(understood, contains('vegetarian only'));
      expect(understood, contains('under ₹300'));
      expect(understood, contains('keyword mode'));
    });

    testWidgets('show more appears when there are more results and loads them', (tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, hits: List.generate(k, (i) => makeHit(id: i + 1, name: 'Dish ${i + 1}')), total: 50));
      await tester.pumpWidget(host(const DishResultsSection()));
      await search(tester, 'something crunchy');
      expect(find.text('Top 10 of 50'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('dish-show-more')));
      await tester.tap(find.byKey(const ValueKey('dish-show-more')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Top 20 of 50'), findsOneWidget);
    });

    testWidgets('an error shows a retry that recovers', (tester) async {
      repo.error = ApiException('Could not reach the server');
      await tester.pumpWidget(host(const DishResultsSection()));
      await search(tester, 'spicy noodles');
      expect(find.byKey(const ValueKey('dish-error')), findsOneWidget);

      repo.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('dish-error')), findsNothing);
      expect(find.text('Honey Hot Chicken Tenders'), findsOneWidget);
    });
  });

  group('DishResultCard', () {
    Widget card(DishHit h) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DishResultCard(hit: h))));

    testWidgets('shows a closed restaurant, spice flames from level 2 and the veg mark', (tester) async {
      await tester.pumpWidget(card(makeHit(open: false, spice: 3, veg: true)));
      expect(find.textContaining('Closed now'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNWidgets(3));
      expect(find.byTooltip('Vegetarian'), findsOneWidget);
    });

    testWidgets('mild dishes show no flames and other tags are outlined, not filled', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DishResultCard(hit: makeHit(spice: 1, matched: const ['sweet'], tags: const ['sweet', 'creamy', 'rich', 'comfort', 'light']), showFlavors: true)))));
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
      expect(find.text('Sweet'), findsOneWidget);
      expect(find.text('Creamy'), findsOneWidget);
      expect(find.text('Light'), findsNothing, reason: 'at most 3 extra tags');
    });
  });

  group('cuisine instead of taste tags', () {
    Widget plain(DishHit h, {bool flavors = false}) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DishResultCard(hit: h, showFlavors: flavors))));

    testWidgets('a dish shows its restaurant\'s cuisine, at most two, and none of its taste tags', (tester) async {
      await tester.pumpWidget(plain(makeHit(id: 4, cuisine: 'Italian, American, Comfort Food', matched: const ['creamy'], tags: const ['creamy', 'rich', 'comfort'])));
      expect(find.text('Italian'), findsOneWidget);
      expect(find.text('American'), findsOneWidget);
      expect(find.text('Comfort Food'), findsNothing, reason: 'two is enough on a card');
      expect(find.text('Creamy'), findsNothing);
      expect(find.text('Rich'), findsNothing);
    });

    testWidgets('the Cravings filter is the one place the taste tags show, and the cuisine steps aside', (tester) async {
      await tester.pumpWidget(plain(makeHit(id: 4, cuisine: 'Italian', matched: const ['creamy'], tags: const ['creamy', 'rich']), flavors: true));
      expect(find.text('Creamy'), findsOneWidget);
      expect(find.text('Rich'), findsOneWidget);
      expect(find.text('Italian'), findsNothing);
    });

    testWidgets('a restaurant with no cuisine set simply shows no chips', (tester) async {
      await tester.pumpWidget(plain(makeHit(id: 4, cuisine: null)));
      expect(find.text('Smokehouse 66'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(plain(makeHit(id: 5, cuisine: ' , ,')));
      expect(tester.takeException(), isNull);
    });

    test('cuisines are split on commas, trimmed and capped', () {
      expect(makeHit(cuisine: 'North Indian').cuisines(), ['North Indian']);
      expect(makeHit(cuisine: 'Italian,  American , Comfort Food').cuisines(), ['Italian', 'American']);
      expect(makeHit(cuisine: 'Italian, American, Comfort Food').cuisines(max: 3), ['Italian', 'American', 'Comfort Food']);
      expect(makeHit(cuisine: null).cuisines(), isEmpty);
    });

    testWidgets('in a list, the filter decides: everything shows cuisine, Cravings shows taste', (tester) async {
      Widget list() => MultiProvider(
            providers: [ChangeNotifierProvider<DishSearchState>.value(value: state), ChangeNotifierProvider<CartState>.value(value: cart)],
            child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Column(children: const [SearchScopeChips(), DishResultsSection()])))),
          );
      repo.handler = (q, k) => Future.value(makeResponse(q, hits: [makeHit(id: 1, cuisine: 'Italian')]));
      await tester.pumpWidget(list());
      await search(tester, 'pasta');
      expect(find.text('Italian'), findsOneWidget);
      expect(find.text('Sweet'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('scope-cravings')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Sweet'), findsOneWidget);
      expect(find.text('Italian'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('scope-dishes')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Italian'), findsOneWidget);
      expect(find.text('Sweet'), findsNothing);
    });
  });

  group('adding to the cart from the results', () {
    Future<void> showTwo(WidgetTester tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, searchId: 'sid-1', hits: [makeHit(id: 1, name: 'Spaghetti Carbonara'), makeHit(id: 2, name: 'Pesto Gnocchi')]));
      await tester.pumpWidget(host(const DishResultsSection()));
      await search(tester, 'pasta');
    }

    testWidgets('every result offers ADD, and none shows a rank number', (tester) async {
      await showTwo(tester);
      expect(find.byKey(const ValueKey('dish-add-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('dish-add-2')), findsOneWidget);
      expect(find.text('#1'), findsNothing);
      expect(find.text('#2'), findsNothing);
    });

    testWidgets('ADD puts the dish in the cart and turns into a stepper; plus and minus change the quantity; minus to zero returns to ADD', (tester) async {
      await showTwo(tester);
      await tester.tap(find.byKey(const ValueKey('dish-add-1')));
      await tester.pump();
      expect(cart.items.single.foodItem.id, 'api_1');
      expect(cart.items.single.quantity, 1);
      expect(cart.activeRestaurant?.id, 'api_7');
      expect(find.byKey(const ValueKey('dish-add-1')), findsNothing);
      expect(find.byKey(const ValueKey('dish-qty-1')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('dish-qty-1'))).data, '1');

      await tester.tap(find.byKey(const ValueKey('dish-plus-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dish-plus-1')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey('dish-qty-1'))).data, '3');
      expect(cart.totalItemCount, 3);

      for (var n = 0; n < 3; n++) {
        await tester.tap(find.byKey(const ValueKey('dish-minus-1')).evaluate().isEmpty ? find.byKey(const ValueKey('dish-add-1')) : find.byKey(const ValueKey('dish-minus-1')));
        await tester.pump();
      }
      expect(cart.items, isEmpty);
      expect(find.byKey(const ValueKey('dish-add-1')), findsOneWidget, reason: 'back to a plain ADD');
    });

    testWidgets('tapping ADD does not open the restaurant, tapping the card does', (tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, searchId: 'sid-1', hits: [makeHit(id: 1)]));
      await tester.pumpWidget(host(DishResultsSection(onOpen: (h) => opened = h)));
      await search(tester, 'pasta');
      await tester.tap(find.byKey(const ValueKey('dish-add-1')));
      await tester.pump();
      expect(opened, isNull);
      await tester.tap(find.text('Honey Hot Chicken Tenders'));
      await tester.pump();
      expect(opened?.itemId, 1);
    });

    testWidgets('the first add is tied to the search (so a delivered order can be counted), repeats are not re-reported', (tester) async {
      await showTwo(tester);
      await tester.tap(find.byKey(const ValueKey('dish-add-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dish-plus-2')));
      await tester.pump();
      expect(attribution.peek(2)?.searchId, 'sid-1');
      expect(attribution.peek(1), isNull, reason: 'only the dish that was added');
      expect(repo.clicks.where((c) => c.$2 == 2), hasLength(1));
    });

    testWidgets('a closed restaurant cannot be added from', (tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, hits: [makeHit(id: 1, open: false)]));
      await tester.pumpWidget(host(const DishResultsSection()));
      await search(tester, 'pasta');
      expect(find.byKey(const ValueKey('dish-add-1')), findsNothing);
      expect(find.textContaining('Closed now'), findsOneWidget);
    });

    testWidgets('adding from another restaurant starts a new cart and says so', (tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, hits: [makeHit(id: 1, restaurantId: 7, restaurant: 'Bella Napoli'), makeHit(id: 2, restaurantId: 9, restaurant: 'Casa Fuego')]));
      await tester.pumpWidget(host(const DishResultsSection()));
      await search(tester, 'dinner');
      await tester.tap(find.byKey(const ValueKey('dish-add-1')));
      await tester.pump();
      expect(find.textContaining('Started a new cart'), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('dish-add-2')));
      await tester.tap(find.byKey(const ValueKey('dish-add-2')));
      await tester.pump();
      expect(find.textContaining('Started a new cart with Casa Fuego'), findsOneWidget);
      expect(cart.items.map((i) => i.foodItem.id), ['api_2'], reason: 'the old restaurant\'s dish is gone from the cart');
      expect(cart.activeRestaurant?.id, 'api_9');
    });

    testWidgets('the cart line is the same one the restaurant page makes', (tester) async {
      final hit = makeHit(id: 68, restaurantId: 6, restaurant: 'Casa Fuego');
      expect(foodItemFromHit(hit).id, 'api_68');
      expect(foodItemFromHit(hit).backendItemId, 68);
      expect(restaurantFromHit(hit).id, 'api_6');
      expect(restaurantFromHit(hit).backendId, 6);
      expect(restaurantFromHit(hit).name, 'Casa Fuego');
    });
  });

  group('filter chips and what each filter shows', () {
    Widget chips() => host(const Column(children: [SearchScopeChips(), DishResultsSection()]));

    testWidgets('the chips appear only while there is a search', (tester) async {
      await tester.pumpWidget(chips());
      expect(find.byKey(const ValueKey('scope-chips')), findsNothing);
      await search(tester, 'pasta');
      expect(find.byKey(const ValueKey('scope-chips')), findsOneWidget);
      expect(find.text('Dishes'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Cravings'), findsOneWidget);
    });

    testWidgets('Dishes and Cravings search again with their own type; tapping the chosen one goes back to everything', (tester) async {
      await tester.pumpWidget(chips());
      await search(tester, 'pasta');
      expect(repo.types.last, isNull);

      await tester.tap(find.byKey(const ValueKey('scope-dishes')));
      await tester.pump();
      await tester.pump();
      expect(state.scope, SearchScope.dishes);
      expect(repo.types.last, 'dish');

      await tester.tap(find.byKey(const ValueKey('scope-cravings')));
      await tester.pump();
      await tester.pump();
      expect(repo.types.last, 'craving');

      await tester.tap(find.byKey(const ValueKey('scope-cravings')));
      await tester.pump();
      await tester.pump();
      expect(state.scope, SearchScope.all);
      expect(repo.types.last, isNull);
    });

    testWidgets('Restaurants hides the dish results and fetches no dishes', (tester) async {
      await tester.pumpWidget(chips());
      await search(tester, 'pasta');
      expect(find.byKey(const ValueKey('dish-results')), findsOneWidget);
      final callsBefore = repo.calls.length;

      await tester.tap(find.byKey(const ValueKey('scope-restaurants')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('dish-results')), findsNothing);
      expect(repo.calls.length, callsBefore, reason: 'restaurants are filtered on the screen, no dish search is made');
      expect(find.byKey(const ValueKey('scope-chips')), findsOneWidget, reason: 'the chips stay so the choice can be changed');
    });

    testWidgets('each filter says what an empty answer means', (tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, hits: const [], flavors: const [], facets: const []));
      await tester.pumpWidget(chips());
      await search(tester, 'injera');
      expect(find.textContaining('Try describing the taste'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('scope-dishes')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('No dish matches "injera". Try Cravings'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('scope-cravings')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Nothing matches that craving yet'), findsOneWidget);
    });

    testWidgets('clearing the search forgets the filter', (tester) async {
      await tester.pumpWidget(chips());
      await search(tester, 'pasta');
      await tester.tap(find.byKey(const ValueKey('scope-dishes')));
      await tester.pump();
      state.clear();
      await tester.pump();
      expect(state.scope, SearchScope.all);
      expect(find.byKey(const ValueKey('scope-chips')), findsNothing);
    });
  });

  group('the dish placeholder', () {
    test('picks an emoji that fits the dish', () {
      expect(dishEmoji('Spaghetti Carbonara'), '🍝');
      expect(dishEmoji('Pesto Gnocchi'), '🍝');
      expect(dishEmoji('Tiramisu'), '🍰');
      expect(dishEmoji('Margherita Pizza'), '🍕');
      expect(dishEmoji('Chicken Tikka Pizza'), '🍕', reason: 'the name decides, not an ingredient');
      expect(dishEmoji('Beef Birria Tacos'), '🌮');
      expect(dishEmoji('Tonkotsu Ramen'), '🍜');
      expect(dishEmoji('Greek Salad'), '🥗');
      expect(dishEmoji('Spicy Ginger Cookie Box'), '🍪');
      expect(dishEmoji('Pineapple Jalapeno Cooler'), '🥤');
      expect(dishEmoji('Honey Hot Chicken Tenders'), '🍗');
    });

    test('falls back to the description, then to a bowl or a plate', () {
      expect(dishEmoji('Chef Special', description: 'Slow cooked beef ribs'), '🥩');
      expect(dishEmoji('Mystery', veg: true), '🥘');
      expect(dishEmoji('Mystery', veg: false), '🍽️');
    });

    testWidgets('a result without a photo shows its emoji, not the old cutlery icon', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: DishResultCard(hit: makeHit(id: 1, name: 'Tiramisu')))));
      expect(find.text('🍰'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu_rounded), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/models/dish_search_models.dart';
import 'package:tomatoo/models/dish_search_state.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/widgets/search/dish_result_card.dart';
import 'package:tomatoo/widgets/search/dish_results_section.dart';

import 'fakes/fake_dish_search.dart';

void main() {
  late FakeDishSearchRepository repo;
  late DishSearchState state;
  DishHit? opened;

  setUp(() {
    repo = FakeDishSearchRepository();
    state = DishSearchState(repository: repo, debounce: const Duration(milliseconds: 10));
    opened = null;
  });

  tearDown(() => state.dispose());

  Widget host(Widget child) => ChangeNotifierProvider<DishSearchState>.value(
        value: state,
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
      expect(find.text('Sweet'), findsNWidgets(3));
      expect(find.text('Spicy'), findsNWidgets(3));
      expect(find.text('Tagged sweet + spicy by the restaurant'), findsNWidgets(2), reason: 'hits 1 and 3 share this reason');
      expect(find.text('Looks sweet + spicy from its description'), findsOneWidget);
      expect(find.text('₹379'), findsNWidgets(2));
      expect(find.text('₹149'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
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
    Widget card(DishHit h) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DishResultCard(hit: h, rank: 1))));

    testWidgets('shows a closed restaurant, spice flames from level 2 and the veg mark', (tester) async {
      await tester.pumpWidget(card(makeHit(open: false, spice: 3, veg: true)));
      expect(find.textContaining('Closed now'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNWidgets(3));
      expect(find.byTooltip('Vegetarian'), findsOneWidget);
    });

    testWidgets('mild dishes show no flames and other tags are outlined, not filled', (tester) async {
      await tester.pumpWidget(card(makeHit(spice: 1, matched: const ['sweet'], tags: const ['sweet', 'creamy', 'rich', 'comfort', 'light'])));
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
      expect(find.text('Sweet'), findsOneWidget);
      expect(find.text('Creamy'), findsOneWidget);
      expect(find.text('Light'), findsNothing, reason: 'at most 3 extra tags');
    });
  });
}

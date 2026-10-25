import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/models/dish_search_state.dart';
import 'package:tomatoo/models/insights_models.dart';
import 'package:tomatoo/models/owner_insights_state.dart';
import 'package:tomatoo/models/trending_state.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/widgets/owner/insights_tab.dart';
import 'package:tomatoo/widgets/search/trending_chips.dart';

import 'fakes/fake_dish_search.dart';
import 'fakes/fake_insights.dart';

void main() {
  group('TrendingChips', () {
    late FakeTrendingRepository trending;
    late TrendingState trendingState;
    late DishSearchState searchState;
    String? picked;

    setUp(() {
      trending = FakeTrendingRepository();
      trendingState = TrendingState(repository: trending);
      searchState = DishSearchState(repository: FakeDishSearchRepository(), debounce: const Duration(milliseconds: 10));
      picked = null;
    });

    tearDown(() {
      trendingState.dispose();
      searchState.dispose();
    });

    Widget host() => MultiProvider(
          providers: [
            ChangeNotifierProvider<TrendingState>.value(value: trendingState),
            ChangeNotifierProvider<DishSearchState>.value(value: searchState),
          ],
          child: MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: TrendingChips(onPick: (q) => picked = q)))),
        );

    testWidgets('shows the chips and tapping one hands back what to search for', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();
      expect(find.text('Trending cravings'), findsOneWidget);
      expect(find.text('Birria Taco'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trending-chip-Birria Taco')));
      expect(picked, 'birria tacos');
    });

    testWidgets('shows nothing when nothing is trending or the load failed', (tester) async {
      trending.chips = const [];
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('trending-chips')), findsNothing);
    });

    testWidgets('hides while a search is showing and returns when it is cleared', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('trending-chips')), findsOneWidget);
      searchState.onQueryChanged('creamy and comforting');
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();
      expect(find.byKey(const ValueKey('trending-chips')), findsNothing);
      searchState.clear();
      await tester.pump();
      expect(find.byKey(const ValueKey('trending-chips')), findsOneWidget);
    });
  });

  group('OwnerInsightsTab', () {
    late FakeOwnerInsightsRepository repo;
    late OwnerInsightsState state;
    OwnerSuggestion? addDishCalledWith;
    bool addDishSaves = true;

    setUp(() {
      repo = FakeOwnerInsightsRepository();
      state = OwnerInsightsState(repository: repo);
      addDishCalledWith = null;
      addDishSaves = true;
    });

    tearDown(() => state.dispose());

    Widget host() => ChangeNotifierProvider<OwnerInsightsState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: OwnerInsightsTab(onAddDish: (s) async {
                addDishCalledWith = s;
                return addDishSaves;
              }),
            ),
          ),
        );

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();
    }

    testWidgets('an empty state says why, not an error', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('insights-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('insights-error')), findsNothing);
    });

    testWidgets('a load failure shows a retry', (tester) async {
      repo.loadError = ApiException('Could not reach the server', statusCode: 500);
      await open(tester);
      expect(find.byKey(const ValueKey('insights-error')), findsOneWidget);
      repo.loadError = null;
      repo.data = OwnerInsights(suggestions: [makeSuggestion(id: 1)]);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('suggestion-1')), findsOneWidget);
    });

    testWidgets('each type shows its label, its numbers and its own button', (tester) async {
      repo.data = OwnerInsights(
        restaurants: const [OwnerRestaurantRef(2, 'Bella Napoli'), OwnerRestaurantRef(6, 'Casa Fuego')],
        suggestions: [
          makeSuggestion(id: 1),
          makeSuggestion(id: 2, type: SuggestionType.makeDrop, restaurant: 'Casa Fuego', restaurantId: 6, headline: 'Turn Beef Birria Tacos into a Drop', unmet: 0, searchers: 38, growth: 19.9, impressions: 38, taps: 3),
          makeSuggestion(id: 3, type: SuggestionType.stockUp, headline: 'Searches for "Pizza" are up 2.4×', unmet: 0, growth: 2.4, searchers: 12, impressions: 40, taps: 6),
        ],
        rising: const [RisingPhrase(label: 'Italian × Korean fusion', recentSearchers: 120, growth: 22, unmetShare: 1.0)],
      );
      await open(tester);

      expect(find.text('Add a dish'), findsOneWidget);
      expect(find.text('Make it a Drop'), findsOneWidget);
      expect(find.text('Keep more ready'), findsOneWidget);
      expect(find.text('Add this dish'), findsOneWidget);
      expect(find.text('Create this Drop'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('120 searchers'), findsOneWidget);
      expect(find.text('22× usual'), findsOneWidget);
      expect(find.text('100% found nothing'), findsOneWidget);
      expect(find.text('shown 38×, tapped 3×'), findsOneWidget);
      expect(find.text('Casa Fuego'), findsOneWidget, reason: 'with several restaurants each card says which');
      expect(find.byKey(const ValueKey('suggestion-prefill-1')), findsOneWidget);
      expect(find.text('Trending across Cravey'), findsOneWidget);
      expect(find.textContaining('no menu serves it yet'), findsOneWidget);
    });

    testWidgets('the restaurant name is left out when the owner has one restaurant', (tester) async {
      repo.data = OwnerInsights(restaurants: const [OwnerRestaurantRef(2, 'Bella Napoli')], suggestions: [makeSuggestion(id: 1)]);
      await open(tester);
      expect(find.text('Bella Napoli'), findsNothing);
    });

    testWidgets('add this dish opens the form callback and closes the card only when the dish was saved', (tester) async {
      repo.data = OwnerInsights(suggestions: [makeSuggestion(id: 1)]);
      addDishSaves = false;
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('suggestion-primary-1')));
      await tester.pump();
      await tester.pump();
      expect(addDishCalledWith?.payload.suggestedName, 'Kimchi Carbonara');
      expect(find.byKey(const ValueKey('suggestion-1')), findsOneWidget, reason: 'cancelled form: suggestion stays');
      expect(repo.calls, isNot(contains('acted:1')));

      addDishSaves = true;
      await tester.tap(find.byKey(const ValueKey('suggestion-primary-1')));
      await tester.pump();
      await tester.pump();
      expect(repo.calls, contains('acted:1'));
      expect(find.byKey(const ValueKey('suggestion-1')), findsNothing);
    });

    testWidgets('create this Drop confirms size and title, then sends them', (tester) async {
      repo.data = OwnerInsights(suggestions: [makeSuggestion(id: 2, type: SuggestionType.makeDrop, unmet: 0)]);
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('suggestion-primary-2')));
      await tester.pumpAndSettle();
      expect(find.text('Create this Drop'), findsWidgets);
      expect(find.byKey(const ValueKey('drop-when')), findsOneWidget);
      expect(find.textContaining('26 Oct, 18:00 to 21:00'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('drop-slots')), '0');
      await tester.tap(find.byKey(const ValueKey('drop-create')));
      await tester.pump();
      expect(find.byKey(const ValueKey('drop-error')), findsOneWidget, reason: 'bad size is refused before anything is sent');
      expect(repo.calls.where((c) => c.startsWith('drop')), isEmpty);

      await tester.enterText(find.byKey(const ValueKey('drop-slots')), '25');
      await tester.enterText(find.byKey(const ValueKey('drop-title')), 'Birria night');
      await tester.tap(find.byKey(const ValueKey('drop-create')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('drop:Birria night:25:2'));
      expect(find.byKey(const ValueKey('suggestion-2')), findsNothing);
    });

    testWidgets('later and not for me remove the card', (tester) async {
      repo.data = OwnerInsights(suggestions: [makeSuggestion(id: 1), makeSuggestion(id: 2, type: SuggestionType.stockUp)]);
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('suggestion-snooze-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('suggestion-dismiss-2')));
      await tester.pump();
      expect(repo.calls, containsAll(['snooze:1', 'dismiss:2']));
      expect(find.byKey(const ValueKey('suggestion-1')), findsNothing);
      expect(find.byKey(const ValueKey('suggestion-2')), findsNothing);
    });

    testWidgets('a failed dismiss brings the card back with the reason', (tester) async {
      repo.data = OwnerInsights(suggestions: [makeSuggestion(id: 1)]);
      await open(tester);
      repo.actionError = ApiException('server down', statusCode: 500);
      await tester.tap(find.byKey(const ValueKey('suggestion-dismiss-1')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('suggestion-1')), findsOneWidget);
      expect(find.text('server down'), findsOneWidget);
    });

    testWidgets('an estimate shows as a fact on the card, and is absent when there is none', (tester) async {
      repo.data = OwnerInsights(suggestions: [
        makeSuggestion(
          id: 2,
          type: SuggestionType.makeDrop,
          payload: const SuggestionPayload(dishId: 68, dishName: 'Beef Birria Tacos', price: 399, suggestedSlots: 10, estimate: SuggestionEstimate(weeklyOrders: 14, weeklyRevenue: 5586, ordersObserved: 28, tapsObserved: 80)),
        ),
        makeSuggestion(id: 3, type: SuggestionType.stockUp),
      ]);
      await open(tester);
      expect(find.byKey(const ValueKey('suggestion-estimate-2')), findsOneWidget);
      expect(find.text('about 14 orders a week'), findsOneWidget);
      expect(find.byKey(const ValueKey('suggestion-estimate-3')), findsNothing);
    });

    testWidgets('the search-orders banner shows only when search has brought orders, with the phrases that have enough', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('search-orders')), findsNothing);

      repo.data = const OwnerInsights(searchOrders: SearchOrders(days: 28, orders: 9, units: 12, revenue: 3591, topPhrases: [PhraseOrders('Birria Taco', 6, 2394)]));
      await state.load();
      await tester.pump();
      expect(find.byKey(const ValueKey('search-orders')), findsOneWidget);
      expect(find.textContaining('9 delivered orders (₹3591) in the last 28 days'), findsOneWidget);
      expect(find.byKey(const ValueKey('search-orders-Birria Taco')), findsOneWidget);
      expect(find.textContaining('never see who ordered'), findsOneWidget);
    });

    testWidgets('one order reads in the singular', (tester) async {
      repo.data = const OwnerInsights(searchOrders: SearchOrders(orders: 1, revenue: 399));
      await open(tester);
      expect(find.textContaining('1 delivered order (₹399)'), findsOneWidget);
    });
  });
}

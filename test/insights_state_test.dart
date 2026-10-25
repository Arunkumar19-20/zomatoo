import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/insights_models.dart';
import 'package:tomatoo/models/owner_insights_state.dart';
import 'package:tomatoo/models/trending_state.dart';
import 'package:tomatoo/services/api_client.dart';

import 'fakes/fake_insights.dart';

void main() {
  group('TrendingState', () {
    test('loads the chips once', () async {
      final repo = FakeTrendingRepository();
      final state = TrendingState(repository: repo);
      await state.ensureLoaded();
      await state.ensureLoaded();
      expect(state.chips.map((c) => c.label), ['Birria Taco']);
      expect(repo.calls, 1);
    });

    test('a failure shows nothing instead of an error, and refresh can recover', () async {
      final repo = FakeTrendingRepository()..fails = true;
      final state = TrendingState(repository: repo);
      await state.ensureLoaded();
      expect(state.chips, isEmpty);
      repo.fails = false;
      await state.refresh();
      expect(state.chips, hasLength(1));
    });

    test('a failed refresh keeps the chips already shown', () async {
      final repo = FakeTrendingRepository();
      final state = TrendingState(repository: repo);
      await state.ensureLoaded();
      repo.fails = true;
      await state.refresh();
      expect(state.chips, hasLength(1));
    });
  });

  group('OwnerInsightsState', () {
    late FakeOwnerInsightsRepository repo;
    late OwnerInsightsState state;
    final a = makeSuggestion(id: 1);
    final b = makeSuggestion(id: 2, type: SuggestionType.makeDrop, restaurant: 'Casa Fuego', restaurantId: 6);

    setUp(() {
      repo = FakeOwnerInsightsRepository()
        ..data = OwnerInsights(
          restaurants: const [OwnerRestaurantRef(2, 'Bella Napoli')],
          suggestions: [a, b],
          rising: const [RisingPhrase(label: 'Birria Taco', recentSearchers: 38, growth: 20)],
        );
      state = OwnerInsightsState(repository: repo);
    });

    tearDown(() => state.dispose());

    test('load fills suggestions and the market view', () async {
      await state.load();
      expect(state.suggestions.map((s) => s.id), [1, 2]);
      expect(state.rising.single.label, 'Birria Taco');
      expect(state.loadedOnce, isTrue);
      expect(state.error, isNull);
    });

    test('a load failure is reported and can be retried', () async {
      repo.loadError = ApiException('boom', statusCode: 500);
      await state.load();
      expect(state.error, 'boom');
      expect(state.loadedOnce, isFalse);
      repo.loadError = null;
      await state.load();
      expect(state.error, isNull);
      expect(state.suggestions, hasLength(2));
    });

    test('a signed-out or non-owner caller gets a plain message', () async {
      repo.loadError = ApiException('Forbidden', statusCode: 403);
      await state.load();
      expect(state.error, 'Please sign in as a restaurant owner.');
    });

    test('dismiss removes the card at once', () async {
      await state.load();
      final err = await state.dismiss(a);
      expect(err, isNull);
      expect(state.suggestions.map((s) => s.id), [2]);
      expect(repo.calls, contains('dismiss:1'));
    });

    test('snooze and acted remove the card too', () async {
      await state.load();
      expect(await state.snooze(a), isNull);
      expect(await state.acted(b), isNull);
      expect(state.suggestions, isEmpty);
      expect(repo.calls, containsAll(['snooze:1', 'acted:2']));
    });

    test('a failed action puts the card back and says why', () async {
      await state.load();
      repo.actionError = ApiException('server down', statusCode: 500);
      final err = await state.dismiss(a);
      expect(err, 'server down');
      expect(state.suggestions.map((s) => s.id), [1, 2]);
    });

    test('a 404 means it is gone, so the card stays removed', () async {
      await state.load();
      repo.actionError = ApiException('gone', statusCode: 404);
      final err = await state.dismiss(a);
      expect(err, 'That suggestion is no longer available.');
      expect(state.suggestions.map((s) => s.id), [2]);
    });

    test('createDrop sends the owner edits and removes the card', () async {
      await state.load();
      final err = await state.createDrop(b, title: 'Birria night', totalSlots: 25);
      expect(err, isNull);
      expect(repo.calls, contains('drop:Birria night:25:2'));
      expect(state.suggestions.map((s) => s.id), [1]);
    });
  });

  group('parsing estimates and search orders', () {
    test('an estimate and the search-orders summary parse', () {
      final ins = OwnerInsights.fromJson({
        'restaurants': [],
        'suggestions': [
          {
            'id': 1, 'restaurantId': 6, 'type': 'MAKE_DROP', 'headline': 'h', 'body': 'b',
            'payload': {'dishId': 68, 'dishName': 'x', 'estimate': {'weeklyOrders': 14, 'weeklyRevenue': 5586, 'ordersObserved': 28, 'tapsObserved': 80, 'basis': 'RESTAURANT'}},
          },
        ],
        'rising': [],
        'searchOrders': {'days': 28, 'orders': 9, 'units': 12, 'revenue': 3591, 'topPhrases': [{'label': 'Birria Taco', 'orders': 6, 'revenue': 2394}]},
      });
      final e = ins.suggestions.single.payload.estimate!;
      expect(e.weeklyOrders, 14);
      expect(e.basis, 'RESTAURANT');
      expect(ins.searchOrders.orders, 9);
      expect(ins.searchOrders.topPhrases.single.label, 'Birria Taco');
    });

    test('an older server that sends neither still parses', () {
      final ins = OwnerInsights.fromJson({'restaurants': [], 'suggestions': [], 'rising': []});
      expect(ins.searchOrders.orders, 0);
      expect(OwnerSuggestion.fromJson({'id': 1, 'restaurantId': 2, 'type': 'STOCK_UP'}).payload.estimate, isNull);
    });
  });

  group('parsing', () {
    test('a suggestion with every field parses', () {
      final s = OwnerSuggestion.fromJson({
        'id': 9, 'restaurantId': 6, 'restaurantName': 'Casa Fuego', 'type': 'MAKE_DROP', 'headline': 'h', 'body': 'b',
        'recentSearchers': 38, 'growth': 19.9, 'unmetShare': 0.0, 'impressions': 38, 'taps': 3,
        'payload': {'dishId': 68, 'dishName': 'Beef Birria Tacos', 'price': 399.0, 'suggestedSlots': 10, 'suggestedStartsAt': '2026-10-26T18:00', 'exampleSearches': ['birria tacos']},
      });
      expect(s.type, SuggestionType.makeDrop);
      expect(s.payload.suggestedStartsAt, DateTime(2026, 10, 26, 18));
      expect(s.payload.price, 399.0);
      expect(s.payload.exampleSearches, ['birria tacos']);
    });

    test('missing optional fields and unknown types do not crash', () {
      final s = OwnerSuggestion.fromJson({'id': 1, 'restaurantId': 2, 'type': 'SOMETHING_NEW'});
      expect(s.type, SuggestionType.stockUp);
      expect(s.payload.flavorTags, isEmpty);
      expect(TrendingChip.fromJson({'label': 'Pizza'}).query, 'Pizza');
    });
  });
}

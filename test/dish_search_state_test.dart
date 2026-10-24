import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/dish_search_models.dart';
import 'package:tomatoo/models/dish_search_state.dart';
import 'package:tomatoo/services/api_client.dart';

import 'fakes/fake_dish_search.dart';

void main() {
  late FakeDishSearchRepository repo;
  late DishSearchState state;

  setUp(() {
    repo = FakeDishSearchRepository();
    state = DishSearchState(repository: repo, debounce: const Duration(milliseconds: 100));
  });

  tearDown(() => state.dispose());

  group('DishSearchState', () {
    testWidgets('waits for the user to stop typing, then searches once', (tester) async {
      state.onQueryChanged('sw');
      state.onQueryChanged('swe');
      state.onQueryChanged('sweet but');
      state.onQueryChanged('sweet but also spicy');
      expect(state.loading, isTrue);
      expect(repo.calls, isEmpty);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(repo.calls, [('sweet but also spicy', 10)]);
      expect(state.loading, isFalse);
      expect(state.response!.hits, hasLength(1));
      expect(state.active, isTrue);
    });

    testWidgets('too-short text searches nothing and clears the old result', (tester) async {
      state.onQueryChanged('creamy');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(state.response, isNotNull);

      state.onQueryChanged('cr');
      expect(state.active, isFalse);
      expect(state.response, isNull);
      expect(state.loading, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.calls, hasLength(1), reason: 'no request for a 2-letter query');
    });

    testWidgets('an answer that arrives after a newer query is ignored', (tester) async {
      final slow = Completer<DishSearchResponse>();
      repo.handler = (q, k) => q == 'slow query' ? slow.future : Future.value(makeResponse(q, hits: [makeHit(name: 'Fast dish')]));

      state.onQueryChanged('slow query');
      await tester.pump(const Duration(milliseconds: 150));
      state.onQueryChanged('fast query');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(state.response!.hits.single.name, 'Fast dish');

      slow.complete(makeResponse('slow query', hits: [makeHit(name: 'Stale dish')]));
      await tester.pump();

      expect(state.response!.hits.single.name, 'Fast dish', reason: 'the stale answer must not overwrite the newer one');
      expect(state.query, 'fast query');
    });

    testWidgets('show more asks for the next page up to the cap', (tester) async {
      repo.handler = (q, k) => Future.value(makeResponse(q, hits: List.generate(k, (i) => makeHit(id: i, name: 'Dish $i')), total: 100));
      state.onQueryChanged('something creamy');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(state.canShowMore, isTrue);

      await state.showMore();
      await state.showMore();
      expect(repo.calls.map((c) => c.$2), [10, 20, 30]);
      expect(state.response!.hits, hasLength(30));
      expect(state.canShowMore, isFalse, reason: 'capped at 30');
    });

    testWidgets('errors are friendly and retry works', (tester) async {
      repo.error = ApiException('boom', statusCode: 500);
      state.onQueryChanged('spicy noodles');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(state.error, 'boom');
      expect(state.loading, isFalse);

      repo.error = null;
      await state.retry();
      expect(state.error, isNull);
      expect(state.response, isNotNull);
    });

    testWidgets('rate limiting gets its own message', (tester) async {
      repo.error = RateLimitException('slow down');
      state.onQueryChanged('spicy noodles');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(state.error, contains('Too many searches'));
    });

    test('DishSearchResponse and DishHit parse the API contract', () {
      final r = DishSearchResponse.fromJson({
        'query': 'sweet but spicy',
        'mode': 'HYBRID',
        'facets': ['sweet', 'spicy'],
        'flavors': ['spicy', 'sweet'],
        'vegOnly': false,
        'maxPrice': 300,
        'total': 55,
        'tookMs': 9,
        'hits': [
          {
            'itemId': 4,
            'name': 'Mango Habanero Wings',
            'description': 'x',
            'price': 399.0,
            'veg': false,
            'imageUrl': null,
            'restaurantId': 5,
            'restaurantName': 'Casa Fuego',
            'restaurantOpen': true,
            'spiceLevel': 4,
            'servingTemp': 'HOT',
            'tags': ['crunchy', 'spicy', 'sweet'],
            'matchedTags': ['spicy', 'sweet'],
            'score': 1.0,
            'reasons': ['Tagged spicy + sweet by the restaurant'],
          }
        ],
      });
      expect(r.hits.single.matchedTags, ['spicy', 'sweet']);
      expect(r.hits.single.spiceLevel, 4);
      expect(r.maxPrice, 300.0);
      expect(r.total, 55);
    });
  });
}

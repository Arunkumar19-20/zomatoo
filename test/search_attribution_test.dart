import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomatoo/models/dish_search_state.dart';
import 'package:tomatoo/services/cart_service.dart';
import 'package:tomatoo/services/search_attribution.dart';
import 'package:tomatoo/services/search_client_id.dart';

import 'fakes/fake_dish_search.dart';

/// Records the requests a Dio makes and answers every one with an empty cart.
class RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int status = 200;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode({'cartId': 1, 'customerId': 2, 'items': []}), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SearchAttribution', () {
    late DateTime now;
    late SearchAttribution attribution;

    setUp(() {
      now = DateTime(2026, 10, 26, 12);
      attribution = SearchAttribution(ttl: const Duration(hours: 2), clock: () => now);
    });

    test('remembers which search led to a dish', () {
      attribution.remember(68, 'sid-1', 3);
      expect(attribution.peek(68)?.searchId, 'sid-1');
      expect(attribution.peek(68)?.rank, 3);
      expect(attribution.peek(69), isNull);
    });

    test('the latest search for a dish wins', () {
      attribution.remember(68, 'sid-1', 1);
      attribution.remember(68, 'sid-2', 2);
      expect(attribution.peek(68)?.searchId, 'sid-2');
    });

    test('forgets after the time limit', () {
      attribution.remember(68, 'sid-1', 1);
      now = now.add(const Duration(hours: 1, minutes: 59));
      expect(attribution.peek(68), isNotNull);
      now = now.add(const Duration(minutes: 2));
      expect(attribution.peek(68), isNull);
    });

    test('forget and clear drop entries', () {
      attribution.remember(1, 'a', 1);
      attribution.remember(2, 'b', 1);
      attribution.forget(1);
      expect(attribution.peek(1), isNull);
      expect(attribution.peek(2), isNotNull);
      attribution.clear();
      expect(attribution.peek(2), isNull);
    });
  });

  group('tapping a result remembers the search', () {
    test('reportOpen records the dish against the search that showed it', () async {
      final attribution = SearchAttribution();
      final repo = FakeDishSearchRepository()..handler = (q, k) async => makeResponse(q, searchId: 'sid-9', hits: [makeHit(id: 5), makeHit(id: 9)]);
      final state = DishSearchState(repository: repo, debounce: const Duration(milliseconds: 5), attribution: attribution);
      addTearDown(state.dispose);
      state.onQueryChanged('birria tacos');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      state.reportOpen(state.response!.hits[1], 2);

      expect(attribution.peek(9)?.searchId, 'sid-9');
      expect(attribution.peek(9)?.rank, 2);
      expect(attribution.peek(5), isNull, reason: 'only the tapped dish');
    });

    test('nothing is remembered when the server did not log the search', () async {
      final attribution = SearchAttribution();
      final repo = FakeDishSearchRepository();
      final state = DishSearchState(repository: repo, debounce: const Duration(milliseconds: 5), attribution: attribution);
      addTearDown(state.dispose);
      state.onQueryChanged('birria tacos');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      state.reportOpen(state.response!.hits.first, 1);
      expect(attribution.peek(state.response!.hits.first.itemId), isNull);
    });
  });

  group('CartService.addItem', () {
    late RecordingAdapter adapter;
    late Dio dio;
    late SearchAttribution attribution;
    late CartService cart;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SearchClientId.reset();
      adapter = RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
      attribution = SearchAttribution();
      cart = CartService(dio: dio, attribution: attribution);
    });

    test('a dish opened from search carries the search id, rank and the anonymous client id', () async {
      attribution.remember(68, 'sid-1', 3);
      await cart.addItem(menuItemId: 68);

      final req = adapter.requests.single;
      expect(req.path, '/cart/items');
      expect(req.data, {'menuItemId': 68, 'quantity': 1, 'searchId': 'sid-1', 'searchRank': 3});
      expect(req.headers['X-Search-Client'], isA<String>());
      expect((req.headers['X-Search-Client'] as String).length, greaterThanOrEqualTo(16));
    });

    test('a plain add sends no search context and no client id', () async {
      await cart.addItem(menuItemId: 68);
      final req = adapter.requests.single;
      expect(req.data, {'menuItemId': 68, 'quantity': 1});
      expect(req.headers.containsKey('X-Search-Client'), isFalse);
    });

    test('the context is used once: a later add of the same dish does not reuse it', () async {
      attribution.remember(68, 'sid-1', 1);
      await cart.addItem(menuItemId: 68);
      await cart.addItem(menuItemId: 68);
      expect((adapter.requests[1].data as Map).containsKey('searchId'), isFalse);
    });

    test('a different dish does not borrow another dish\'s search', () async {
      attribution.remember(68, 'sid-1', 1);
      await cart.addItem(menuItemId: 99);
      expect((adapter.requests.single.data as Map).containsKey('searchId'), isFalse);
    });

    test('a failed add keeps the context so a retry still counts', () async {
      attribution.remember(68, 'sid-1', 1);
      adapter.status = 500;
      await expectLater(cart.addItem(menuItemId: 68), throwsA(anything));
      expect(attribution.peek(68), isNotNull);
    });
  });
}

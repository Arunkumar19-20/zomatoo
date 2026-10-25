import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomatoo/models/cart_state.dart';
import 'package:tomatoo/models/dish_search_state.dart';
import 'package:tomatoo/services/cart_service.dart';
import 'package:tomatoo/services/dish_search_service.dart';
import 'package:tomatoo/services/search_attribution.dart';
import 'package:tomatoo/services/search_client_id.dart';
import 'package:tomatoo/services/search_privacy.dart';
import 'package:tomatoo/widgets/search/dish_results_section.dart';
import 'package:tomatoo/widgets/search/search_privacy_widgets.dart';

import 'fakes/fake_dish_search.dart';

/// Records the requests a Dio makes; answers a search with no hits and anything else with an empty cart.
class _Recorder implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final body = options.path.contains('/search/dishes') ? {'query': 'q', 'mode': 'HYBRID', 'hits': []} : {'cartId': 1, 'customerId': 2, 'items': []};
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SearchClientId.reset();
    SearchPrivacy.reset();
  });

  tearDown(() => SearchPrivacy.reset());

  group('the stored choice', () {
    test('counting is on and the notice unseen until the customer says otherwise', () async {
      await SearchPrivacy.load();
      expect(SearchPrivacy.optedOut, isFalse);
      expect(SearchPrivacy.noticeSeen, isFalse);
    });

    test('turning it off and dismissing the notice survive a restart', () async {
      await SearchPrivacy.setOptedOut(true);
      await SearchPrivacy.markNoticeSeen();
      SearchPrivacy.reset();   // a fresh start of the app
      await SearchPrivacy.load();
      expect(SearchPrivacy.optedOut, isTrue);
      expect(SearchPrivacy.noticeSeen, isTrue);
    });

    test('turning it back on is remembered too', () async {
      await SearchPrivacy.setOptedOut(true);
      await SearchPrivacy.setOptedOut(false);
      SearchPrivacy.reset(optedOut: true);
      await SearchPrivacy.load();
      expect(SearchPrivacy.optedOut, isFalse);
    });
  });

  group('what the app sends', () {
    late _Recorder rec;
    late Dio dio;

    setUp(() {
      rec = _Recorder();
      dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = rec;
    });

    test('searches carry the anonymous id when counting is on, and no Do Not Track', () async {
      await DishSearchService(dio: dio).search('pasta');
      final h = rec.requests.single.headers;
      expect(h['X-Search-Client'], isA<String>());
      expect(h.containsKey('DNT'), isFalse);
    });

    test('searches ask not to be tracked, and do not even send the anonymous id, once it is off', () async {
      SearchPrivacy.reset(optedOut: true);
      await DishSearchService(dio: dio).search('pasta');
      final h = rec.requests.single.headers;
      expect(h['DNT'], '1');
      expect(h.containsKey('X-Search-Client'), isFalse);
    });

    test('a tap on a result is reported when counting is on and never when it is off', () async {
      final service = DishSearchService(dio: dio);
      await service.reportClick('sid', 5, 1);
      expect(rec.requests.where((r) => r.path.contains('/click')), hasLength(1));
      SearchPrivacy.reset(optedOut: true);
      await service.reportClick('sid', 5, 1);
      expect(rec.requests.where((r) => r.path.contains('/click')), hasLength(1), reason: 'no second request');
    });

    test('a cart add carries the search only while counting is on, so no order is ever linked to a search once it is off', () async {
      final attribution = SearchAttribution()..remember(68, 'sid-1', 2);
      final cart = CartService(dio: dio, attribution: attribution);

      SearchPrivacy.reset(optedOut: true);
      await cart.addItem(menuItemId: 68);
      expect((rec.requests.last.data as Map).containsKey('searchId'), isFalse);
      expect(rec.requests.last.headers.containsKey('X-Search-Client'), isFalse);

      SearchPrivacy.reset(optedOut: false);
      await cart.addItem(menuItemId: 68);
      expect((rec.requests.last.data as Map)['searchId'], 'sid-1');
    });

    test('opened results are neither reported nor remembered for the cart when it is off', () async {
      SearchPrivacy.reset(optedOut: true);
      final attribution = SearchAttribution();
      final repo = FakeDishSearchRepository()..handler = (q, k) async => makeResponse(q, searchId: 'sid-1', hits: [makeHit(id: 5)]);
      final state = DishSearchState(repository: repo, debounce: const Duration(milliseconds: 5), attribution: attribution);
      addTearDown(state.dispose);
      state.onQueryChanged('pasta');
      while (state.loading || state.response == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5)); // wait for the answer, however busy the machine is
      }
      state.reportOpen(state.response!.hits.first, 1);
      expect(repo.clicks, isEmpty);
      expect(attribution.peek(5), isNull);
    });
  });

  group('the notice and the switch', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

    testWidgets('the notice says what is counted, once, and "Got it" dismisses it for good', (tester) async {
      await tester.pumpWidget(host(const SearchPrivacyNotice()));
      expect(find.byKey(const ValueKey('search-privacy-notice')), findsOneWidget);
      expect(find.textContaining('never who you are'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('search-privacy-ok')));
      await tester.pump();
      expect(find.byKey(const ValueKey('search-privacy-notice')), findsNothing);
      expect(SearchPrivacy.noticeSeen, isTrue);
      expect(SearchPrivacy.optedOut, isFalse, reason: 'dismissing is not opting out');
    });

    testWidgets('"Turn off" opts out and dismisses the notice', (tester) async {
      await tester.pumpWidget(host(const SearchPrivacyNotice()));
      await tester.tap(find.byKey(const ValueKey('search-privacy-off')));
      await tester.pump();
      await tester.pump();
      expect(SearchPrivacy.optedOut, isTrue);
      expect(find.byKey(const ValueKey('search-privacy-notice')), findsNothing);
    });

    testWidgets('no notice for someone who already chose', (tester) async {
      SearchPrivacy.reset(optedOut: true);
      await tester.pumpWidget(host(const SearchPrivacyNotice()));
      expect(find.byKey(const ValueKey('search-privacy-notice')), findsNothing);
      SearchPrivacy.reset(noticeSeen: true);
      await tester.pump();
      expect(find.byKey(const ValueKey('search-privacy-notice')), findsNothing);
    });

    testWidgets('the profile switch shows the state and flips it, with the promise or the confirmation', (tester) async {
      await tester.pumpWidget(host(const SearchPrivacyTile()));
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('search-privacy-switch'))).value, isTrue);
      expect(find.textContaining('never who you are'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('search-privacy-switch')));
      await tester.pump();
      await tester.pump();
      expect(SearchPrivacy.optedOut, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('search-privacy-switch'))).value, isFalse);
      expect(find.textContaining('nothing about your searches is recorded'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('search-privacy-switch')));
      await tester.pump();
      await tester.pump();
      expect(SearchPrivacy.optedOut, isFalse);
    });

    testWidgets('the first results carry the notice above them', (tester) async {
      final repo = FakeDishSearchRepository();
      final state = DishSearchState(repository: repo, debounce: const Duration(milliseconds: 10), attribution: SearchAttribution());
      addTearDown(state.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [ChangeNotifierProvider<DishSearchState>.value(value: state), ChangeNotifierProvider<CartState>.value(value: CartState())],
        child: host(const DishResultsSection()),
      ));
      state.onQueryChanged('pasta');
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();
      expect(find.byKey(const ValueKey('search-privacy-notice')), findsOneWidget);
      expect(find.byKey(const ValueKey('dish-results')), findsOneWidget);
    });
  });
}

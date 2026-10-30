import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomatoo/models/insights_models.dart';
import 'package:tomatoo/models/trending_state.dart';
import 'package:tomatoo/repositories/insights_repository.dart';
import 'package:tomatoo/services/dish_search_service.dart';
import 'package:tomatoo/services/insights_service.dart';
import 'package:tomatoo/services/search_area.dart';
import 'package:tomatoo/services/search_client_id.dart';
import 'package:tomatoo/services/search_privacy.dart';
import 'package:tomatoo/widgets/search/search_privacy_widgets.dart';

class _Recorder implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final body = options.path.contains('/search/dishes') ? {'query': 'q', 'mode': 'HYBRID', 'hits': []} : [];
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _CountingTrending implements TrendingRepository {
  int calls = 0;
  @override
  Future<List<TrendingChip>> trending({int limit = 6}) async {
    calls++;
    return const [];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SearchClientId.reset();
    SearchPrivacy.reset();
    SearchArea.reset();
  });

  tearDown(() {
    SearchPrivacy.reset();
    SearchArea.reset();
  });

  group('the stored city', () {
    test('is trimmed, single-spaced, capped and empty means none', () {
      expect(SearchArea.clean('  San   Francisco '), 'San Francisco');
      expect(SearchArea.clean('   '), isNull);
      expect(SearchArea.clean(null), isNull);
      expect(SearchArea.clean('x' * 200)!.length, SearchArea.maxLength);
    });

    test('survives a restart, and clearing forgets it', () async {
      await SearchArea.set('Oakland');
      SearchArea.reset();
      await SearchArea.load();
      expect(SearchArea.areaNotifier.value, 'Oakland');
      await SearchArea.set('');
      SearchArea.reset('stale');
      await SearchArea.load();
      expect(SearchArea.areaNotifier.value, isNull);
    });

    test('is never sent once counting is off, and is back when it is on again', () async {
      await SearchArea.set('Oakland');
      expect(SearchArea.current, 'Oakland');
      SearchPrivacy.reset(optedOut: true);
      expect(SearchArea.current, isNull);
      SearchPrivacy.reset(optedOut: false);
      expect(SearchArea.current, 'Oakland');
    });
  });

  group('what the app sends', () {
    late _Recorder rec;
    late Dio dio;

    setUp(() {
      rec = _Recorder();
      dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = rec;
    });

    test('searches and the trending request carry the city when it is set', () async {
      await SearchArea.set('Oakland');
      await DishSearchService(dio: dio).search('pasta');
      await InsightsService(dio: dio).trending();
      expect(rec.requests[0].queryParameters['area'], 'Oakland');
      expect(rec.requests[1].queryParameters['area'], 'Oakland');
    });

    test('nothing about an area is sent when none is set or counting is off', () async {
      await DishSearchService(dio: dio).search('pasta');
      await SearchArea.set('Oakland');
      SearchPrivacy.reset(optedOut: true);
      await DishSearchService(dio: dio).search('pasta');
      await InsightsService(dio: dio).trending();
      for (final r in rec.requests) {
        expect(r.queryParameters.containsKey('area'), isFalse);
      }
    });
  });

  test('the chips are looked up again when the customer changes their city', () async {
    final repo = _CountingTrending();
    final state = TrendingState(repository: repo);
    addTearDown(state.dispose);
    await state.ensureLoaded();
    expect(repo.calls, 1);
    await SearchArea.set('Oakland');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.calls, 2);
  });

  group('the profile tile', () {
    Widget host() => const MaterialApp(home: Scaffold(body: SearchAreaTile()));

    testWidgets('says when no city is set, saves one, and clears it', (tester) async {
      await tester.pumpWidget(host());
      expect(find.textContaining('Not set'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('search-area-tile')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('search-area-field')), '  Oakland ');
      await tester.tap(find.byKey(const ValueKey('search-area-save')));
      await tester.pumpAndSettle();
      expect(find.text('Oakland'), findsOneWidget);
      expect(SearchArea.areaNotifier.value, 'Oakland');

      await tester.tap(find.byKey(const ValueKey('search-area-tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-area-clear')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not set'), findsOneWidget);
      expect(SearchArea.areaNotifier.value, isNull);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await SearchArea.set('Oakland');
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const ValueKey('search-area-tile')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('search-area-field')), 'Somewhere else');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(SearchArea.areaNotifier.value, 'Oakland');
    });
  });
}

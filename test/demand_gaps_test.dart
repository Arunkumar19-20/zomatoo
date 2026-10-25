import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/models/demand_gap_models.dart';
import 'package:tomatoo/models/demand_gap_state.dart';
import 'package:tomatoo/repositories/demand_gap_repository.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/widgets/admin/demand_gaps_tab.dart';

class _FakeRepo implements DemandGapRepository {
  Future<DemandGapReport> Function(int days)? handler;
  final calls = <int>[];

  @override
  Future<DemandGapReport> load({int days = 14, int min = 5}) {
    calls.add(days);
    return handler != null ? handler!(days) : Future.value(const DemandGapReport());
  }
}

DemandGapReport sample({int days = 14}) => DemandGapReport(
      days: days,
      unmetSearches: 724,
      phrasesShown: 3,
      phrasesBelowMinimum: 10,
      groups: const [
        DemandGapGroup(
          cuisine: 'korean',
          label: 'Korean',
          status: DemandGapStatus.noRestaurant,
          searcherDays: 135,
          restaurantsServing: 0,
          openRestaurantsServing: 0,
          gaps: [
            DemandGap(key: 'fusion:italian+korean', label: 'Italian × Korean fusion', kind: 'FUSION', searcherDays: 135, activeDays: 12, alsoCuisines: ['italian'], examples: ['kimchi carbonara', 'bulgogi pizza']),
          ],
        ),
        DemandGapGroup(
          cuisine: 'italian',
          label: 'Italian',
          status: DemandGapStatus.dishGap,
          searcherDays: 135,
          restaurantsServing: 2,
          openRestaurantsServing: 1,
          gaps: [
            DemandGap(key: 'fusion:italian+korean', label: 'Italian × Korean fusion', kind: 'FUSION', searcherDays: 135, activeDays: 12, alsoCuisines: ['korean'], examples: ['kimchi carbonara']),
          ],
        ),
        DemandGapGroup(
          cuisine: 'other',
          label: 'Other cravings',
          status: DemandGapStatus.noCuisine,
          searcherDays: 48,
          gaps: [
            DemandGap(key: 'dish:chocolate+dubai', label: 'dubai chocolate', kind: 'DISH', searcherDays: 48, activeDays: 1, examples: ['dubai chocolate']),
          ],
        ),
      ],
    );

void main() {
  test('DemandGapReport reads a live /admin/search/demand-gaps response', () {
    final r = DemandGapReport.fromJson(jsonDecode(File('test/fixtures/api_demand_gaps.json').readAsStringSync()) as Map<String, dynamic>);
    expect(r.days, 14);
    expect(r.minSearcherDays, 5);
    expect(r.unmetSearches, greaterThan(0));
    expect(r.groups, isNotEmpty);
    final korean = r.groups.firstWhere((g) => g.cuisine == 'korean');
    expect(korean.status, DemandGapStatus.noRestaurant);
    expect(korean.restaurantsServing, 0);
    final fusion = korean.gaps.firstWhere((g) => g.kind == 'FUSION');
    expect(fusion.alsoCuisines, ['italian']);
    expect(fusion.examples, isNotEmpty);
    final other = r.groups.firstWhere((g) => g.cuisine == 'other');
    expect(other.status, DemandGapStatus.noCuisine);
    expect(other.restaurantsServing, isNull, reason: 'no supply figure for cravings that name no cuisine');
    final groupDemand = r.groups.map((g) => g.searcherDays).toList();
    expect(groupDemand, orderedEquals([...groupDemand]..sort((a, b) => b.compareTo(a))), reason: 'biggest first');
  });

  group('DemandGapState', () {
    test('loads, and a failure is explained and can be retried', () async {
      final repo = _FakeRepo()..handler = (d) async => throw ApiException('Admin only', statusCode: 403);
      final state = DemandGapState(repository: repo);
      await state.load();
      expect(state.error, 'Admin only');
      expect(state.report, isNull);
      repo.handler = (d) async => sample();
      await state.load();
      expect(state.error, isNull);
      expect(state.report!.groups, hasLength(3));
      expect(state.loading, isFalse);
    });

    test('changing the window loads again and an old answer never overwrites a newer one', () async {
      final repo = _FakeRepo();
      final slow = Completer<DemandGapReport>();
      repo.handler = (d) => d == 7 ? slow.future : Future.value(sample(days: d));
      final state = DemandGapState(repository: repo);
      final first = state.setDays(7);   // slow
      await state.setDays(30);          // fast, started later
      expect(state.report!.days, 30);
      slow.complete(sample(days: 7));
      await first;
      expect(state.report!.days, 30, reason: 'the 7-day answer arrived late and is ignored');
      expect(repo.calls, [7, 30]);
      await state.setDays(30);
      expect(repo.calls, [7, 30], reason: 'same window, nothing to load');
    });

    test('keeps the last report on screen while the next window loads', () async {
      final repo = _FakeRepo();
      final state = DemandGapState(repository: repo);
      repo.handler = (d) async => sample(days: d);
      await state.load();
      final gate = Completer<DemandGapReport>();
      repo.handler = (d) => gate.future;
      final next = state.setDays(30);
      expect(state.loading, isTrue);
      expect(state.report!.days, 14);
      gate.complete(sample(days: 30));
      await next;
      expect(state.report!.days, 30);
    });
  });

  group('DemandGapsTab', () {
    late _FakeRepo repo;

    Future<DemandGapState> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final state = DemandGapState(repository: repo);
      addTearDown(state.dispose);
      await state.load();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ChangeNotifierProvider.value(value: state, child: const DemandGapsTab())),
      ));
      await tester.pump();
      return state;
    }

    setUp(() => repo = _FakeRepo()..handler = (d) async => sample(days: d));

    testWidgets('shows each cuisine with its demand and how many restaurants serve it', (tester) async {
      await show(tester);
      expect(find.byKey(const ValueKey('demand-group-korean')), findsOneWidget);
      expect(find.text('No restaurant serves this'), findsOneWidget);
      expect(find.text('Served, but these are missing'), findsOneWidget);
      expect(find.text('No cuisine named'), findsOneWidget);
      expect(find.text('0 restaurants serve it (0 open)'), findsOneWidget);
      expect(find.text('2 restaurants serve it (1 open)'), findsOneWidget);
      expect(find.byKey(const ValueKey('demand-supply-other')), findsNothing, reason: 'no supply figure for the no-cuisine group');
      expect(find.textContaining('Italian × Korean fusion · 135 searcher-days over 12 days'), findsNWidgets(2));
      expect(find.textContaining('"kimchi carbonara", "bulgogi pizza"'), findsOneWidget);
    });

    testWidgets('says so when a craving was all on one day, and explains what was left out', (tester) async {
      await show(tester);
      expect(find.textContaining('All on one day'), findsOneWidget);
      expect(find.textContaining('724 searches found nothing in the last 14 days'), findsOneWidget);
      expect(find.textContaining('leaving out 10 smaller ones'), findsOneWidget);
    });

    testWidgets('picking another window asks for it', (tester) async {
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('demand-days-30')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 30);
      expect(find.textContaining('in the last 30 days'), findsOneWidget);
    });

    testWidgets('an empty report says why, without hiding that searches found nothing', (tester) async {
      repo.handler = (d) async => const DemandGapReport(unmetSearches: 12);
      await show(tester);
      expect(find.byKey(const ValueKey('demand-empty')), findsOneWidget);
      expect(find.textContaining('12 searches found nothing'), findsOneWidget);
      expect(find.textContaining('at least 5 people'), findsOneWidget);
    });

    testWidgets('an error shows a retry that works', (tester) async {
      repo.handler = (d) async => throw ApiException('Could not reach the server', statusCode: 500);
      final state = await show(tester);
      expect(find.byKey(const ValueKey('demand-error')), findsOneWidget);
      expect(find.text('Could not reach the server'), findsOneWidget);
      repo.handler = (d) async => sample(days: d);
      await tester.tap(find.byKey(const ValueKey('demand-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('demand-error')), findsNothing);
      expect(state.report, isNotNull);
      expect(find.byKey(const ValueKey('demand-group-korean')), findsOneWidget);
    });
  });
}

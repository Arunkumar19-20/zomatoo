import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/models/drop_models.dart';
import 'package:tomatoo/models/drop_state.dart';
import 'package:tomatoo/screens/drop_detail_screen.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/services/session_provider.dart';
import 'package:tomatoo/widgets/drops/countdown_text.dart';
import 'package:tomatoo/widgets/drops/drops_section.dart';
import 'package:tomatoo/widgets/drops/hold_banner.dart';

import 'fakes/fake_drop_repository.dart';

class _Session extends SessionProvider {
  bool loggedIn;
  _Session(this.loggedIn);

  @override
  bool get isLoggedIn => loggedIn;
}

void main() {
  final serverNow = DateTime(2026, 10, 22, 12);
  late FakeDropRepository repo;
  late DateTime deviceNow;
  late DropState state;
  late _Session session;
  final pushed = <RouteSettings>[];

  setUp(() {
    repo = FakeDropRepository();
    deviceNow = serverNow;
    pushed.clear();
    session = _Session(true);
    state = DropState(repository: repo, isLoggedIn: () => session.isLoggedIn, clock: () => deviceNow);
  });

  tearDown(() {
    state.dispose();
    session.dispose();
  });

  Widget host(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<DropState>.value(value: state),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
          onGenerateRoute: (settings) {
            pushed.add(settings);
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => Scaffold(body: Text('route:${settings.name}:${settings.arguments}')),
            );
          },
        ),
      );

  group('CountdownText', () {
    test('formats minutes, hours and days', () {
      expect(CountdownText.format(const Duration(minutes: 9, seconds: 5)), '09:05');
      expect(CountdownText.format(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(CountdownText.format(const Duration(days: 2, hours: 3)), '2d 3h');
      expect(CountdownText.format(const Duration(seconds: -5)), '00:00');
    });
  });

  group('HoldBanner', () {
    testWidgets('shows a live countdown and disappears when the hold is gone', (tester) async {
      repo.drops = [makeDrop()];
      repo.reservations = [makeHold(expiresAt: serverNow.add(const Duration(minutes: 9, seconds: 30)))];
      await state.refresh();

      await tester.pumpWidget(host(const HoldBanner()));
      expect(find.byKey(const ValueKey('hold-banner')), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Slot held for you'), findsOneWidget);

      deviceNow = serverNow.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('09:00'), findsOneWidget);

      repo.reservations = [];
      deviceNow = serverNow.add(const Duration(minutes: 10));
      await state.refresh();
      await tester.pump();
      expect(find.byKey(const ValueKey('hold-banner')), findsNothing);
    });

    testWidgets('re-syncs with the server when the timer reaches zero', (tester) async {
      repo.drops = [makeDrop()];
      repo.reservations = [makeHold(expiresAt: serverNow.add(const Duration(seconds: 2)))];
      await state.refresh();
      await tester.pumpWidget(host(const HoldBanner()));
      final before = repo.getDropsCalls;

      repo.reservations = []; // server expired it
      deviceNow = serverNow.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();

      expect(repo.getDropsCalls, greaterThan(before));
      expect(find.byKey(const ValueKey('hold-banner')), findsNothing);
    });

    testWidgets('flags a slot that came from the waitlist', (tester) async {
      repo.drops = [makeDrop(status: 'SOLD_OUT', remaining: 0)];
      repo.reservations = [makeHold(id: 61, expiresAt: serverNow.add(const Duration(minutes: 5)))];
      repo.waitlist = [
        WaitlistEntryDto(entryId: 1, dropId: 1, status: 'OFFERED', position: 0, reservationId: 61, serverTime: serverNow),
      ];
      await state.refresh();

      await tester.pumpWidget(host(const HoldBanner()));
      expect(find.text('A slot opened up for you!'), findsOneWidget);
    });

    testWidgets('Checkout opens the drop checkout with the reservation id', (tester) async {
      repo.drops = [makeDrop()];
      repo.reservations = [makeHold(id: 88, expiresAt: serverNow.add(const Duration(minutes: 8)))];
      await state.refresh();

      await tester.pumpWidget(host(const HoldBanner()));
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      expect(pushed.last.name, '/drop-checkout');
      expect(pushed.last.arguments, 88);
    });

    testWidgets('Release asks first, then frees the slot', (tester) async {
      repo.drops = [makeDrop()];
      repo.reservations = [makeHold(id: 90, expiresAt: serverNow.add(const Duration(minutes: 8)))];
      await state.refresh();

      await tester.pumpWidget(host(const HoldBanner()));
      await tester.tap(find.text('Release'));
      await tester.pumpAndSettle();
      expect(find.text('Release this slot?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Release').last);
      await tester.pumpAndSettle();

      expect(repo.released, [90]);
      expect(find.byKey(const ValueKey('hold-banner')), findsNothing);
    });
  });

  group('DropsSection', () {
    testWidgets('lists live and sold-out drops, hides ended ones, opens the detail route', (tester) async {
      repo.drops = [
        makeDrop(id: 1),
        makeDrop(id: 2, status: 'SOLD_OUT', remaining: 0),
        makeDrop(id: 3, status: 'ENDED', remaining: 0),
      ];
      await state.refresh();

      await tester.pumpWidget(host(const DropsSection()));
      expect(find.text('Limited Drops'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('SOLD OUT'), findsOneWidget);
      expect(find.text('ENDED'), findsNothing);
      expect(find.text('4 of 10 left'), findsOneWidget);
      expect(find.text('Waitlist open'), findsOneWidget);

      await tester.tap(find.text('LIVE'));
      await tester.pumpAndSettle();
      expect(pushed.last.name, '/drop');
      expect(pushed.last.arguments, 1);
    });

    testWidgets('renders nothing when there are no drops', (tester) async {
      await state.refresh();
      await tester.pumpWidget(host(const DropsSection()));
      expect(find.byKey(const ValueKey('drops-section')), findsNothing);
    });
  });

  group('DropDetailScreen', () {
    Future<void> open(WidgetTester tester, {int dropId = 1}) async {
      await state.refresh();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<DropState>.value(value: state),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
        ],
        child: MaterialApp(
          home: DropDetailScreen(dropId: dropId),
          onGenerateRoute: (settings) {
            pushed.add(settings);
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => Scaffold(body: Text('route:${settings.name}:${settings.arguments}')),
            );
          },
        ),
      ));
      await tester.pump();
    }

    testWidgets('live drop: reserve takes the hold and goes straight to checkout', (tester) async {
      repo.drops = [makeDrop()];
      repo.onReserve = (_) => repo.reservations = [makeHold(id: 31, expiresAt: serverNow.add(const Duration(minutes: 10)))];
      await open(tester);

      expect(find.text('4 of 10 slots left'), findsOneWidget);
      await tester.tap(find.text('Reserve a slot'));
      await tester.pumpAndSettle();

      expect(repo.reserveCalls, 1);
      expect(pushed.last.name, '/drop-checkout');
      expect(pushed.last.arguments, 31);
    });

    testWidgets('signed-out visitors are sent to login instead of reserving', (tester) async {
      session.loggedIn = false;
      repo.drops = [makeDrop()];
      await open(tester);

      await tester.tap(find.text('Reserve a slot'));
      await tester.pumpAndSettle();

      expect(repo.reserveCalls, 0);
      expect(pushed.last.name, '/login');
    });

    testWidgets('sold out: join the waitlist, see your place, leave again', (tester) async {
      repo.drops = [makeDrop(status: 'SOLD_OUT', remaining: 0)];
      await open(tester);

      expect(find.text('All 10 slots are taken'), findsOneWidget);
      await tester.tap(find.text('Join waitlist'));
      await tester.pumpAndSettle();
      expect(repo.joinCalls, 1);
      expect(find.text("You're #1 in line"), findsOneWidget);

      await tester.tap(find.text('Leave waitlist'));
      await tester.pumpAndSettle();
      expect(repo.leaveCalls, 1);
      expect(find.text('Join waitlist'), findsOneWidget);
    });

    testWidgets('a slot that frees up between refresh and tap is reserved instead', (tester) async {
      repo.drops = [makeDrop(status: 'SOLD_OUT', remaining: 0)];
      repo.joinError = ApiException('Slots are still available', statusCode: 409, code: 'SLOTS_AVAILABLE');
      repo.onReserve = (_) => repo.reservations = [makeHold(id: 41, expiresAt: serverNow.add(const Duration(minutes: 10)))];
      await open(tester);

      await tester.tap(find.text('Join waitlist'));
      await tester.pumpAndSettle();

      expect(repo.reserveCalls, 1);
      expect(pushed.last.arguments, 41);
    });

    testWidgets('a held drop offers checkout instead of reserving twice', (tester) async {
      repo.drops = [makeDrop()];
      repo.reservations = [makeHold(id: 51, expiresAt: serverNow.add(const Duration(minutes: 7)))];
      await open(tester);

      expect(find.text('Reserve a slot'), findsNothing);
      await tester.tap(find.text('Checkout now'));
      await tester.pumpAndSettle();
      expect(pushed.last.arguments, 51);
    });

    testWidgets('scheduled and ended drops cannot be reserved', (tester) async {
      repo.drops = [makeDrop(id: 1, status: 'SCHEDULED'), makeDrop(id: 2, status: 'ENDED', remaining: 0)];
      await open(tester, dropId: 1);
      expect(find.text('Not live yet'), findsOneWidget);
      expect(find.text('Reserve a slot'), findsNothing);
    });
  });
}

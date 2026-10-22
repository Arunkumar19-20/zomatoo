import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/drop_models.dart';
import 'package:tomatoo/models/drop_state.dart';
import 'package:tomatoo/services/api_client.dart';

import 'fakes/fake_drop_repository.dart';

void main() {
  final serverNow = DateTime(2026, 10, 22, 12);

  group('server date parsing and DTOs', () {
    test('parses nanosecond LocalDateTime strings from Spring', () {
      final d = parseServerDateTime('2026-10-22T22:21:17.496123456');
      expect(d.year, 2026);
      expect(d.second, 17);
      expect(d.millisecond, 496);
    });

    test('parses strings without fractional seconds', () {
      expect(parseServerDateTime('2026-10-22T22:21:17').minute, 21);
    });

    test('DropDto.fromJson maps the API contract', () {
      final d = DropDto.fromJson({
        'id': 3,
        'title': 'Brisket Bao',
        'price': 18,
        'restaurantId': 2,
        'restaurantName': 'Smoke House',
        'startsAt': '2026-10-22T10:00:00',
        'endsAt': '2026-10-22T14:00:00',
        'totalSlots': 15,
        'remainingSlots': 0,
        'status': 'SOLD_OUT',
        'serverTime': '2026-10-22T12:00:00.123456789',
      });
      expect(d.isSoldOut, isTrue);
      expect(d.price, 18.0);
      expect(d.claimedFraction, 1.0);
      expect(d.restaurantName, 'Smoke House');
    });

    test('ReservationDto and WaitlistEntryDto.fromJson', () {
      final r = ReservationDto.fromJson({
        'reservationId': 9,
        'dropId': 3,
        'status': 'HELD',
        'expiresAt': '2026-10-22T12:10:00',
        'orderId': null,
        'serverTime': '2026-10-22T12:00:00',
      });
      expect(r.isHeld, isTrue);
      expect(r.orderId, isNull);
      final w = WaitlistEntryDto.fromJson({
        'entryId': 4,
        'dropId': 3,
        'status': 'OFFERED',
        'position': 0,
        'reservationId': 9,
        'offerExpiresAt': '2026-10-22T12:05:00',
        'serverTime': '2026-10-22T12:00:00',
      });
      expect(w.isOffered, isTrue);
      expect(w.reservationId, 9);
    });
  });

  group('DropState', () {
    late FakeDropRepository repo;
    late DateTime deviceNow;
    late DropState state;
    var loggedIn = true;

    setUp(() {
      repo = FakeDropRepository();
      loggedIn = true;
      deviceNow = serverNow;
      state = DropState(
        repository: repo,
        isLoggedIn: () => loggedIn,
        clock: () => deviceNow,
      );
    });

    tearDown(() => state.dispose());

    test('countdowns follow the server clock even when the device clock is an hour off', () async {
      deviceNow = serverNow.subtract(const Duration(hours: 1)); // phone clock is wrong
      repo.drops = [makeDrop()];
      repo.reservations = [makeHold(expiresAt: serverNow.add(const Duration(minutes: 10)))];

      await state.refresh();

      final hold = state.activeHold;
      expect(hold, isNotNull);
      expect(state.timeLeft(hold!.expiresAt).inSeconds, inInclusiveRange(598, 600));
    });

    test('a hold stops being active the moment its server expiry passes', () async {
      repo.drops = [makeDrop()];
      repo.reservations = [makeHold(expiresAt: serverNow.add(const Duration(minutes: 10)))];
      await state.refresh();
      expect(state.activeHold, isNotNull);

      deviceNow = serverNow.add(const Duration(minutes: 10, seconds: 1));
      expect(state.activeHold, isNull);
      expect(state.holdForDrop(1), isNull);
    });

    test('anonymous visitors only load public drops', () async {
      loggedIn = false;
      repo.drops = [makeDrop()];
      await state.refresh();
      expect(state.drops, hasLength(1));
      expect(repo.reservationCalls, 0);
      expect(state.reservations, isEmpty);
    });

    test('a waitlist hand-off is announced exactly once and flagged on the hold', () async {
      repo.drops = [makeDrop(status: 'SOLD_OUT', remaining: 0)];
      repo.reservations = [makeHold(id: 77, expiresAt: serverNow.add(const Duration(minutes: 5)))];
      repo.waitlist = [
        WaitlistEntryDto(entryId: 5, dropId: 1, status: 'OFFERED', position: 0, reservationId: 77, serverTime: serverNow),
      ];

      await state.refresh();
      expect(state.takePendingOffer(), 1);
      expect(state.takePendingOffer(), isNull);
      expect(state.isWaitlistOffer(state.activeHold!), isTrue);

      await state.refresh();
      expect(state.takePendingOffer(), isNull, reason: 'same offer must not be announced twice');
    });

    test('reserve success returns the hold and refreshes', () async {
      repo.drops = [makeDrop()];
      final hold = makeHold(expiresAt: serverNow.add(const Duration(minutes: 10)));
      repo.onReserve = (_) => repo.reservations = [hold];

      final result = await state.reserve(1);

      expect(result.ok, isTrue);
      expect(result.reservation!.reservationId, hold.reservationId);
      expect(state.holdForDrop(1), isNotNull);
    });

    test('reserve failures become friendly messages with the error code', () async {
      repo.drops = [makeDrop(status: 'SOLD_OUT', remaining: 0)];
      repo.reserveError = ApiException('Drop is sold out', statusCode: 409, code: 'SOLD_OUT');

      final result = await state.reserve(1);

      expect(result.ok, isFalse);
      expect(result.code, 'SOLD_OUT');
      expect(result.message, contains('waitlist'));
    });

    test('join and leave waitlist update the list', () async {
      repo.drops = [makeDrop(status: 'SOLD_OUT', remaining: 0)];
      final joined = await state.joinWaitlist(1);
      expect(joined.ok, isTrue);
      expect(state.waitlistFor(1)!.position, 1);

      await state.leaveWaitlist(1);
      expect(state.waitlistFor(1), isNull);
    });

    test('messageFor covers the contract codes', () {
      String msg(String code) => DropState.messageFor(ApiException('raw', code: code));
      expect(msg('HOLD_EXPIRED'), contains('expired'));
      expect(msg('ALREADY_RESERVED'), contains('already'));
      expect(msg('WAITLIST_FULL'), contains('full'));
      expect(msg('RATE_LIMIT_EXCEEDED'), contains('Too many'));
      expect(msg('SOMETHING_ELSE'), 'raw');
    });

    test('a failing refresh keeps the last good data and records the error', () async {
      repo.drops = [makeDrop()];
      await state.refresh();
      expect(state.drops, hasLength(1));

      repo.failDrops = true;
      await state.refresh();

      expect(state.error, isNotNull);
      expect(state.drops, hasLength(1), reason: 'stale data beats a blank screen');

      repo.failDrops = false;
      await state.refresh();
      expect(state.error, isNull);
    });

    testWidgets('polling runs only while a screen retains it', (tester) async {
      repo.drops = [makeDrop()];
      state.retainPolling();
      await tester.pump();
      final afterStart = repo.getDropsCalls;
      expect(afterStart, 1);

      await tester.pump(const Duration(seconds: 4));
      expect(repo.getDropsCalls, afterStart + 1);

      state.retainPolling(); // a second screen shares the same timer
      state.releasePolling();
      await tester.pump(const Duration(seconds: 4));
      expect(repo.getDropsCalls, afterStart + 2);

      state.releasePolling();
      await tester.pump(const Duration(seconds: 12));
      expect(repo.getDropsCalls, afterStart + 2, reason: 'no polling once nobody needs it');
    });
  });
}

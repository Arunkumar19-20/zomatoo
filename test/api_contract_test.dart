import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/dish_search_models.dart';
import 'package:tomatoo/models/drop_models.dart';
import 'package:tomatoo/models/models.dart';
import 'package:tomatoo/services/api_client.dart';

/// The JSON in test/fixtures was captured from a real backend run (Postgres, Flyway, demo profile) by
/// scripts/demo/e2e_drops_smoke.py, so these tests fail if the Dart DTOs and the Spring DTOs drift apart.
dynamic rawFixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

Map<String, dynamic> fixture(String name) => rawFixture(name) as Map<String, dynamic>;

const kFallbackIds = {'sweet', 'spicy', 'sour', 'savory', 'creamy', 'crunchy', 'tangy', 'smoky', 'light', 'rich', 'comfort', 'fresh'};

void main() {
  test('DropDto reads a live /drops/{id} response', () {
    final d = DropDto.fromJson(fixture('api_drop'));
    expect(d.title, 'E2E Wagyu Drop');
    expect(d.price, 24.5);
    expect(d.isLive, isTrue);
    expect(d.totalSlots, 2);
    expect(d.restaurantName, 'Cravey Kitchen');
    expect(d.serverTime, isNotNull);
    expect(d.endsAt.isAfter(d.startsAt), isTrue);
  });

  test('ReservationDto reads a live HELD reservation and its server-clock window', () {
    final r = ReservationDto.fromJson(fixture('api_reservation_held'));
    expect(r.isHeld, isTrue);
    expect(r.orderId, isNull);
    // microsecond precision from Java must survive parsing; a fresh hold is positive and never beyond the 20 min cap
    expect(r.expiresAt.difference(r.serverTime!).inSeconds, inInclusiveRange(55, 20 * 60));
  });

  test('WaitlistEntryDto reads WAITING and OFFERED entries', () {
    final waiting = WaitlistEntryDto.fromJson(fixture('api_waitlist_waiting'));
    expect(waiting.isWaiting, isTrue);
    expect(waiting.position, 1);
    expect(waiting.offerExpiresAt, isNull);

    final offered = WaitlistEntryDto.fromJson(fixture('api_waitlist_offered'));
    expect(offered.isOffered, isTrue);
    expect(offered.position, 0);
    expect(offered.reservationId, isNotNull);
    expect(offered.offerExpiresAt!.difference(offered.serverTime!).inMinutes, inInclusiveRange(4, 5));
  });

  test('order checkout, payment intent and final order shapes parse', () {
    final pending = OrderResponseDTO.fromJson(fixture('api_order_pending'));
    expect(pending.paymentStatus, 'PENDING');
    expect(pending.totalAmount, 24.5);
    expect(pending.items.single.quantity, 1);

    final intent = PaymentResponseDTO.fromJson(fixture('api_payment_intent'));
    expect(intent.clientSecret, isNotEmpty);
    expect(intent.orderId, pending.orderId);

    final paid = OrderResponseDTO.fromJson(fixture('api_order_paid'));
    expect(paid.paymentStatus, 'PAID');
  });

  test('order history rows (GET /orders) parse with the model the My Orders screen uses', () {
    final o = OrderModel.fromJson(fixture('api_order_paid'));
    expect(o.orderId, isNotNull);
    expect(o.status, 'PLACED');
    expect(o.restaurantName, 'Cravey Kitchen');
    expect(o.totalAmount, 24.5);
    expect(o.items, hasLength(1));
  });

  test('refunded order (slot lost after paying) carries the fields the poller relies on', () {
    final o = OrderResponseDTO.fromJson(fixture('api_order_refunded'));
    expect(o.status, 'CANCELLED');
    expect(o.paymentStatus, 'REFUNDED');
  });

  test('error bodies keep the machine-readable code the client maps to messages', () {
    final err = fixture('api_error_sold_out');
    expect(err['code'], 'SOLD_OUT');
    final ex = ApiException(err['message'].toString(), statusCode: err['status'] as int, code: err['code'].toString());
    expect(ex.statusCode, 409);
  });

  group('craving search (captured from the live backend, real bge-small model)', () {
    test('a /search/dishes response parses, and the craving was split into two flavors', () {
      final r = DishSearchResponse.fromJson(fixture('api_dish_search'));
      expect(r.query, 'something sweet but also spicy');
      expect(r.mode, 'HYBRID');
      expect(r.facets, ['sweet', 'spicy']);
      expect(r.flavors.toSet(), {'sweet', 'spicy'});
      expect(r.hits, hasLength(10));
      expect(r.total, greaterThan(10));
      expect(r.hits.first.score, 1.0, reason: 'the best hit anchors the relative score');
      for (final h in r.hits.take(5)) {
        expect(h.matchedTags.toSet(), {'sweet', 'spicy'}, reason: '${h.name} should carry both requested flavors');
        expect(h.reasons, isNotEmpty);
        expect(h.restaurantName, isNotNull);
        expect(h.price, greaterThan(0));
      }
      expect(r.hits.map((h) => h.score).toList(), orderedEquals(r.hits.map((h) => h.score).toList()..sort((a, b) => b.compareTo(a))));
    });

    test('tag suggestions for the owner form parse with confidence and reasons', () {
      final list = (fixture('api_suggest_tags')['suggestions'] as List).map((e) => TagSuggestion.fromJson(e as Map<String, dynamic>)).toList();
      expect(list, isNotEmpty);
      expect(list.map((s) => s.tag), containsAll(['spicy', 'sweet']));
      for (final s in list) {
        expect(s.confidence, inInclusiveRange(0.5, 1.0));
        expect(s.reasons, isNotEmpty);
      }
    });

    test('the flavor vocabulary has the 12 tags the dialog falls back to', () {
      final vocab = (rawFixture('api_flavor_tags') as List).map((e) => FlavorInfo.fromJson(e as Map<String, dynamic>)).toList();
      expect(vocab, hasLength(12));
      expect(vocab.map((f) => f.id).toSet(), kFallbackIds);
    });
  });
}

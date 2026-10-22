import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/controllers/checkout_controller.dart';
import 'package:tomatoo/models/drop_state.dart';
import 'package:tomatoo/models/models.dart';
import 'package:tomatoo/repositories/order_repository.dart';
import 'package:tomatoo/repositories/payment_repository.dart';
import 'package:tomatoo/screens/drop_checkout_screen.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/services/payment_service.dart';

import 'fakes/fake_drop_repository.dart';

class _FakeOrders implements OrderRepository {
  int checkoutCalls = 0;
  ApiException? error;
  final List<int> reservationIds = [];

  @override
  Future<OrderResponseDTO> checkoutDrop(int reservationId) async {
    checkoutCalls++;
    reservationIds.add(reservationId);
    if (error != null) throw error!;
    return OrderResponseDTO(orderId: 700 + checkoutCalls, totalAmount: 24.5, status: 'PLACED', paymentStatus: 'PENDING');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakePayments implements PaymentRepository {
  final List<int> intentOrders = [];
  PaymentPollResult? pollResult;
  Object? confirmError;

  @override
  Future<PaymentResponseDTO> createPaymentIntent(int orderId) async {
    intentOrders.add(orderId);
    return PaymentResponseDTO(orderId: orderId, clientSecret: 'secret_$orderId', paymentIntentId: 'pi_$orderId');
  }

  @override
  Future<bool> confirmPaymentWithStripe({required String clientSecret, required int orderId}) async {
    if (confirmError != null) throw confirmError!;
    return true;
  }

  @override
  Future<PaymentPollResult> pollPaymentStatus(int orderId,
      {Duration timeout = const Duration(seconds: 45),
      Duration initialInterval = const Duration(seconds: 2),
      Duration maxInterval = const Duration(seconds: 5)}) async {
    return pollResult ??
        PaymentPollResult(
          status: PaymentPollStatus.paid,
          order: OrderResponseDTO(orderId: orderId, totalAmount: 24.5, status: 'PLACED', paymentStatus: 'PAID'),
        );
  }

  @override
  Future<OrderResponseDTO> pollOrderStatusUntilFinal(int orderId,
          {Duration timeout = const Duration(seconds: 45), Duration interval = const Duration(seconds: 2)}) async =>
      throw UnimplementedError();
}

void main() {
  final serverNow = DateTime(2026, 10, 22, 12);
  late FakeDropRepository drops;
  late _FakeOrders orders;
  late _FakePayments payments;
  late CheckoutController controller;
  late DropState state;
  late DateTime deviceNow;
  final pushed = <String?>[];

  setUp(() {
    drops = FakeDropRepository()
      ..drops = [makeDrop()]
      ..reservations = [makeHold(id: 55, expiresAt: serverNow.add(const Duration(minutes: 8)))];
    orders = _FakeOrders();
    payments = _FakePayments();
    controller = CheckoutController(paymentRepository: payments);
    deviceNow = serverNow;
    state = DropState(repository: drops, clock: () => deviceNow);
    pushed.clear();
  });

  tearDown(() => state.dispose());

  Future<void> open(WidgetTester tester) async {
    await state.refresh();
    await tester.pumpWidget(ChangeNotifierProvider<DropState>.value(
      value: state,
      child: MaterialApp(
        home: DropCheckoutScreen(reservationId: 55, orderRepository: orders, controller: controller),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute(settings: settings, builder: (_) => Scaffold(body: Text('route:${settings.name}')));
        },
      ),
    ));
    await tester.pump();
  }

  testWidgets('shows the held drop, its price and the countdown', (tester) async {
    await open(tester);

    expect(find.text('Wagyu Sando'), findsWidgets);
    expect(find.text('Pay ₹24.50'), findsOneWidget);
    expect(find.byKey(const ValueKey('hold-banner')), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing, reason: 'already checking out');
  });

  testWidgets('paying creates the order from the reservation, pays it and moves on', (tester) async {
    await open(tester);

    await tester.tap(find.text('Pay ₹24.50'));
    await tester.pumpAndSettle();

    expect(orders.reservationIds, [55]);
    expect(payments.intentOrders, [701]);
    expect(pushed, contains('/orders-history'));
  });

  testWidgets('a retried payment reuses the same order instead of creating a second one', (tester) async {
    payments.confirmError = ApiException('Payment was cancelled by the user.');
    await open(tester);

    await tester.tap(find.text('Pay ₹24.50'));
    await tester.pumpAndSettle();
    expect(find.text('Payment not completed'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    payments.confirmError = null;
    await tester.tap(find.text('Pay ₹24.50'));
    await tester.pumpAndSettle();

    expect(orders.checkoutCalls, 1, reason: 'one order per reservation');
    expect(payments.intentOrders, [701, 701]);
    expect(pushed, contains('/orders-history'));
  });

  testWidgets('an order that already exists on the reservation is paid, not re-created', (tester) async {
    drops.reservations = [makeHold(id: 55, orderId: 640, expiresAt: serverNow.add(const Duration(minutes: 8)))];
    await open(tester);

    await tester.tap(find.text('Pay ₹24.50'));
    await tester.pumpAndSettle();

    expect(orders.checkoutCalls, 0);
    expect(payments.intentOrders, [640]);
  });

  testWidgets('sold out after paying: tells the customer they are being refunded', (tester) async {
    payments.pollResult = PaymentPollResult(
      status: PaymentPollStatus.failed,
      errorMessage: 'Sorry, this drop sold out before your payment completed. Your payment will be refunded automatically.',
    );
    await open(tester);

    await tester.tap(find.text('Pay ₹24.50'));
    await tester.pumpAndSettle();

    expect(find.text('Payment not completed'), findsOneWidget);
    expect(find.textContaining('refunded automatically'), findsOneWidget);
    expect(pushed, isNot(contains('/orders-history')));
  });

  testWidgets('server says the hold expired mid-checkout: explains it and refreshes', (tester) async {
    orders.error = ApiException('Reservation expired', statusCode: 409, code: 'HOLD_EXPIRED');
    await open(tester);
    final before = drops.reservationCalls;

    drops.reservations = []; // server released it
    await tester.tap(find.text('Pay ₹24.50'));
    await tester.pumpAndSettle();

    expect(find.text('Your hold expired'), findsOneWidget);
    expect(drops.reservationCalls, greaterThan(before));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('This hold has expired'), findsOneWidget);
    expect(payments.intentOrders, isEmpty);
  });

  testWidgets('opening checkout for a hold that is already gone shows the expired state', (tester) async {
    drops.reservations = [];
    await open(tester);

    expect(find.text('This hold has expired'), findsOneWidget);
    expect(find.text('Pay ₹24.50'), findsNothing);
  });

  testWidgets('the countdown running out swaps the pay screen for the expired state', (tester) async {
    await open(tester);
    expect(find.text('Pay ₹24.50'), findsOneWidget);

    drops.reservations = [];
    deviceNow = serverNow.add(const Duration(minutes: 8, seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('This hold has expired'), findsOneWidget);
  });
}

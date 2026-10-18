import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/controllers/checkout_controller.dart';
import 'package:tomatoo/repositories/payment_repository.dart';
import 'package:tomatoo/services/payment_service.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/models/models.dart';

class FakePaymentRepository implements PaymentRepository {
  PaymentResponseDTO Function(int orderId)? onCreatePaymentIntent;
  bool Function({required String clientSecret, required int orderId})? onConfirmPaymentWithStripe;
  PaymentPollResult Function(int orderId)? onPollPaymentStatus;
  OrderResponseDTO Function(int orderId)? onPollOrderStatusUntilFinal;

  @override
  Future<PaymentResponseDTO> createPaymentIntent(int orderId) async {
    if (onCreatePaymentIntent != null) {
      return onCreatePaymentIntent!(orderId);
    }
    return PaymentResponseDTO(
      orderId: orderId,
      clientSecret: 'pi_test_secret_123',
      paymentIntentId: 'pi_test_123',
    );
  }

  @override
  Future<bool> confirmPaymentWithStripe({
    required String clientSecret,
    required int orderId,
  }) async {
    if (onConfirmPaymentWithStripe != null) {
      return onConfirmPaymentWithStripe!(clientSecret: clientSecret, orderId: orderId);
    }
    return true;
  }

  @override
  Future<PaymentPollResult> pollPaymentStatus(
    int orderId, {
    Duration timeout = const Duration(seconds: 45),
    Duration initialInterval = const Duration(seconds: 2),
    Duration maxInterval = const Duration(seconds: 5),
  }) async {
    if (onPollPaymentStatus != null) {
      return onPollPaymentStatus!(orderId);
    }
    return PaymentPollResult(
      status: PaymentPollStatus.paid,
      order: OrderResponseDTO(
        orderId: orderId,
        totalAmount: 99.0,
        status: 'CONFIRMED',
        paymentStatus: 'PAID',
      ),
    );
  }

  @override
  Future<OrderResponseDTO> pollOrderStatusUntilFinal(
    int orderId, {
    Duration timeout = const Duration(seconds: 45),
    Duration interval = const Duration(seconds: 2),
  }) async {
    if (onPollOrderStatusUntilFinal != null) {
      return onPollOrderStatusUntilFinal!(orderId);
    }
    return OrderResponseDTO(
      orderId: orderId,
      totalAmount: 99.0,
      status: 'CONFIRMED',
      paymentStatus: 'PAID',
    );
  }
}

void main() {
  late FakePaymentRepository fakeRepo;
  late CheckoutController controller;

  setUp(() {
    fakeRepo = FakePaymentRepository();
    controller = CheckoutController(paymentRepository: fakeRepo);
  });

  group('CheckoutController', () {
    test('initial state is idle', () {
      expect(controller.state, equals(CheckoutState.idle));
      expect(controller.errorMessage, isNull);
      expect(controller.statusText, isEmpty);
      expect(controller.isProcessing, isFalse);
      expect(controller.pollStatus, isNull);
    });

    test('success path: transitions through states and completes successfully', () async {
      final recordedStates = <CheckoutState>[];
      controller.addListener(() => recordedStates.add(controller.state));

      final result = await controller.processPayment(42);

      expect(result, isTrue);
      expect(controller.state, equals(CheckoutState.success));
      expect(controller.errorMessage, isNull);
      expect(controller.pollStatus, equals(PaymentPollStatus.paid));
      expect(controller.isProcessing, isFalse);

      expect(
        recordedStates,
        equals([
          CheckoutState.creatingIntent,
          CheckoutState.awaitingPayment,
          CheckoutState.polling,
          CheckoutState.success,
        ]),
      );
    });

    test('payment cancelled: handles Stripe cancellation as failure', () async {
      fakeRepo.onConfirmPaymentWithStripe = ({required clientSecret, required orderId}) {
        throw ApiException('Payment was cancelled by the user.');
      };

      final result = await controller.processPayment(42);

      expect(result, isFalse);
      expect(controller.state, equals(CheckoutState.failure));
      expect(controller.errorMessage, equals('Payment was cancelled by the user.'));
      expect(controller.isProcessing, isFalse);
    });

    test('payment failed: handles poll failure with error message', () async {
      fakeRepo.onPollPaymentStatus = (orderId) {
        return PaymentPollResult(
          status: PaymentPollStatus.failed,
          errorMessage: 'Payment declined by issuing bank.',
        );
      };

      final result = await controller.processPayment(42);

      expect(result, isFalse);
      expect(controller.state, equals(CheckoutState.failure));
      expect(controller.errorMessage, equals('Payment declined by issuing bank.'));
      expect(controller.isProcessing, isFalse);
    });

    test('intent creation error: handles server failure when creating payment intent', () async {
      fakeRepo.onCreatePaymentIntent = (orderId) {
        throw ApiException('Server error: unable to create intent (500)');
      };

      final result = await controller.processPayment(42);

      expect(result, isFalse);
      expect(controller.state, equals(CheckoutState.failure));
      expect(controller.errorMessage, equals('Server error: unable to create intent (500)'));
      expect(controller.isProcessing, isFalse);
    });

    test('intent creation error: handles missing client secret', () async {
      fakeRepo.onCreatePaymentIntent = (orderId) {
        return PaymentResponseDTO(
          orderId: orderId,
          clientSecret: '',
          paymentIntentId: 'pi_test',
        );
      };

      final result = await controller.processPayment(42);

      expect(result, isFalse);
      expect(controller.state, equals(CheckoutState.failure));
      expect(controller.errorMessage, contains('missing client secret'));
      expect(controller.isProcessing, isFalse);
    });

    test('polling timeout: handles timeout during status polling', () async {
      fakeRepo.onPollPaymentStatus = (orderId) {
        throw TimeoutException('Polling timed out after 45s');
      };

      final result = await controller.processPayment(42);

      expect(result, isFalse);
      expect(controller.state, equals(CheckoutState.failure));
      expect(controller.errorMessage, contains('Polling timed out'));
      expect(controller.isProcessing, isFalse);
    });

    test('reset clears state back to idle', () async {
      fakeRepo.onCreatePaymentIntent = (orderId) {
        throw ApiException('Failed');
      };
      await controller.processPayment(42);
      expect(controller.state, equals(CheckoutState.failure));

      controller.reset();
      expect(controller.state, equals(CheckoutState.idle));
      expect(controller.errorMessage, isNull);
      expect(controller.statusText, isEmpty);
      expect(controller.pollStatus, isNull);
    });
  });
}

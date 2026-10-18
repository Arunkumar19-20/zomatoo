import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/payment_repository.dart';
import '../services/payment_service.dart';
import '../services/api_client.dart';

enum CheckoutState {
  idle,
  creatingIntent,
  awaitingPayment,
  polling,
  success,
  failure,
}

class CheckoutController extends ChangeNotifier {
  final PaymentRepository _paymentRepository;

  CheckoutController({PaymentRepository? paymentRepository})
      : _paymentRepository = paymentRepository ?? PaymentService();

  CheckoutState _state = CheckoutState.idle;
  CheckoutState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _statusText = '';
  String get statusText => _statusText;

  PaymentPollStatus? _pollStatus;
  PaymentPollStatus? get pollStatus => _pollStatus;

  bool get isProcessing =>
      _state == CheckoutState.creatingIntent ||
      _state == CheckoutState.awaitingPayment ||
      _state == CheckoutState.polling;

  void reset() {
    _state = CheckoutState.idle;
    _errorMessage = null;
    _statusText = '';
    _pollStatus = null;
    notifyListeners();
  }

  /// Coordinates creating a payment intent, Stripe confirmation, and order status polling.
  Future<bool> processPayment(int orderId) async {
    _errorMessage = null;
    _pollStatus = null;

    // 1. Creating Intent
    _state = CheckoutState.creatingIntent;
    _statusText = 'Initializing Payment...';
    notifyListeners();

    try {
      final intentRes = await _paymentRepository.createPaymentIntent(orderId);
      final clientSecret = intentRes.clientSecret;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw ApiException('Payment intent creation failed: missing client secret.');
      }

      // 2. Awaiting Payment
      _state = CheckoutState.awaitingPayment;
      _statusText = 'Confirming Payment...';
      notifyListeners();

      await _paymentRepository.confirmPaymentWithStripe(
        clientSecret: clientSecret,
        orderId: orderId,
      );

      // 3. Polling
      _state = CheckoutState.polling;
      _statusText = 'Verifying Confirmation...';
      notifyListeners();

      final pollResult = await _paymentRepository.pollPaymentStatus(orderId);
      _pollStatus = pollResult.status;

      if (pollResult.status == PaymentPollStatus.paid ||
          pollResult.status == PaymentPollStatus.processing) {
        _state = CheckoutState.success;
        _statusText = '';
        notifyListeners();
        return true;
      } else {
        _state = CheckoutState.failure;
        _statusText = '';
        _errorMessage = pollResult.errorMessage ?? 'Payment was not completed. Please retry your payment.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[CheckoutController] Payment flow warning: $e');
      _state = CheckoutState.failure;
      _statusText = '';
      _errorMessage = e is ApiException ? e.message : 'Payment error: $e';
      notifyListeners();
      return false;
    }
  }
}

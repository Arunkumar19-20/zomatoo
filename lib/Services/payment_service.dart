// lib/services/payment_service.dart
// Mirrors: PaymentController (/payment) — creates a Stripe PaymentIntent
// and returns its client secret. Use the `flutter_stripe` package on the
// client to actually confirm/collect the card payment with that secret.

import 'package:dio/dio.dart';
import '../core/api_client.dart';

class PaymentService {
  final Dio _dio = ApiClient.instance.dio;

  /// POST /payment/create?amount=  (amount is in the smallest currency
  /// unit, e.g. paise for INR — same convention Stripe uses).
  /// Returns the PaymentIntent's client secret.
  Future<String> createPaymentIntent(int amount) async {
    try {
      final res = await _dio.post(
        '/payment/create',
        queryParameters: {'amount': amount},
      );
      return res.data.toString();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

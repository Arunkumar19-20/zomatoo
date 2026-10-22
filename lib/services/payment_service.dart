// lib/services/payment_service.dart
// Mirrors: PaymentController (/payment) — creates a Stripe PaymentIntent
// and coordinates confirmation and order status polling.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'api_client.dart';
import 'order_service.dart';
import '../models/models.dart';
import '../repositories/payment_repository.dart';

enum PaymentPollStatus {
  paid,
  processing,
  failed,
}

class PaymentPollResult {
  final PaymentPollStatus status;
  final OrderResponseDTO? order;
  final String? errorMessage;

  PaymentPollResult({
    required this.status,
    this.order,
    this.errorMessage,
  });
}

class PaymentService implements PaymentRepository {
  final Dio _dio;
  final OrderService _orderService;

  PaymentService({Dio? dio, OrderService? orderService})
      : _dio = dio ?? ApiClient.instance.dio,
        _orderService = orderService ?? OrderService(dio: dio);

  static const String defaultPublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_placeholder',
  );

  static void initialize({String? publishableKey}) {
    final key = publishableKey ?? defaultPublishableKey;
    if (key.isNotEmpty && key != 'pk_test_placeholder') {
      Stripe.publishableKey = key;
      Stripe.merchantIdentifier = 'merchant.com.example.cravey';
    }
  }

  /// POST /payment/create?orderId=
  @override
  Future<PaymentResponseDTO> createPaymentIntent(int orderId) async {
    try {
      final res = await _dio.post(
        '/payment/create',
        queryParameters: {'orderId': orderId},
      );
      return PaymentResponseDTO.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Confirms Stripe payment via PaymentSheet on mobile devices
  @override
  Future<bool> confirmPaymentWithStripe({
    required String clientSecret,
    required int orderId,
  }) async {
    // If Stripe publishable key is not set or mock secret is used, return true for test environments
    if (Stripe.publishableKey.isEmpty ||
        Stripe.publishableKey == 'pk_test_placeholder' ||
        clientSecret.isEmpty ||
        clientSecret.startsWith('mock_')) {
      debugPrint('[PaymentService] Simulated payment confirmation for order $orderId');
      return true;
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Cravey',
          style: ThemeMode.system,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return true;
    } catch (e) {
      if (e is StripeException) {
        if (e.error.code == FailureCode.Canceled) {
          throw ApiException('Payment was cancelled by the user.');
        }
        throw ApiException('Payment failed: ${e.error.localizedMessage ?? e.error.message}');
      }
      throw ApiException('Payment failed: $e');
    }
  }

  /// Polls GET /orders/{orderId} with backoff until paymentStatus is PAID, FAILED, or timeout.
  /// Bounded duration (45s) prevents infinite loops.
  @override
  Future<PaymentPollResult> pollPaymentStatus(
    int orderId, {
    Duration timeout = const Duration(seconds: 45),
    Duration initialInterval = const Duration(seconds: 2),
    Duration maxInterval = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    Duration currentInterval = initialInterval;
    OrderResponseDTO? lastOrder;

    while (stopwatch.elapsed < timeout) {
      try {
        final order = await _orderService.getOrderById(orderId);
        lastOrder = order;

        final payStatus = (order.paymentStatus ?? '').toUpperCase();
        final orderStatus = (order.status ?? '').toUpperCase();

        if (payStatus == 'PAID' ||
            payStatus == 'SUCCESS' ||
            orderStatus == 'CONFIRMED' ||
            orderStatus == 'PREPARING' ||
            orderStatus == 'OUT_FOR_DELIVERY' ||
            orderStatus == 'DELIVERED') {
          return PaymentPollResult(
            status: PaymentPollStatus.paid,
            order: order,
          );
        }

        if (payStatus == 'FAILED' || orderStatus == 'CANCELLED') {
          return PaymentPollResult(
            status: PaymentPollStatus.failed,
            order: order,
            errorMessage: 'Payment failed or was cancelled.',
          );
        }
      } catch (_) {
        // Transient network error while polling; retry until timeout
      }

      await Future.delayed(currentInterval);
      // Incremental backoff capped at maxInterval
      final nextMs = (currentInterval.inMilliseconds * 1.5).round();
      currentInterval = Duration(milliseconds: nextMs.clamp(1000, maxInterval.inMilliseconds));
    }

    // Bounded timeout reached: return processing result without fabricating PAID
    return PaymentPollResult(
      status: PaymentPollStatus.processing,
      order: lastOrder,
      errorMessage: 'Payment processing, we will confirm shortly.',
    );
  }

  /// Backward-compatible alias
  @override
  Future<OrderResponseDTO> pollOrderStatusUntilFinal(
    int orderId, {
    Duration timeout = const Duration(seconds: 45),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final result = await pollPaymentStatus(orderId, timeout: timeout, initialInterval: interval);
    if (result.order != null) return result.order!;
    return await _orderService.getOrderById(orderId);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:tomatoo/services/payment_service.dart';
import 'package:tomatoo/services/order_service.dart';
import 'package:tomatoo/models/models.dart';

class _FakeOrderService extends OrderService {
  final List<Future<OrderResponseDTO> Function()> queue;
  int callCount = 0;

  _FakeOrderService(this.queue);

  @override
  Future<OrderResponseDTO> getOrderById(int id) async {
    if (callCount < queue.length) {
      final fn = queue[callCount++];
      return await fn();
    }
    return OrderResponseDTO(
      orderId: id,
      status: 'PLACED',
      paymentStatus: 'PENDING',
      totalAmount: 100.0,
      orderDate: '2026-10-06T12:00:00Z',
      items: [],
    );
  }
}

void main() {
  group('PaymentService.pollPaymentStatus Tests', () {
    test('1. Returns paid immediately when order paymentStatus is PAID', () async {
      final fakeOrderService = _FakeOrderService([
        () async => OrderResponseDTO(
              orderId: 101,
              status: 'PLACED',
              paymentStatus: 'PAID',
              totalAmount: 250.0,
              orderDate: '2026-10-06T12:00:00Z',
              items: [],
            ),
      ]);

      final paymentService = PaymentService(orderService: fakeOrderService);
      final result = await paymentService.pollPaymentStatus(
        101,
        timeout: const Duration(seconds: 10),
        initialInterval: const Duration(milliseconds: 10),
      );

      expect(result.status, PaymentPollStatus.paid);
      expect(result.order?.orderId, 101);
      expect(result.order?.paymentStatus, 'PAID');
      expect(fakeOrderService.callCount, 1);
    });

    test('2. Returns paid when order transitions from PENDING to CONFIRMED / PAID on second poll', () async {
      final fakeOrderService = _FakeOrderService([
        () async => OrderResponseDTO(
              orderId: 102,
              status: 'PLACED',
              paymentStatus: 'PENDING',
              totalAmount: 300.0,
              orderDate: '2026-10-06T12:00:00Z',
              items: [],
            ),
        () async => OrderResponseDTO(
              orderId: 102,
              status: 'CONFIRMED',
              paymentStatus: 'PAID',
              totalAmount: 300.0,
              orderDate: '2026-10-06T12:00:00Z',
              items: [],
            ),
      ]);

      final paymentService = PaymentService(orderService: fakeOrderService);
      final result = await paymentService.pollPaymentStatus(
        102,
        timeout: const Duration(seconds: 10),
        initialInterval: const Duration(milliseconds: 10),
      );

      expect(result.status, PaymentPollStatus.paid);
      expect(result.order?.paymentStatus, 'PAID');
      expect(fakeOrderService.callCount, 2);
    });

    test('3. Returns failed when order paymentStatus is FAILED', () async {
      final fakeOrderService = _FakeOrderService([
        () async => OrderResponseDTO(
              orderId: 103,
              status: 'PLACED',
              paymentStatus: 'FAILED',
              totalAmount: 150.0,
              orderDate: '2026-10-06T12:00:00Z',
              items: [],
            ),
      ]);

      final paymentService = PaymentService(orderService: fakeOrderService);
      final result = await paymentService.pollPaymentStatus(
        103,
        timeout: const Duration(seconds: 10),
        initialInterval: const Duration(milliseconds: 10),
      );

      expect(result.status, PaymentPollStatus.failed);
      expect(result.errorMessage, contains('Payment failed'));
      expect(fakeOrderService.callCount, 1);
    });

    test('4. Returns processing when bounded timeout expires without PAID or FAILED', () async {
      final fakeOrderService = _FakeOrderService([
        () async => OrderResponseDTO(
              orderId: 104,
              status: 'PLACED',
              paymentStatus: 'PENDING',
              totalAmount: 150.0,
              orderDate: '2026-10-06T12:00:00Z',
              items: [],
            ),
      ]);

      final paymentService = PaymentService(orderService: fakeOrderService);
      final result = await paymentService.pollPaymentStatus(
        104,
        timeout: const Duration(milliseconds: 50),
        initialInterval: const Duration(milliseconds: 20),
      );

      expect(result.status, PaymentPollStatus.processing);
      expect(result.errorMessage, contains('confirm shortly'));
      expect(result.order?.orderId, 104);
      expect(result.order?.paymentStatus, 'PENDING');
    });

    test('5. Handles transient network errors gracefully during polling', () async {
      final fakeOrderService = _FakeOrderService([
        () async => throw DioException(
              requestOptions: RequestOptions(path: '/orders/105'),
              error: 'Temporary timeout',
              type: DioExceptionType.connectionTimeout,
            ),
        () async => OrderResponseDTO(
              orderId: 105,
              status: 'PLACED',
              paymentStatus: 'PAID',
              totalAmount: 150.0,
              orderDate: '2026-10-06T12:00:00Z',
              items: [],
            ),
      ]);

      final paymentService = PaymentService(orderService: fakeOrderService);
      final result = await paymentService.pollPaymentStatus(
        105,
        timeout: const Duration(seconds: 10),
        initialInterval: const Duration(milliseconds: 10),
      );

      expect(result.status, PaymentPollStatus.paid);
      expect(result.order?.orderId, 105);
      expect(fakeOrderService.callCount, 2);
    });
  });
}

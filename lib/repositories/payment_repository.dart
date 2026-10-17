import '../models/models.dart';
import '../services/payment_service.dart';

abstract class PaymentRepository {
  Future<PaymentResponseDTO> createPaymentIntent(int orderId);

  Future<bool> confirmPaymentWithStripe({
    required String clientSecret,
    required int orderId,
  });

  Future<PaymentPollResult> pollPaymentStatus(
    int orderId, {
    Duration timeout,
    Duration initialInterval,
    Duration maxInterval,
  });

  Future<OrderResponseDTO> pollOrderStatusUntilFinal(
    int orderId, {
    Duration timeout,
    Duration interval,
  });
}

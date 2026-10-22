import '../models/models.dart';

abstract class OrderRepository {
  Future<OrderResponseDTO> checkout({
    int? restaurantId,
    int? cartId,
    int? customerId,
  });

  /// Turns a held drop slot into an unpaid order priced from the drop (POST /orders/checkout?reservationId=).
  Future<OrderResponseDTO> checkoutDrop(int reservationId);

  Future<List<OrderResponseDTO>> getMyOrders();

  Future<OrderResponseDTO> getOrderById(int id);

  Future<OrderResponseDTO> updateStatus(int id, String status);

  Future<bool> cancel(int id);
}

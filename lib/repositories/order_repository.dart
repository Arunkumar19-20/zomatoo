import '../models/models.dart';

abstract class OrderRepository {
  Future<OrderResponseDTO> checkout({
    int? restaurantId,
    int? cartId,
    int? customerId,
  });

  Future<List<OrderResponseDTO>> getMyOrders();

  Future<OrderResponseDTO> getOrderById(int id);

  Future<OrderResponseDTO> updateStatus(int id, String status);

  Future<bool> cancel(int id);
}

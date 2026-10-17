import '../models/models.dart';

abstract class RestaurantRepository {
  Future<List<Restaurant>> getAll({
    int page = 0,
    int size = 20,
    String? cuisine,
    double? minRating,
    bool? isOpen,
    String? search,
  });

  Future<List<MenuCategoryDTO>> getRestaurantMenu(int restaurantId);

  Future<Restaurant> getById(int id);

  Future<Restaurant> create(Restaurant restaurant);

  Future<Restaurant> update(int id, Restaurant restaurant);

  Future<void> delete(int id);

  Future<List<Restaurant>> getByLocation(int locationId);

  Future<List<Restaurant>> getOpenRestaurants();

  Future<List<Restaurant>> getByRating(double rating);

  Future<void> updateStatus(int id, bool isOpen);

  Future<void> addMenuItem(MenuItem item);

  Future<void> removeMenuItem(int itemId);
}

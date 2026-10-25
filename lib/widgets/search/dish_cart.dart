import '../../models/dish_search_models.dart';
import '../../models/food_item.dart';

// Search results know a dish and a restaurant by their database ids. The cart knows them as FoodItem and Restaurant, with the ids the restaurant page
// uses ('api_<id>'), so a dish added here is the same cart line as when it is added from the restaurant's menu.

FoodItem foodItemFromHit(DishHit hit) => FoodItem(
      id: 'api_${hit.itemId}',
      name: hit.name,
      description: hit.description ?? '',
      price: hit.price,
      imageUrl: hit.imageUrl ?? '',
      category: '',
      rating: 4.5,
      backendItemId: hit.itemId,
      isVeg: hit.veg,
    );

/// Just enough of a restaurant for the cart to know where the dishes come from. Same id and delivery fee the home screen gives it.
Restaurant restaurantFromHit(DishHit hit) => Restaurant(
      id: 'api_${hit.restaurantId}',
      name: hit.restaurantName ?? 'Restaurant',
      imageUrl: '',
      rating: 4.5,
      deliveryTime: '30 min',
      deliveryFee: 29.0,
      cuisineTags: const [],
      menu: const [],
      backendId: hit.restaurantId,
    );

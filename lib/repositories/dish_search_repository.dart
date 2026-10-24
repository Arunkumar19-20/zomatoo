import '../models/dish_search_models.dart';

abstract class DishSearchRepository {
  /// "Something sweet but also spicy" in, the top-[k] dishes out.
  Future<DishSearchResponse> search(String query, {int k = 10, bool? veg, double? maxPrice});

  /// Tells the server a result was opened. Best effort: never throws.
  Future<void> reportClick(String searchId, int itemId, int rank, {String action = 'OPEN'});
}

/// What the owner's add-dish form needs from /menu-items.
abstract class MenuTagRepository {
  Future<List<FlavorInfo>> flavorTags();

  Future<List<TagSuggestion>> suggest({required String name, String? description, String? ingredients, String? categoryName});
}

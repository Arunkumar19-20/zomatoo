import 'dart:async';
import 'package:tomatoo/models/dish_search_models.dart';
import 'package:tomatoo/repositories/dish_search_repository.dart';
import 'package:tomatoo/services/api_client.dart';

DishHit makeHit({
  int id = 1,
  String name = 'Honey Hot Chicken Tenders',
  List<String> matched = const ['sweet', 'spicy'],
  List<String> tags = const ['sweet', 'spicy', 'crunchy'],
  double price = 379,
  bool veg = false,
  bool open = true,
  int? spice = 2,
  String restaurant = 'Smokehouse 66',
  int restaurantId = 7,
  List<String> reasons = const ['Tagged sweet + spicy by the restaurant'],
  double score = 1.0,
}) =>
    DishHit(
      itemId: id,
      name: name,
      price: price,
      veg: veg,
      restaurantId: restaurantId,
      restaurantName: restaurant,
      restaurantOpen: open,
      spiceLevel: spice,
      tags: tags,
      matchedTags: matched,
      score: score,
      reasons: reasons,
    );

DishSearchResponse makeResponse(
  String q, {
  List<DishHit>? hits,
  int? total,
  List<String> facets = const ['sweet', 'spicy'],
  List<String> flavors = const ['spicy', 'sweet'],
  String mode = 'HYBRID',
  bool veg = false,
  double? maxPrice,
  String? searchId,
}) {
  final h = hits ?? [makeHit()];
  return DishSearchResponse(query: q, mode: mode, facets: facets, flavors: flavors, vegOnly: veg, maxPrice: maxPrice, total: total ?? h.length, tookMs: 12, hits: h, searchId: searchId);
}

/// Scripted /search/dishes: tests decide what each query returns and when.
class FakeDishSearchRepository implements DishSearchRepository {
  final List<(String, int)> calls = [];
  Future<DishSearchResponse> Function(String q, int k)? handler;
  ApiException? error;
  final List<(String, int, int, String)> clicks = [];

  /// The `type` of each search, in the same order as [calls] (null = everything).
  final List<String?> types = [];

  @override
  Future<void> reportClick(String searchId, int itemId, int rank, {String action = 'OPEN'}) async {
    clicks.add((searchId, itemId, rank, action));
  }

  @override
  Future<DishSearchResponse> search(String query, {int k = 10, bool? veg, double? maxPrice, String? type}) {
    calls.add((query, k));
    types.add(type);
    if (error != null) return Future.error(error!);
    if (handler != null) return handler!(query, k);
    return Future.value(makeResponse(query));
  }
}

class FakeMenuTagRepository implements MenuTagRepository {
  List<FlavorInfo>? vocabulary;
  bool vocabularyFails = false;
  List<TagSuggestion> suggestions = const [];
  final List<String> suggestCalls = [];

  @override
  Future<List<FlavorInfo>> flavorTags() async {
    if (vocabularyFails) throw ApiException('offline');
    return vocabulary ?? const [FlavorInfo('sweet', 'Sweet'), FlavorInfo('spicy', 'Spicy'), FlavorInfo('crunchy', 'Crunchy')];
  }

  @override
  Future<List<TagSuggestion>> suggest({required String name, String? description, String? ingredients, String? categoryName}) async {
    suggestCalls.add(name);
    return suggestions;
  }
}

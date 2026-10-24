// Mirrors: DishSearchResponse (GET /search/dishes) and the tag endpoints under /menu-items

class DishHit {
  final int itemId;
  final String name;
  final String? description;
  final double price;
  final bool veg;
  final String? imageUrl;
  final int restaurantId;
  final String? restaurantName;
  final bool restaurantOpen;
  final int? spiceLevel;
  final String? servingTemp;
  final List<String> tags;

  /// The requested flavors this dish actually carries.
  final List<String> matchedTags;

  /// 0..1, relative to the best result of this search (the top hit is always 1.0).
  final double score;

  /// Plain-language reasons built from real matches, never generated.
  final List<String> reasons;

  const DishHit({
    required this.itemId,
    required this.name,
    this.description,
    required this.price,
    required this.veg,
    this.imageUrl,
    required this.restaurantId,
    this.restaurantName,
    this.restaurantOpen = true,
    this.spiceLevel,
    this.servingTemp,
    this.tags = const [],
    this.matchedTags = const [],
    this.score = 0,
    this.reasons = const [],
  });

  factory DishHit.fromJson(Map<String, dynamic> j) => DishHit(
        itemId: j['itemId'] as int,
        name: (j['name'] ?? '').toString(),
        description: j['description']?.toString(),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        veg: j['veg'] == true,
        imageUrl: j['imageUrl']?.toString(),
        restaurantId: (j['restaurantId'] as num?)?.toInt() ?? 0,
        restaurantName: j['restaurantName']?.toString(),
        restaurantOpen: j['restaurantOpen'] != false,
        spiceLevel: (j['spiceLevel'] as num?)?.toInt(),
        servingTemp: j['servingTemp']?.toString(),
        tags: _strings(j['tags']),
        matchedTags: _strings(j['matchedTags']),
        score: (j['score'] as num?)?.toDouble() ?? 0,
        reasons: _strings(j['reasons']),
      );
}

class DishSearchResponse {
  final String query;

  /// HYBRID (embeddings + keywords + tags) or KEYWORD (no model installed on the server)
  final String mode;

  /// How the craving was split, e.g. ["sweet", "spicy"]
  final List<String> facets;
  final List<String> flavors;
  final bool vegOnly;
  final double? maxPrice;
  final int total;
  final int tookMs;
  final List<DishHit> hits;

  const DishSearchResponse({
    required this.query,
    required this.mode,
    this.facets = const [],
    this.flavors = const [],
    this.vegOnly = false,
    this.maxPrice,
    this.total = 0,
    this.tookMs = 0,
    this.hits = const [],
  });

  factory DishSearchResponse.fromJson(Map<String, dynamic> j) => DishSearchResponse(
        query: (j['query'] ?? '').toString(),
        mode: (j['mode'] ?? 'KEYWORD').toString(),
        facets: _strings(j['facets']),
        flavors: _strings(j['flavors']),
        vegOnly: j['vegOnly'] == true,
        maxPrice: (j['maxPrice'] as num?)?.toDouble(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        tookMs: (j['tookMs'] as num?)?.toInt() ?? 0,
        hits: (j['hits'] as List? ?? const []).map((e) => DishHit.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class FlavorInfo {
  final String id;
  final String label;
  const FlavorInfo(this.id, this.label);

  factory FlavorInfo.fromJson(Map<String, dynamic> j) => FlavorInfo(j['id'].toString(), j['label'].toString());
}

/// One suggested tag while an owner types a dish.
class TagSuggestion {
  final String tag;
  final String label;
  final double confidence;
  final List<String> reasons;
  const TagSuggestion({required this.tag, required this.label, required this.confidence, this.reasons = const []});

  factory TagSuggestion.fromJson(Map<String, dynamic> j) => TagSuggestion(
        tag: j['tag'].toString(),
        label: (j['label'] ?? j['tag']).toString(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        reasons: _strings(j['reasons']),
      );
}

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

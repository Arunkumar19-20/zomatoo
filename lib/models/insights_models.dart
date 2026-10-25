// Mirrors: GET /search/trending (TrendingService.Chip) and GET /owner/insights (OwnerInsightsController.Insights)

List<String> _strings(dynamic v) => (v as List? ?? const []).map((e) => e.toString()).toList();

/// A rising craving customers can order today, shown as a chip under the search bar.
class TrendingChip {
  final String label;

  /// What tapping the chip types into the search box.
  final String query;
  final String kind;
  final int dishCount;

  const TrendingChip({required this.label, required this.query, this.kind = 'DISH', this.dishCount = 0});

  factory TrendingChip.fromJson(Map<String, dynamic> j) => TrendingChip(
        label: (j['label'] ?? '').toString(),
        query: (j['query'] ?? j['label'] ?? '').toString(),
        kind: (j['kind'] ?? 'DISH').toString(),
        dishCount: (j['dishCount'] as num?)?.toInt() ?? 0,
      );
}

enum SuggestionType { addDish, stockUp, makeDrop }

SuggestionType suggestionTypeFrom(String s) {
  switch (s) {
    case 'ADD_DISH':
      return SuggestionType.addDish;
    case 'MAKE_DROP':
      return SuggestionType.makeDrop;
    default:
      return SuggestionType.stockUp;
  }
}

/// What search has really brought a restaurant, projected a week ahead at the same rate. Built only from counted delivered orders.
class SuggestionEstimate {
  final int weeklyOrders;
  final int weeklyRevenue;
  final int ordersObserved;
  final int tapsObserved;

  /// PHRASE (this phrase has enough history) or RESTAURANT (falls back to the restaurant's overall rate from search).
  final String basis;

  const SuggestionEstimate({required this.weeklyOrders, this.weeklyRevenue = 0, this.ordersObserved = 0, this.tapsObserved = 0, this.basis = 'PHRASE'});

  factory SuggestionEstimate.fromJson(Map<String, dynamic> j) => SuggestionEstimate(
        weeklyOrders: (j['weeklyOrders'] as num?)?.toInt() ?? 0,
        weeklyRevenue: (j['weeklyRevenue'] as num?)?.toInt() ?? 0,
        ordersObserved: (j['ordersObserved'] as num?)?.toInt() ?? 0,
        tapsObserved: (j['tapsObserved'] as num?)?.toInt() ?? 0,
        basis: (j['basis'] ?? 'PHRASE').toString(),
      );
}

/// The form to prefill and the evidence behind a suggestion.
class SuggestionPayload {
  final String? suggestedName;
  final String? description;
  final List<String> flavorTags;
  final int? dishId;
  final String? dishName;
  final double? price;
  final bool? dishAvailable;
  final int? suggestedSlots;
  final DateTime? suggestedStartsAt;
  final DateTime? suggestedEndsAt;
  final List<String> exampleSearches;

  /// Null when there are not enough counted orders to base one on (and always for "add a dish").
  final SuggestionEstimate? estimate;

  const SuggestionPayload({
    this.suggestedName,
    this.description,
    this.flavorTags = const [],
    this.dishId,
    this.dishName,
    this.price,
    this.dishAvailable,
    this.suggestedSlots,
    this.suggestedStartsAt,
    this.suggestedEndsAt,
    this.exampleSearches = const [],
    this.estimate,
  });

  factory SuggestionPayload.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const SuggestionPayload();
    return SuggestionPayload(
      suggestedName: j['suggestedName']?.toString(),
      description: j['description']?.toString(),
      flavorTags: _strings(j['flavorTags']),
      dishId: (j['dishId'] as num?)?.toInt(),
      dishName: j['dishName']?.toString(),
      price: (j['price'] as num?)?.toDouble(),
      dishAvailable: j['dishAvailable'] as bool?,
      suggestedSlots: (j['suggestedSlots'] as num?)?.toInt(),
      suggestedStartsAt: DateTime.tryParse(j['suggestedStartsAt']?.toString() ?? ''),
      suggestedEndsAt: DateTime.tryParse(j['suggestedEndsAt']?.toString() ?? ''),
      exampleSearches: _strings(j['exampleSearches']),
      estimate: j['estimate'] == null ? null : SuggestionEstimate.fromJson(j['estimate'] as Map<String, dynamic>),
    );
  }
}

class OwnerSuggestion {
  final int id;
  final int restaurantId;
  final String restaurantName;
  final SuggestionType type;
  final String trendLabel;
  final String headline;
  final String body;
  final int recentSearchers;
  final double growth;

  /// 0..1: the share of those searches that found no matching dish on any menu.
  final double unmetShare;
  final int impressions;
  final int taps;
  final SuggestionPayload payload;

  const OwnerSuggestion({
    required this.id,
    required this.restaurantId,
    this.restaurantName = '',
    required this.type,
    this.trendLabel = '',
    required this.headline,
    required this.body,
    this.recentSearchers = 0,
    this.growth = 0,
    this.unmetShare = 0,
    this.impressions = 0,
    this.taps = 0,
    this.payload = const SuggestionPayload(),
  });

  factory OwnerSuggestion.fromJson(Map<String, dynamic> j) => OwnerSuggestion(
        id: (j['id'] as num).toInt(),
        restaurantId: (j['restaurantId'] as num).toInt(),
        restaurantName: (j['restaurantName'] ?? '').toString(),
        type: suggestionTypeFrom((j['type'] ?? '').toString()),
        trendLabel: (j['trendLabel'] ?? '').toString(),
        headline: (j['headline'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        recentSearchers: (j['recentSearchers'] as num?)?.toInt() ?? 0,
        growth: (j['growth'] as num?)?.toDouble() ?? 0,
        unmetShare: (j['unmetShare'] as num?)?.toDouble() ?? 0,
        impressions: (j['impressions'] as num?)?.toInt() ?? 0,
        taps: (j['taps'] as num?)?.toInt() ?? 0,
        payload: SuggestionPayload.fromJson(j['payload'] as Map<String, dynamic>?),
      );
}

/// A phrase rising across all searches, with the numbers owners see and customers do not.
class RisingPhrase {
  final String label;
  final String kind;
  final int recentSearchers;
  final double growth;
  final double unmetShare;
  final List<String> exampleSearches;

  const RisingPhrase({required this.label, this.kind = 'DISH', this.recentSearchers = 0, this.growth = 0, this.unmetShare = 0, this.exampleSearches = const []});

  factory RisingPhrase.fromJson(Map<String, dynamic> j) => RisingPhrase(
        label: (j['label'] ?? '').toString(),
        kind: (j['kind'] ?? 'DISH').toString(),
        recentSearchers: (j['recentSearchers'] as num?)?.toInt() ?? 0,
        growth: (j['growth'] as num?)?.toDouble() ?? 0,
        unmetShare: (j['unmetShare'] as num?)?.toDouble() ?? 0,
        exampleSearches: _strings(j['exampleSearches']),
      );
}

class OwnerRestaurantRef {
  final int id;
  final String name;
  const OwnerRestaurantRef(this.id, this.name);
}

class PhraseOrders {
  final String label;
  final int orders;
  final int revenue;
  const PhraseOrders(this.label, this.orders, this.revenue);
}

/// Delivered orders that search brought in, counted without knowing who ordered.
class SearchOrders {
  final int days;
  final int orders;
  final int units;
  final int revenue;

  /// Only phrases with enough orders behind them.
  final List<PhraseOrders> topPhrases;

  const SearchOrders({this.days = 28, this.orders = 0, this.units = 0, this.revenue = 0, this.topPhrases = const []});

  factory SearchOrders.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const SearchOrders();
    return SearchOrders(
      days: (j['days'] as num?)?.toInt() ?? 28,
      orders: (j['orders'] as num?)?.toInt() ?? 0,
      units: (j['units'] as num?)?.toInt() ?? 0,
      revenue: (j['revenue'] as num?)?.toInt() ?? 0,
      topPhrases: (j['topPhrases'] as List? ?? const [])
          .map((e) => PhraseOrders((e['label'] ?? '').toString(), (e['orders'] as num?)?.toInt() ?? 0, (e['revenue'] as num?)?.toInt() ?? 0))
          .toList(),
    );
  }
}

class OwnerInsights {
  final List<OwnerRestaurantRef> restaurants;
  final List<OwnerSuggestion> suggestions;
  final List<RisingPhrase> rising;
  final SearchOrders searchOrders;

  const OwnerInsights({this.restaurants = const [], this.suggestions = const [], this.rising = const [], this.searchOrders = const SearchOrders()});

  factory OwnerInsights.fromJson(Map<String, dynamic> j) => OwnerInsights(
        restaurants: (j['restaurants'] as List? ?? const []).map((e) => OwnerRestaurantRef((e['id'] as num).toInt(), (e['name'] ?? '').toString())).toList(),
        suggestions: (j['suggestions'] as List? ?? const []).map((e) => OwnerSuggestion.fromJson(e as Map<String, dynamic>)).toList(),
        rising: (j['rising'] as List? ?? const []).map((e) => RisingPhrase.fromJson(e as Map<String, dynamic>)).toList(),
        searchOrders: SearchOrders.fromJson(j['searchOrders'] as Map<String, dynamic>?),
      );
}

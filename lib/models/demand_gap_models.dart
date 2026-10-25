// lib/models/demand_gap_models.dart
// Mirrors: SearchAdminController GET /admin/search/demand-gaps (DemandGapService.Report)

/// One craving (several wordings folded together) that found nothing.
class DemandGap {
  final String key;
  final String label;
  final String kind; // FUSION | FLAVOR | DISH
  final int searcherDays;
  final int activeDays;

  /// For a fusion, the other cuisines it combines this group's cuisine with.
  final List<String> alsoCuisines;
  final List<String> examples;

  const DemandGap({
    required this.key,
    required this.label,
    required this.kind,
    required this.searcherDays,
    required this.activeDays,
    this.alsoCuisines = const [],
    this.examples = const [],
  });

  factory DemandGap.fromJson(Map<String, dynamic> j) => DemandGap(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        kind: (j['kind'] ?? 'DISH').toString(),
        searcherDays: (j['searcherDays'] as num?)?.toInt() ?? 0,
        activeDays: (j['activeDays'] as num?)?.toInt() ?? 0,
        alsoCuisines: (j['alsoCuisines'] as List? ?? const []).map((e) => e.toString()).toList(),
        examples: (j['examples'] as List? ?? const []).map((e) => e.toString()).toList(),
      );
}

enum DemandGapStatus {
  /// No restaurant declares this cuisine: a hole in the supply.
  noRestaurant,

  /// The cuisine is served, but these dishes or combinations are not found.
  dishGap,

  /// Cravings that name no cuisine (flavors, moods, a dish with no origin).
  noCuisine;

  static DemandGapStatus parse(String? s) {
    switch (s) {
      case 'NO_RESTAURANT':
        return DemandGapStatus.noRestaurant;
      case 'NO_CUISINE':
        return DemandGapStatus.noCuisine;
      default:
        return DemandGapStatus.dishGap;
    }
  }
}

class DemandGapGroup {
  final String cuisine;
  final String label;
  final DemandGapStatus status;
  final int searcherDays;

  /// Null for the group of cravings that name no cuisine.
  final int? restaurantsServing;
  final int? openRestaurantsServing;
  final List<DemandGap> gaps;

  const DemandGapGroup({
    required this.cuisine,
    required this.label,
    required this.status,
    required this.searcherDays,
    this.restaurantsServing,
    this.openRestaurantsServing,
    this.gaps = const [],
  });

  factory DemandGapGroup.fromJson(Map<String, dynamic> j) => DemandGapGroup(
        cuisine: (j['cuisine'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        status: DemandGapStatus.parse(j['status']?.toString()),
        searcherDays: (j['searcherDays'] as num?)?.toInt() ?? 0,
        restaurantsServing: (j['restaurantsServing'] as num?)?.toInt(),
        openRestaurantsServing: (j['openRestaurantsServing'] as num?)?.toInt(),
        gaps: (j['gaps'] as List? ?? const []).map((e) => DemandGap.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class DemandGapReport {
  final int days;
  final int minSearcherDays;
  final int unmetSearches;
  final int phrasesShown;
  final int phrasesBelowMinimum;
  final List<DemandGapGroup> groups;

  const DemandGapReport({
    this.days = 14,
    this.minSearcherDays = 5,
    this.unmetSearches = 0,
    this.phrasesShown = 0,
    this.phrasesBelowMinimum = 0,
    this.groups = const [],
  });

  factory DemandGapReport.fromJson(Map<String, dynamic> j) => DemandGapReport(
        days: (j['days'] as num?)?.toInt() ?? 14,
        minSearcherDays: (j['minSearcherDays'] as num?)?.toInt() ?? 5,
        unmetSearches: (j['unmetSearches'] as num?)?.toInt() ?? 0,
        phrasesShown: (j['phrasesShown'] as num?)?.toInt() ?? 0,
        phrasesBelowMinimum: (j['phrasesBelowMinimum'] as num?)?.toInt() ?? 0,
        groups: (j['groups'] as List? ?? const []).map((e) => DemandGapGroup.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

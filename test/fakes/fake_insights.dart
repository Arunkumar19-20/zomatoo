import 'package:tomatoo/models/insights_models.dart';
import 'package:tomatoo/repositories/insights_repository.dart';
import 'package:tomatoo/services/api_client.dart';

OwnerSuggestion makeSuggestion({
  int id = 1,
  SuggestionType type = SuggestionType.addDish,
  String headline = '"Italian × Korean fusion" is trending and not on your menu',
  String body = '120 people searched for it in the last 7 days, 22× its usual level.',
  int searchers = 120,
  double growth = 22,
  double unmet = 1.0,
  int impressions = 120,
  int taps = 16,
  int restaurantId = 2,
  String restaurant = 'Bella Napoli',
  SuggestionPayload? payload,
}) =>
    OwnerSuggestion(
      id: id,
      restaurantId: restaurantId,
      restaurantName: restaurant,
      type: type,
      headline: headline,
      body: body,
      recentSearchers: searchers,
      growth: growth,
      unmetShare: unmet,
      impressions: impressions,
      taps: taps,
      payload: payload ??
          (type == SuggestionType.makeDrop
              ? SuggestionPayload(dishId: 68, dishName: 'Beef Birria Tacos', price: 399, suggestedSlots: 10, suggestedStartsAt: DateTime(2026, 10, 26, 18), suggestedEndsAt: DateTime(2026, 10, 26, 21))
              : type == SuggestionType.addDish
                  ? const SuggestionPayload(suggestedName: 'Kimchi Carbonara', description: 'Our take on Kimchi Carbonara.', flavorTags: ['creamy', 'spicy'])
                  : const SuggestionPayload(dishId: 5, dishName: 'Margherita Pizza')),
    );

class FakeTrendingRepository implements TrendingRepository {
  List<TrendingChip> chips = const [TrendingChip(label: 'Birria Taco', query: 'birria tacos', dishCount: 1)];
  bool fails = false;
  int calls = 0;

  @override
  Future<List<TrendingChip>> trending({int limit = 6}) async {
    calls++;
    if (fails) throw ApiException('offline');
    return chips;
  }
}

class FakeOwnerInsightsRepository implements OwnerInsightsRepository {
  OwnerInsights data = const OwnerInsights();
  ApiException? loadError;
  ApiException? actionError;
  final List<String> calls = [];
  int createdDropId = 77;

  @override
  Future<OwnerInsights> load() async {
    calls.add('load');
    if (loadError != null) throw loadError!;
    return data;
  }

  Future<void> _act(String name, int id) async {
    calls.add('$name:$id');
    if (actionError != null) throw actionError!;
  }

  @override
  Future<void> dismiss(int id) => _act('dismiss', id);

  @override
  Future<void> snooze(int id) => _act('snooze', id);

  @override
  Future<void> acted(int id) => _act('acted', id);

  @override
  Future<int> createDrop(int id, {String? title, int? totalSlots}) async {
    await _act('drop:$title:$totalSlots', id);
    return createdDropId;
  }
}

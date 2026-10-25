import '../models/insights_models.dart';

/// "Trending cravings" for customers.
abstract class TrendingRepository {
  Future<List<TrendingChip>> trending({int limit = 6});
}

/// What the owner's Insights tab needs from /owner/insights.
abstract class OwnerInsightsRepository {
  Future<OwnerInsights> load();

  Future<void> dismiss(int suggestionId);

  Future<void> snooze(int suggestionId);

  /// The owner added the suggested dish through the normal form.
  Future<void> acted(int suggestionId);

  /// Creates the suggested Drop for the suggestion's own restaurant; returns the new Drop's id.
  Future<int> createDrop(int suggestionId, {String? title, int? totalSlots});
}

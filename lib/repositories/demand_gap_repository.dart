import '../models/demand_gap_models.dart';

/// What the admin's Demand tab needs from /admin/search/demand-gaps.
abstract class DemandGapRepository {
  Future<DemandGapReport> load({int days = 14, int min = 5});
}

import 'package:flutter/foundation.dart';
import '../repositories/insights_repository.dart';
import 'insights_models.dart';

/// The "Trending cravings" chips. They are a nicety, so a failure shows nothing rather than an error.
class TrendingState extends ChangeNotifier {
  TrendingState({required TrendingRepository repository, this.limit = 6}) : _repo = repository;

  final TrendingRepository _repo;
  final int limit;

  List<TrendingChip> _chips = const [];
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;

  List<TrendingChip> get chips => _chips;
  bool get loading => _loading;

  /// Loads once; call [refresh] to force it.
  Future<void> ensureLoaded() => _loaded ? Future.value() : refresh();

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      _chips = await _repo.trending(limit: limit);
    } catch (_) {
      // keep whatever we had
    } finally {
      _loaded = true;
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

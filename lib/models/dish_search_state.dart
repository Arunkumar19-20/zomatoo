import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/dish_search_repository.dart';
import '../services/api_client.dart';
import 'dish_search_models.dart';

/// Drives "search by craving": debounces typing, ignores answers that arrive after a newer query, and keeps the
/// last good result on screen while the next one loads.
class DishSearchState extends ChangeNotifier {
  DishSearchState({
    required DishSearchRepository repository,
    this.debounce = const Duration(milliseconds: 450),
    this.minChars = 3,
    this.pageSize = 10,
    this.maxK = 30,
  }) : _repo = repository;

  final DishSearchRepository _repo;
  final Duration debounce;
  final int minChars;
  final int pageSize;
  final int maxK;

  String _query = '';
  int _k = 10;
  DishSearchResponse? _response;
  bool _loading = false;
  String? _error;
  Timer? _timer;
  int _ticket = 0;
  bool _disposed = false;

  String get query => _query;
  int get k => _k;
  DishSearchResponse? get response => _response;
  bool get loading => _loading;
  String? get error => _error;

  /// A query long enough to be worth searching.
  bool get active => _query.trim().length >= minChars;

  /// More results can be asked for.
  bool get canShowMore => _response != null && _k < maxK && _response!.total > _response!.hits.length && _response!.hits.length >= _k;

  /// Call on every keystroke.
  void onQueryChanged(String text) {
    final q = text.trim();
    if (q == _query) return;
    _query = q;
    _k = pageSize;
    _timer?.cancel();
    if (!active) {
      _ticket++; // invalidate anything in flight
      _response = null;
      _error = null;
      _loading = false;
      _notify();
      return;
    }
    _loading = true;
    _error = null;
    _notify();
    _timer = Timer(debounce, _run);
  }

  Future<void> retry() => _run();

  Future<void> showMore() {
    if (!canShowMore) return Future.value();
    _k = (_k + pageSize).clamp(pageSize, maxK);
    return _run();
  }

  Future<void> _run() async {
    if (!active) return;
    final ticket = ++_ticket;
    _loading = true;
    _error = null;
    _notify();
    try {
      final r = await _repo.search(_query, k: _k);
      if (ticket != _ticket) return; // a newer query took over
      _response = r;
    } catch (e) {
      if (ticket != _ticket) return;
      _error = e is ApiException ? (e is RateLimitException ? 'Too many searches. Wait a moment and try again.' : e.message) : 'Could not search right now.';
    } finally {
      if (ticket == _ticket) {
        _loading = false;
        _notify();
      }
    }
  }

  void clear() => onQueryChanged('');

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

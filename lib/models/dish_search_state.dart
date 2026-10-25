import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/dish_search_repository.dart';
import '../services/api_client.dart';
import '../services/search_attribution.dart';
import 'dish_search_models.dart';

/// What the customer wants the search to look at. [all] is both words and cravings; the others narrow it.
enum SearchScope {
  all,
  dishes,
  restaurants,
  cravings;

  /// The `type` the dish search understands, or null for everything. Restaurants are not a dish search at all.
  String? get apiType {
    switch (this) {
      case SearchScope.dishes:
        return 'dish';
      case SearchScope.cravings:
        return 'craving';
      case SearchScope.all:
      case SearchScope.restaurants:
        return null;
    }
  }
}

/// Drives "search by craving": debounces typing, ignores answers that arrive after a newer query, and keeps the
/// last good result on screen while the next one loads.
class DishSearchState extends ChangeNotifier {
  DishSearchState({
    required DishSearchRepository repository,
    this.debounce = const Duration(milliseconds: 450),
    this.minChars = 3,
    this.pageSize = 10,
    this.maxK = 30,
    SearchAttribution? attribution,
  })  : _repo = repository,
        _attribution = attribution ?? SearchAttribution.instance;

  final DishSearchRepository _repo;
  final SearchAttribution _attribution;
  final Duration debounce;
  final int minChars;
  final int pageSize;
  final int maxK;

  String _query = '';
  SearchScope _scope = SearchScope.all;
  int _k = 10;
  DishSearchResponse? _response;
  bool _loading = false;
  String? _error;
  Timer? _timer;
  int _ticket = 0;
  bool _disposed = false;

  String get query => _query;
  SearchScope get scope => _scope;
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
      _scope = SearchScope.all; // a new search starts from everything
      _notify();
      return;
    }
    _loading = _scope != SearchScope.restaurants;
    _error = null;
    _notify();
    _timer = Timer(debounce, _run);
  }

  /// Narrows the search to dishes, restaurants or cravings (or back to everything), and searches again at once.
  void setScope(SearchScope scope) {
    if (scope == _scope) return;
    _scope = scope;
    _k = pageSize;
    _timer?.cancel();
    _ticket++; // an answer for the old scope must not land on the new one
    _response = null;
    _error = null;
    _loading = false;
    _notify();
    if (active) unawaited(_run());
  }

  Future<void> retry() => _run();

  Future<void> showMore() {
    if (!canShowMore) return Future.value();
    _k = (_k + pageSize).clamp(pageSize, maxK);
    return _run();
  }

  Future<void> _run() async {
    if (!active) return;
    if (_scope == SearchScope.restaurants) return; // the screen filters its own restaurant list; there are no dishes to fetch
    final ticket = ++_ticket;
    _loading = true;
    _error = null;
    _notify();
    try {
      final r = await _repo.search(_query, k: _k, type: _scope.apiType);
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

  /// A result was tapped. Reported against the search that produced the list on screen, once per tap, fire and forget.
  void reportOpen(DishHit hit, int rank) {
    final id = _response?.searchId;
    if (id == null) return;
    // if this dish is then added to the cart, the cart add says which search led to it
    _attribution.remember(hit.itemId, id, rank);
    unawaited(_repo.reportClick(id, hit.itemId, rank).catchError((_) {}));
  }

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

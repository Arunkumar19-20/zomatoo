import 'package:flutter/foundation.dart';
import '../repositories/insights_repository.dart';
import '../services/api_client.dart';
import 'insights_models.dart';

/// What the owner's Insights tab shows and does: suggestions to act on, and the market-wide rising phrases.
/// Dismissing or snoozing removes a card at once and puts it back if the server says no.
class OwnerInsightsState extends ChangeNotifier {
  OwnerInsightsState({required OwnerInsightsRepository repository}) : _repo = repository;

  final OwnerInsightsRepository _repo;

  OwnerInsights _data = const OwnerInsights();
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  bool _disposed = false;

  List<OwnerSuggestion> get suggestions => _data.suggestions;
  List<RisingPhrase> get rising => _data.rising;
  List<OwnerRestaurantRef> get restaurants => _data.restaurants;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      _data = await _repo.load();
      _loadedOnce = true;
    } catch (e) {
      _error = _message(e, 'Could not load insights.');
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<String?> dismiss(OwnerSuggestion s) => _remove(s, () => _repo.dismiss(s.id));

  Future<String?> snooze(OwnerSuggestion s) => _remove(s, () => _repo.snooze(s.id));

  /// The owner added the suggested dish.
  Future<String?> acted(OwnerSuggestion s) => _remove(s, () => _repo.acted(s.id));

  /// Creates the Drop; returns null on success, otherwise a message that is safe to show.
  Future<String?> createDrop(OwnerSuggestion s, {String? title, int? totalSlots}) =>
      _remove(s, () => _repo.createDrop(s.id, title: title, totalSlots: totalSlots));

  Future<String?> _remove(OwnerSuggestion s, Future<void> Function() call) async {
    final before = _data;
    _data = OwnerInsights(restaurants: before.restaurants, suggestions: before.suggestions.where((x) => x.id != s.id).toList(), rising: before.rising);
    _notify();
    try {
      await call();
      return null;
    } catch (e) {
      // a 404 means it is gone (acted on elsewhere, expired): bringing the card back would show a dead end
      if (!(e is ApiException && e.statusCode == 404)) {
        _data = before;
        _notify();
      }
      return _message(e, 'That did not work. Please try again.');
    }
  }

  static String _message(Object e, String fallback) {
    if (e is ApiException) {
      if (e.statusCode == 404) return 'That suggestion is no longer available.';
      if (e.statusCode == 401 || e.statusCode == 403) return 'Please sign in as a restaurant owner.';
      return e.message;
    }
    return fallback;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

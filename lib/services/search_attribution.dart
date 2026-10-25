// lib/services/search_attribution.dart
// Remembers, on this device only and only for a couple of hours, which search led the customer to open a dish, so that adding that dish to the
// cart can say so. The server uses it to count orders that search brought in; it never learns what the customer typed from this.

class SearchAttribution {
  SearchAttribution({this.ttl = const Duration(hours: 2), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// The one used by the app. Tests make their own.
  static final SearchAttribution instance = SearchAttribution();

  final Duration ttl;
  final DateTime Function() _clock;
  final Map<int, _Entry> _byItem = {};

  void remember(int itemId, String searchId, int rank) {
    _byItem[itemId] = _Entry(searchId, rank, _clock());
  }

  /// The search that led to [itemId], or null if there is none or it is too old.
  ({String searchId, int rank})? peek(int itemId) {
    final e = _byItem[itemId];
    if (e == null) return null;
    if (_clock().difference(e.at) > ttl) {
      _byItem.remove(itemId);
      return null;
    }
    return (searchId: e.searchId, rank: e.rank);
  }

  void forget(int itemId) => _byItem.remove(itemId);

  void clear() => _byItem.clear();
}

class _Entry {
  final String searchId;
  final int rank;
  final DateTime at;
  const _Entry(this.searchId, this.rank, this.at);
}

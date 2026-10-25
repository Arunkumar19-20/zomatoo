import '../../models/food_item.dart';

/// A restaurant that fits a search, with how strongly and why, in words the customer can read.
class RestaurantMatch {
  final Restaurant restaurant;

  /// Higher is more relevant. Only used to order the list.
  final int score;

  /// "Cuisine: Italian, Pasta", "Serves Pasta Primavera and 2 more": the strongest reason this restaurant is here.
  final String reason;

  const RestaurantMatch(this.restaurant, this.score, this.reason);
}

// Words that say what the customer is doing, not what they want.
const _filler = {'a', 'an', 'the', 'and', 'or', 'of', 'in', 'for', 'to', 'at', 'with', 'near', 'me', 'my', 'best', 'good', 'great', 'nice', 'some', 'any', 'restaurant', 'restaurants', 'place', 'places', 'food', 'foods', 'order', 'want'};

List<String> _tokens(String query) {
  final out = <String>[];
  for (final raw in query.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
    if (raw.length < 2 || _filler.contains(raw)) continue;
    if (!out.contains(raw)) out.add(raw);
  }
  return out;
}

/// "pastas" and "pasta" are the same word to a hungry person.
String _stem(String w) => w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.substring(0, w.length - 1) : w;

bool _hasWord(String text, String token) {
  final t = _stem(token);
  for (final w in text.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
    if (w.isEmpty) continue;
    final s = _stem(w);
    // whole word, or the start of one ("ital" finds Italian) once it is long enough to mean something
    if (s == t || (t.length >= 4 && s.startsWith(t))) return true;
  }
  return false;
}

/// The restaurants that are relevant to [query], best first.
///
/// Every word of the query has to be found somewhere in the restaurant (its name, cuisine, address or the dishes on its menu), so "italian pasta" does not
/// return every Italian restaurant and every pasta dish separately. Order: a name match first, then cuisine, then a menu that serves it, then the address;
/// ties go to the better rated.
List<RestaurantMatch> matchRestaurants(String query, List<Restaurant> restaurants) {
  final tokens = _tokens(query);
  if (tokens.isEmpty) return const [];
  final out = <RestaurantMatch>[];
  for (final r in restaurants) {
    var score = 0;
    var inName = 0, inCuisine = 0, inAddress = 0;
    final dishes = <String>{};
    var allFound = true;
    for (final t in tokens) {
      var found = false;
      if (_hasWord(r.name, t)) {
        score += 100;
        inName++;
        found = true;
      }
      if (r.cuisineTags.any((c) => _hasWord(c, t))) {
        score += 60;
        inCuisine++;
        found = true;
      }
      final serving = r.menu.where((m) => _hasWord(m.name, t) || _hasWord(m.category, t) || _hasWord(m.description, t)).toList();
      if (serving.isNotEmpty) {
        score += 25 + (serving.length > 5 ? 5 : serving.length) * 3;
        dishes.addAll(serving.map((m) => m.name));
        found = true;
      }
      if (r.address != null && _hasWord(r.address!, t)) {
        score += 10;
        inAddress++;
        found = true;
      }
      if (!found) {
        allFound = false;
        break;
      }
    }
    if (!allFound) continue;

    String reason;
    if (inName > 0) {
      reason = 'Name matches';
    } else if (inCuisine > 0) {
      reason = 'Cuisine: ${r.cuisineTags.where((c) => tokens.any((t) => _hasWord(c, t))).take(3).join(', ')}';
    } else if (dishes.isNotEmpty) {
      final list = dishes.toList()..sort();
      reason = list.length <= 2 ? 'Serves ${list.join(' and ')}' : 'Serves ${list.first}, ${list[1]} and ${list.length - 2} more';
    } else if (inAddress > 0) {
      reason = 'In ${r.address}';
    } else {
      reason = '';
    }
    out.add(RestaurantMatch(r, score, reason));
  }
  out.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byRating = b.restaurant.rating.compareTo(a.restaurant.rating);
    return byRating != 0 ? byRating : a.restaurant.name.compareTo(b.restaurant.name);
  });
  return out;
}
